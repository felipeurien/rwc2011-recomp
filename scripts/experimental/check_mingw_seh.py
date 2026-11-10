"""Reject guest SEH scopes unsupported by the experimental MinGW build."""
import argparse
from pathlib import Path
import re
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generated', required=True, type=Path)
    args = parser.parse_args()
    files = sorted(p for p in args.generated.rglob('*') if p.is_file() and p.suffix.lower() in ('.cpp', '.h', '.hpp'))
    if not files:
        parser.error('No hay codigo generado para inspeccionar.')
    pattern = re.compile(r'\b__(?:try|except|finally)\b')
    for path in files:
        match = pattern.search(path.read_text(encoding='utf-8'))
        if match:
            line = path.read_text(encoding='utf-8').count('\n', 0, match.start()) + 1
            print(f'Ambito SEH no compatible con MinGW: {path}:{line}', file=sys.stderr)
            return 1
    print(f'Codigo generado: {len(files)} archivos sin ambitos SEH explicitos.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
