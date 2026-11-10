"""Detect the current profile path embedded in files before distribution."""
import argparse
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    args = parser.parse_args()
    root = args.directory.resolve(strict=True)
    home = str(Path.home()).lower()
    values = {home.replace('\\', '/'), home.replace('/', '\\')}
    patterns = [value.encode(encoding) for value in values for encoding in ('utf-8', 'utf-16le')]
    hits = []
    count = 0
    for path in root.rglob('*'):
        if path.is_symlink() or path.is_junction():
            raise ValueError(f'El directorio contiene un enlace: {path}')
        if not path.is_file():
            continue
        count += 1
        tail = b''
        with path.open('rb') as f:
            while block := f.read(1024 * 1024):
                content = (tail + block).lower()
                if any(pattern in content for pattern in patterns):
                    hits.append(path.relative_to(root).as_posix())
                    break
                tail = content[-256:]
    if hits:
        print('Se encontraron rutas del perfil local:', file=sys.stderr)
        for name in hits:
            print('  ' + name, file=sys.stderr)
        return 1
    print(f'Verificados {count} archivos sin rutas del perfil local.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as exc:
        print('Falló la inspección de rutas:', exc, file=sys.stderr)
        sys.exit(1)
