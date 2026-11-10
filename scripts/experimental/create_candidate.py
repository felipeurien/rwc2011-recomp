"""Build and audit a local, non-release MinGW player candidate."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TOOL_FOLDERS = ('cmake', 'mingw', 'ninja', 'python', 'rexglue')
APP_FILES = (
    'Jugar Rugby 2011.cmd',
    'port/CMakeLists.txt', 'port/rugby2011_manifest.toml', 'port/generated/rexglue.cmake', 'port/config/virtual_calls.toml',
    'scripts/RugbyLauncher.cs', 'scripts/build_launcher.ps1', 'scripts/start_game.ps1',
    'scripts/prepare_mingw_playable.ps1', 'scripts/prepare_original_game.ps1', 'scripts/prepare_iso.ps1', 'scripts/verify_game.ps1', 'scripts/repair_game_copy.ps1', 'scripts/check_free_space.ps1',
    'scripts/get_extractor.ps1', 'scripts/verify_shadow_plugin.ps1', 'scripts/check_task_sync.py',
    'scripts/prepare_unlock_prefill.py', 'scripts/get_port_fingerprint.ps1',
    'scripts/test_mingw_ready.ps1', 'scripts/update_mingw_launcher.ps1', 'scripts/verify_unlock_prefill.ps1', 'scripts/sync_unlock_backup.ps1',
    'scripts/experimental/build_mingw_port.ps1', 'scripts/experimental/rename_mingw_imports.py', 'scripts/experimental/check_mingw_seh.py', 'scripts/experimental/get_release_bundle.ps1',
)
EXTRACTOR_HASH = '7e97536f978735d586a2f78327aa337b9a19b3e364fa715316fb42d07d33e0b7'
EXTRACTOR_LICENSE_HASH = '4a7802fdcbc4781a2f9f70be9ed8b65f196393188b71347df309c4d9ead03e32'
SHADER_HASH = '3be64e932ac65fb2a41e3d379b053a530b1593158ce0fdd7a81185821c0a61c5'
LICENSE_HASHES = {
    'analysis/release-licenses/TINYAES-UNLICENSE.txt': '7e12e5df4bae12cb21581ba157ced20e1986a0508dd10d0e8a4ab9a4cf94e85c',
    'analysis/release-licenses/DISRUPTORPLUS-UPSTREAM-LICENSE.txt': 'a56f05c0dbd9489e928fd3ca22712f90b310fe749ceef47059e895f6a235100c',
    'analysis/release-licenses/GPL-2.0.txt': '8177f97513213526df2cf6184d8ff986c675afb514d4e68a404010521b880643',
    'analysis/release-licenses/AES128-LICENSE.txt': '756965be50afde53fe51d47da4fe180f82fdfaa5e72ed591d84d05df5bef4e3c',
    'analysis/release-licenses/AES128-SOURCE-NOTICE.txt': '6c73e4cd5f6aa256198be67a81e3536902fa2c3d862336075648556dbdfd969e',
    'analysis/release-licenses/TOMLPLUSPLUS-LICENSE.txt': '529bc3900a9571e49db285b0df432397e70b881cc3bf48de6667ae74ff4b06d8',
    'analysis/release-licenses/CLI11-LICENSE.txt': '3a70a5dffdaefe4c434660a8270f679ae18dd3c34208fb0b461a665bfcfe3e97',
    'analysis/release-licenses/FFMPEG-LGPL-2.1.txt': 'b634ab5640e258563c536e658cad87080553df6f34f62269a21d554844e58bfe',
    'analysis/release-licenses/FFMPEG-LICENSE.md': 'cb48bf09a11f5fb576cddb0431c8f5ed0a60157a9ec942adffc13907cbe083f2',
    'analysis/release-licenses/FMT-LICENSE.txt': '07580f2a3b35709ce703d523f447b242f6dfec7582a8c0df102c7fa2849375f8',
    'analysis/release-licenses/IMGUI-LICENSE.txt': '55e058cc5899e6077a819ad1005d6d1f4528f65ae100795c9692f9fa6525a8ce',
    'analysis/release-licenses/INJA-LICENSE.txt': 'ebc4a262d03d4b914e031060c163095deda0d9767ac6ce7758b98293e19591b3',
    'analysis/release-licenses/LIBMSPACK-LICENSE.txt': 'a190dc9c8043755d90f8b0a75fa66b9e42d4af4c980bf5ddc633f0124db3cee7',
    'analysis/release-licenses/NINJA.txt': 'eb7e9ab9690124c5c9f42bdc81383d886a3dede26345b6ed15bbad7caf81f7ea',
    'analysis/release-licenses/O1HEAP-LICENSE.txt': '9b853befdac9b2907131427795b66e0dbfdd0cfa8ecd25a58167893b8c1f0f4d',
    'analysis/release-licenses/REXGLUE.txt': '8e065be1da2ff9a16b1f063d4636d8b67e6a654bb90583ea4332e66ac421bb18',
    'analysis/release-licenses/SIMDE-LICENSE.txt': '75ce0a8c5a7bff42fbd6f8f3b469b518132132c4f4948fb8d02b1ccb5d0df9d8',
    'analysis/release-licenses/SPDLOG-LICENSE.txt': 'd678c20826e1392578508e1c78649a1e3c31bda05ef4388d967dbd654461b140',
    'analysis/release-licenses/UTFCPP-LICENSE.txt': 'c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566',
    'analysis/release-licenses/XXHASH-LICENSE.txt': '6ffedbc0f7878612d2b23589f1ff2ab15633e1df7963a5d9fc750ec5500c7e7a',
}
NOTE = ('CANDIDATO LOCAL DE PRUEBA: no publicar ni redistribuir.\n'
        'Falta auditar licencias y contenido y probar en Windows limpio.\n'
        'Para probar, colocar una ISO compatible en esta carpeta y abrir Jugar Rugby 2011.cmd.\n').encode('utf-8')


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def regular_tree(root):
    if root.is_symlink() or root.is_junction() or not root.is_dir():
        raise ValueError(f'Carpeta inválida o enlazada: {root}')
    for path in root.rglob('*'):
        if path.is_symlink() or path.is_junction():
            raise ValueError(f'No se admiten enlaces en el paquete: {path}')
        if path.is_file():
            yield path


def archive_name(value):
    name = PurePosixPath(value)
    if name.is_absolute() or not name.parts or any(p in ('', '.', '..') or ':' in p or '\\' in p for p in value.split('/')):
        raise ValueError(f'Ruta no permitida: {value}')
    return name.as_posix()


def add_entry(entries, name, source):
    name = archive_name(name)
    key = name.casefold()
    if key in entries:
        raise ValueError(f'Ruta duplicada: {name}')
    if isinstance(source, Path) and (not source.is_file() or source.is_symlink() or source.is_junction()):
        raise ValueError(f'Archivo ausente o enlazado: {source}')
    entries[key] = (name, source)


def zip_info(name):
    info = zipfile.ZipInfo(name, (2020, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    return info


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--toolset', required=True, type=Path)
    parser.add_argument('--sdk', type=Path, help='SDK ReXGlue construido por separado')
    parser.add_argument('--extractor', required=True, type=Path, help='Carpeta del extractor verificado')
    parser.add_argument('--output', required=True, type=Path, help='ZIP nuevo fuera del proyecto y del conjunto')
    args = parser.parse_args()
    toolset, extractor, output = args.toolset.resolve(), args.extractor.resolve(), args.output.resolve()
    sdk = args.sdk.resolve() if args.sdk else toolset / 'rexglue'
    if output.exists() or Path(str(output) + '.sha256').exists():
        raise ValueError('El destino o su archivo de hash ya existen.')
    if output.is_relative_to(ROOT) or output.is_relative_to(toolset) or output.is_relative_to(extractor) or output.is_relative_to(sdk):
        raise ValueError('La salida debe estar fuera del proyecto y de los componentes de entrada.')
    if digest(extractor / 'artifacts/extract-xiso.exe') != EXTRACTOR_HASH:
        raise ValueError('El extractor no coincide con la versión fijada.')
    if digest(extractor / 'artifacts/LICENSE.TXT') != EXTRACTOR_LICENSE_HASH:
        raise ValueError('La licencia del extractor no coincide con la versión fijada.')
    for name, expected in LICENSE_HASHES.items():
        if digest(ROOT / name) != expected:
            raise ValueError('El aviso de licencia no coincide con la versión fijada: ' + name)
    if digest(toolset / 'shader/resolve-full32-signed.dxbc') != SHADER_HASH:
        raise ValueError('El shader no coincide con la versión corregida.')
    for needed in ('mingw/bin/x86_64-w64-mingw32-clang++.exe',
                   'cmake/bin/cmake.exe', 'ninja/ninja.exe', 'python/python.exe'):
        if not (toolset / needed).is_file():
            raise ValueError(f'Falta un componente requerido: {needed}')
    for needed in ('bin/rexglue.exe', 'bin/librexruntime.dll', 'bin/librexgpu-xenos.dll'):
        if not (sdk / needed).is_file():
            raise ValueError(f'Falta un componente del SDK: {needed}')
    if (toolset / 'shader/resolve-full32-signed.dxbc').read_bytes() not in (sdk / 'bin/librexgpu-xenos.dll').read_bytes():
        raise ValueError('El complemento no contiene el shader corregido.')
    entries = {}
    for relative in (*APP_FILES, *LICENSE_HASHES):
        add_entry(entries, relative, ROOT / relative)
    configuration = {p.relative_to(ROOT).as_posix() for p in regular_tree(ROOT / 'port/config')}
    if configuration != {'port/config/virtual_calls.toml'}:
        raise ValueError('La configuración del port cambió; actualizar y revisar la lista del paquete.')
    for p in regular_tree(ROOT / 'port/src'):
        if p.suffix.lower() not in ('.cpp', '.h', '.hpp'):
            raise ValueError(f'Archivo inesperado en port/src: {p}')
        add_entry(entries, p.relative_to(ROOT).as_posix(), p)
    for component in TOOL_FOLDERS:
        source = sdk if component == 'rexglue' else toolset / component
        for p in regular_tree(source):
            # The verified downloaders retain their source ZIP for future checks.
            # It is not part of the upstream tool tree shipped in the candidate.
            if component in ('cmake', 'ninja', 'python', 'mingw') and p.relative_to(source).as_posix() == '.source.zip':
                continue
            rel = PurePosixPath(component, p.relative_to(source).as_posix())
            if p.suffix.lower() in ('.iso', '.xex', '.xbe', '.xzp', '.sav') or 'rugby' in p.name.lower() or '.git' in (part.lower() for part in rel.parts):
                raise ValueError(f'Archivo no permitido en herramientas: {rel}')
            add_entry(entries, 'tools/rugby-dependencies/mingw-toolset/' + rel.as_posix(), p)
    add_entry(entries, 'tools/rugby-dependencies/mingw-toolset/shader/resolve-full32-signed.dxbc', toolset / 'shader/resolve-full32-signed.dxbc')
    for name in ('extract-xiso.exe', 'LICENSE.TXT'):
        add_entry(entries, 'tools/extract-xiso-portable/artifacts/' + name, extractor / 'artifacts' / name)
    game_manifest = json.loads((ROOT / 'analysis/baseline/game-manifest.json').read_text(encoding='utf-8-sig'))
    if game_manifest.get('file_count') != len(game_manifest.get('files', [])):
        raise ValueError('El manifiesto del juego está incompleto.')
    # Do not include machine-specific paths or timestamps from the research manifest.
    public_manifest = {k: game_manifest[k] for k in ('schema_version', 'file_count', 'files')}
    add_entry(entries, 'analysis/baseline/game-manifest.json', (json.dumps(public_manifest, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    add_entry(entries, 'CANDIDATO_LOCAL_NO_PUBLICAR.txt', NOTE)
    forbidden = {}
    for entry in game_manifest['files']:
        forbidden.setdefault(entry['size'], set()).add(entry['sha256'].lower())
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name('.' + output.name + '.partial')
    if temporary.exists():
        raise ValueError(f'Ya existe una salida temporal: {temporary}')
    inventory = []
    try:
        with zipfile.ZipFile(temporary, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as z:
            for index, (name, source) in enumerate(sorted(entries.values(), key=lambda item: item[0].casefold()), 1):
                data = source if isinstance(source, bytes) else None
                size = len(data) if data is not None else source.stat().st_size
                h = hashlib.sha256()
                with z.open(zip_info(name), 'w', force_zip64=True) as out:
                    if data is not None:
                        h.update(data); out.write(data)
                    else:
                        with source.open('rb') as src:
                            while chunk := src.read(1024 * 1024):
                                h.update(chunk); out.write(chunk)
                value = h.hexdigest()
                if size in forbidden and value in forbidden[size]:
                    raise ValueError(f'El archivo coincide con un archivo del disco: {name}')
                inventory.append({'path': name, 'size': size, 'sha256': value})
                if index % 2000 == 0:
                    print(f'Empaquetados {index}/{len(entries)} archivos...', flush=True)
            manifest = {'format': 1, 'status': 'local-test-only', 'files': inventory}
            z.writestr(zip_info('MANIFIESTO.json'), (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
        print('Verificando el ZIP completo...', flush=True)
        with zipfile.ZipFile(temporary) as z:
            names = z.namelist()
            if len(names) != len(inventory) + 1 or len({n.casefold() for n in names}) != len(names):
                raise ValueError('El ZIP contiene rutas adicionales o duplicadas.')
            for item in inventory:
                info = z.getinfo(item['path'])
                if info.file_size != item['size']:
                    raise ValueError('Tamaño incorrecto: ' + item['path'])
                with z.open(info) as f:
                    if hashlib.file_digest(f, 'sha256').hexdigest() != item['sha256']:
                        raise ValueError('Contenido incorrecto: ' + item['path'])
        checksum = digest(temporary)
        temporary.rename(output)
        Path(str(output) + '.sha256').write_text(checksum + '  ' + output.name + '\n', encoding='ascii')
        print(f'Candidato local: {output}\nSHA-256: {checksum}\nArchivos: {len(inventory)}')
    except Exception:
        print(f'El archivo temporal, si existe, se conserva para inspección: {temporary}', file=sys.stderr)
        raise


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print('No se pudo construir el candidato:', exc, file=sys.stderr)
        sys.exit(1)
