"""Record or verify an SDK's local build output before publication or reuse."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import uuid

REQUIRED = ('bin/rexglue.exe', 'bin/librexruntime.dll', 'bin/librexgpu-xenos.dll',
            'lib/cmake/rexglue/rexglueConfig.cmake')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inventory(root):
    if root.is_symlink() or root.is_junction() or not root.is_dir():
        raise ValueError('Carpeta SDK inválida o enlazada.')
    files = {}
    for parent, directories, names in os.walk(root, followlinks=False):
        base = Path(parent)
        for name in directories:
            path = base / name
            if path.is_symlink() or path.is_junction():
                raise ValueError('Enlace no permitido: ' + str(path))
        for name in names:
            path = base / name
            if path.is_symlink() or path.is_junction():
                raise ValueError('Enlace no permitido: ' + str(path))
            relative = path.relative_to(root).as_posix()
            files[relative] = sha(path)
    if any(name not in files for name in REQUIRED):
        raise ValueError('El SDK está incompleto.')
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('record', 'verify'))
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, required=True)
    args = parser.parse_args()
    work = args.work.resolve()
    state = {'format': 1, 'inputs_sha256': sha(work / 'sdk-build-inputs.json'),
             'files': inventory(args.sdk)}
    marker = work / 'sdk-build-output.json'
    if args.action == 'record':
        temporary = work / ('.sdk-output-' + uuid.uuid4().hex + '.tmp')
        with temporary.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(state, stream, sort_keys=True, separators=(',', ':'))
        os.replace(temporary, marker)
        print('Inventario del SDK guardado.')
    else:
        expected = json.loads(marker.read_text(encoding='utf-8'))
        if expected != state:
            raise ValueError('El SDK o los insumos registrados cambiaron.')
        print('SDK verificado contra el inventario local.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print('No se pudo verificar el SDK:', exc, file=sys.stderr)
        sys.exit(1)
