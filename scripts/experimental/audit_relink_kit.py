"""Audit a local source kit against independently prepared sources and inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile

import create_candidate
import create_relink_kit
import sdk_build_state


def digest(stream):
    return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zip', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True,
                        help='Fuentes preparadas por separado desde los commits y parches fijados')
    parser.add_argument('--toolset', type=Path, required=True)
    args = parser.parse_args()
    package = args.zip.resolve()
    expected_hash = Path(str(package)+'.sha256').read_text(encoding='ascii').split()[0].lower()
    with package.open('rb') as stream:
        if len(expected_hash) != 64 or digest(stream) != expected_hash:
            raise ValueError('El SHA-256 del ZIP no coincide.')
    source = sdk_build_state.inventory(args.source.resolve())
    expected = {'src/'+name:value for name,value in source.items()}
    for name in (*create_relink_kit.FILES, *create_candidate.LICENSE_HASHES):
        with (create_relink_kit.ROOT/name).open('rb') as stream:
            value = digest(stream)
        if name in create_candidate.LICENSE_HASHES and value != create_candidate.LICENSE_HASHES[name]:
            raise ValueError('El aviso local no coincide con el fijado: '+name)
        expected[name] = value
    for name in ('resolve-full32-signed.dxbc','resolve_full_32bpp_cs.h'):
        with (args.toolset/'shader'/name).open('rb') as stream:
            expected['shader/'+name] = digest(stream)
    expected['LEEME_NO_PUBLICAR.txt'] = hashlib.sha256(create_relink_kit.README).hexdigest()
    game = json.loads((create_relink_kit.ROOT/'analysis/baseline/game-manifest.json').read_text(encoding='utf-8-sig'))
    forbidden = {(entry['size'], entry['sha256'].lower()) for entry in game['files']}
    home = str(Path.home()).lower()
    patterns = [path.encode(enc) for path in (home.replace('\\','/'),home.replace('/','\\')) for enc in ('utf-8','utf-16le')]
    with zipfile.ZipFile(package) as archive:
        names = archive.namelist()
        if len(names) != len({name.casefold() for name in names}):
            raise ValueError('Rutas duplicadas en el ZIP.')
        for name in names:
            create_candidate.archive_name(name)
        manifest = json.loads(archive.read('MANIFIESTO.json'))
        if manifest.get('status') != 'local-test-only':
            raise ValueError('El kit no está identificado como prueba local.')
        records = manifest['files']
        indexed = {item['path']:item for item in records}
        if len(indexed) != len(records) or set(indexed) != set(expected) or set(names) != set(expected)|{'MANIFIESTO.json'}:
            raise ValueError('El inventario contiene archivos ausentes o inesperados.')
        for index, (name, expected_digest) in enumerate(sorted(expected.items()), 1):
            info = archive.getinfo(name)
            record = indexed[name]
            if info.file_size != record['size'] or record['sha256'] != expected_digest:
                raise ValueError('Inventario incorrecto: '+name)
            hasher = hashlib.sha256(); tail = b''; found = False
            with archive.open(info) as stream:
                while chunk := stream.read(1024*1024):
                    hasher.update(chunk)
                    value = (tail+chunk).lower()
                    found = found or any(pattern in value for pattern in patterns)
                    tail = value[-256:]
            if hasher.hexdigest() != expected_digest or (info.file_size, expected_digest) in forbidden:
                raise ValueError('Contenido incorrecto o igual al disco: '+name)
            if found:
                raise ValueError('Ruta de perfil local incluida: '+name)
            if index % 3000 == 0: print(f'Auditados {index}/{len(expected)} archivos...', flush=True)
    print(f'Fuentes, receta, avisos y ZIP verificados: {len(source)} fuentes, {len(expected)} archivos en total.')
    print('La comparación exacta no sustituye la revisión de licencias o contenido derivado.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as exc:
        print('Auditoría fallida:', exc, file=sys.stderr)
        sys.exit(1)
