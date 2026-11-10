"""Prepare the pinned LLVM/MinGW toolchain from its verified official ZIP."""
import argparse
import hashlib
import msvcrt
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import urllib.parse
import urllib.request
import uuid
import zipfile

URL = 'https://github.com/mstorsjo/llvm-mingw/releases/download/20251021/llvm-mingw-20251021-ucrt-x86_64.zip'
SHA256 = '0a0ce4733b54de8c4858ecfc2a08447de57728dccf9fbf7fcba3ce7e0d0c6af8'
SIZE = 181090604
PREFIX = 'llvm-mingw-20251021-ucrt-x86_64/'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verified_archive(path):
    try:
        return (not path.is_symlink() and not path.is_junction() and path.is_file()
                and path.stat().st_size == SIZE and digest(path) == SHA256)
    except OSError:
        return False


def download(package, partial=None):
    offset = 0
    if partial:
        shutil.copyfile(partial, package)
        offset = package.stat().st_size
    request = urllib.request.Request(URL, headers={'Accept-Encoding': 'identity'})
    if offset:
        request.add_header('Range', f'bytes={offset}-')
    with urllib.request.urlopen(request, timeout=60) as response:
        if urllib.parse.urlsplit(response.geturl()).scheme.lower() != 'https':
            raise ValueError('La descarga redirigió a una dirección sin HTTPS.')
        status = response.status
        length = response.headers.get('Content-Length')
        if status == 206 and offset:
            expected_range = f'bytes {offset}-{SIZE - 1}/{SIZE}'
            if response.headers.get('Content-Range') != expected_range:
                raise ValueError('El servidor devolvió un rango incompatible.')
            expected_length = SIZE - offset
            mode = 'ab'
            print(f'Reanudando la descarga desde {offset} bytes...', flush=True)
        elif status == 200:
            expected_length = SIZE
            mode = 'wb'
            if offset:
                print('El servidor no admite reanudar; se descargará el archivo completo.', flush=True)
        else:
            raise ValueError(f'Respuesta HTTP inesperada: {status}')
        if length is not None and (not re.fullmatch(r'[0-9]+', length) or int(length) != expected_length):
            raise ValueError('El tamaño anunciado no coincide con el paquete fijado.')
        with package.open(mode) as out:
            total = offset if mode == 'ab' else 0
            while chunk := response.read(1024 * 1024):
                total += len(chunk)
                if total > SIZE:
                    raise ValueError('La descarga supera el tamaño fijado.')
                out.write(chunk)


def members(archive):
    result = {}
    for item in archive.infolist():
        name = item.filename
        if not name.startswith(PREFIX):
            raise ValueError('Raíz inesperada en el ZIP: ' + name)
        relative = name[len(PREFIX):].rstrip('/')
        if not relative:
            continue
        parts = relative.split('/')
        if any(p in ('', '.', '..') or ':' in p or '\\' in p or p.endswith(('.', ' ')) for p in parts):
            raise ValueError('Ruta inválida en el ZIP: ' + name)
        kind = (item.external_attr >> 16) & 0o170000
        if kind not in (0, 0o100000, 0o040000):
            raise ValueError('Tipo de archivo no admitido: ' + name)
        if item.is_dir():
            continue
        key = relative.casefold()
        if key in result or key == '.source.zip':
            raise ValueError('Archivo duplicado o reservado: ' + name)
        result[key] = (PurePosixPath(relative), item)
    if not result:
        raise ValueError('El ZIP está vacío.')
    return result


