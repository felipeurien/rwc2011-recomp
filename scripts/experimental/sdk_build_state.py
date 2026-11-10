"""Record or validate local inputs before resuming an experimental SDK build."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parents[1]
RECIPE = (
    'scripts/experimental/sdk_build_state.py',
    'scripts/experimental/build_mingw_sdk.ps1',
    'scripts/experimental/build_mingw_graphics.ps1',
    'scripts/experimental/prepare_mingw_sdk_sources.py',
    'scripts/experimental/rename_mingw_imports.py',
    'scripts/experimental/scan_local_paths.py',
    'scripts/apply_exact_patch.ps1', 'scripts/verify_shadow_plugin.ps1',
    'patches/experimental-rexglue-mingw.patch',
    'patches/experimental-mingw-jmp-alignment.patch',
    'patches/shadow-integer-r16-fetch.patch',
)


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inventory(root):
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        base = Path(directory)
        dirs[:] = sorted(d for d in dirs if d != '.git' and not (base == root and d == 'out'))
        for name in dirs:
            entry = base / name
            if entry.is_symlink() or entry.is_junction():
                raise ValueError('Enlace inesperado en las fuentes: ' + str(entry))
        for name in sorted(files):
            if name == '.git':
                continue
            entry = base / name
            if entry.is_symlink() or entry.is_junction():
                raise ValueError('Enlace inesperado en las fuentes: ' + str(entry))
            relative = entry.relative_to(root).as_posix()
            result[relative] = sha(entry)
    if not result:
        raise ValueError('Las fuentes están vacías.')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('record', 'verify'))
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--toolset', type=Path, required=True)
    args = parser.parse_args()
    work, tool = args.work.resolve(), args.toolset.resolve()
    marker = work / 'sdk-build-inputs.json'
    inputs = {name: sha(ROOT / name) for name in RECIPE}
    for relative in ('cmake/.source.zip', 'ninja/.source.zip', 'python/.source.zip',
                     'mingw/.source.zip', 'shader/resolve-full32-signed.dxbc',
                     'shader/resolve_full_32bpp_cs.h'):
        inputs['toolset/' + relative] = sha(tool / relative)
    state = {'format': 1, 'work': str(work), 'toolset': str(tool),
             'inputs': inputs, 'sources': inventory(work / 'src')}
    if args.action == 'record':
        if marker.exists():
            raise ValueError('El registro de fuentes ya existe.')
        temporary = marker.with_suffix('.tmp')
        with temporary.open('x', encoding='utf-8', newline='\n') as out:
            json.dump(state, out, sort_keys=True, separators=(',', ':'))
        os.replace(temporary, marker)
        print('Fuentes e insumos registrados para reintentos.')
    else:
        recorded = json.loads(marker.read_text(encoding='utf-8'))
        if recorded != state:
            raise ValueError('Las fuentes, la receta, las rutas o los insumos cambiaron; no se reutilizará esta compilación.')
        print('Fuentes e insumos coinciden; se puede retomar la compilación.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print('No se puede verificar el estado de compilación:', exc, file=sys.stderr)
        sys.exit(1)