def verify(directory):
    try:
        if directory.is_symlink() or directory.is_junction() or not directory.is_dir():
            return False
        source = directory / '.source.zip'
        if not verified_archive(source):
            return False
        with zipfile.ZipFile(source) as archive:
            expected = members(archive)
            actual = {}
            for path in directory.rglob('*'):
                if path.is_symlink() or path.is_junction():
                    return False
                if path.is_file() and path != source:
                    key = path.relative_to(directory).as_posix().casefold()
                    if key in actual:
                        return False
                    actual[key] = path
            if set(actual) != set(expected):
                return False
            for key, (_, item) in expected.items():
                path = actual[key]
                if path.stat().st_size != item.file_size:
                    return False
                with archive.open(item) as stream:
                    if hashlib.file_digest(stream, 'sha256').hexdigest() != digest(path):
                        return False
        return True
    except (OSError, ValueError, zipfile.BadZipFile):
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--toolset', type=Path, required=True)
    parser.add_argument('--archive', type=Path, help='ZIP oficial ya descargado')
    args = parser.parse_args()
    root = args.toolset.resolve()
    root.mkdir(parents=True, exist_ok=True)
    lock_path = root / '.llvm-mingw.lock'
    with lock_path.open('a+b') as lock:
        lock.seek(0)
        if lock.read(1) == b'':
            lock.write(b'0'); lock.flush()
        lock.seek(0)
        try:
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError as exc:
            raise ValueError('Ya hay una preparación de LLVM/MinGW en curso.') from exc
        destination = root / 'mingw'
        if destination.exists() and verify(destination):
            print('Se reutiliza LLVM/MinGW verificado.', flush=True)
            return
        stage = None
        saved_archive = None
        partial_archive = None
        for candidate in root.glob('.llvm-mingw-*'):
            suffix = candidate.name.removeprefix('.llvm-mingw-')
            if len(suffix) != 32 or not all(c in '0123456789abcdef' for c in suffix) or not candidate.is_dir() or candidate.is_symlink() or candidate.is_junction():
                continue
            if verify(candidate):
                stage = candidate
                print('Se recuperó una extracción completa: ' + str(stage), flush=True)
                break
            if not args.archive and saved_archive is None and verified_archive(candidate / '.source.zip'):
                saved_archive = candidate / '.source.zip'
            source = candidate / '.source.zip'
            if not args.archive and not source.is_symlink() and not source.is_junction() and source.is_file():
                size = source.stat().st_size
                if 0 < size < SIZE and (partial_archive is None or size > partial_archive.stat().st_size):
                    partial_archive = source
        if stage is None and not args.archive and saved_archive is None and destination.is_dir() and not destination.is_symlink() and not destination.is_junction():
            if verified_archive(destination / '.source.zip'):
                saved_archive = destination / '.source.zip'
        if stage is None:
            stage = root / ('.llvm-mingw-' + uuid.uuid4().hex)
            stage.mkdir()
            package = stage / '.source.zip'
            print('Preparando LLVM/MinGW (173 MiB); carpeta temporal: ' + str(stage), flush=True)
            if args.archive or saved_archive:
                source_archive = args.archive or saved_archive
                print('Usando ZIP local; se verificará antes de extraer: ' + str(source_archive), flush=True)
                shutil.copyfile(source_archive, package)
            else:
                download(package, partial_archive)
            if package.stat().st_size != SIZE:
                raise ValueError('La descarga de LLVM/MinGW quedó incompleta; se conserva para reintentar.')
            if digest(package) != SHA256:
                if partial_archive and not args.archive and not saved_archive:
                    partial_archive.rename(partial_archive.with_name('.source.invalid-' + uuid.uuid4().hex))
                    package.rename(package.with_name('.source.invalid-' + uuid.uuid4().hex))
                raise ValueError('El ZIP de LLVM/MinGW no coincide con el tamaño y hash fijados.')
            with zipfile.ZipFile(package) as archive:
                expected = members(archive)
                for relative, item in expected.values():
                    target = stage.joinpath(*relative.parts)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with archive.open(item) as src, target.open('xb') as out:
                        shutil.copyfileobj(src, out, 1024 * 1024)
            print('Verificando todos los archivos extraídos...', flush=True)
            if not verify(stage):
                raise ValueError('La extracción no pasó la verificación: ' + str(stage))
        previous = None
        if destination.exists():
            previous = root / ('.mingw-anterior-' + uuid.uuid4().hex)
            destination.rename(previous)
        try:
            stage.rename(destination)
        except OSError:
            if previous and not destination.exists():
                previous.rename(destination)
            raise
        if previous:
            print('Se conservó la copia anterior en ' + str(previous), flush=True)
        print('LLVM/MinGW verificado y preparado: ' + str(destination), flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print('No se pudo preparar LLVM/MinGW: ' + str(exc), file=sys.stderr)
        sys.exit(1)
