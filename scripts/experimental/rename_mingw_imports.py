"""Rename guest symbols in isolated, disposable MinGW experiment trees.

Run on the SDK before building the generator, or on the port after code
generation to update its native hooks and any previously generated sources.
"""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--sdk", type=Path)
parser.add_argument("--port", type=Path)
args = parser.parse_args()

roots = []
if args.sdk:
    roots.extend(args.sdk / name for name in ("include", "src", "resources/templates"))
if args.port:
    roots.extend(args.port / name for name in ("src", "generated/default"))
if not roots:
    parser.error("select --sdk or --port")
if any(not root.is_dir() for root in roots):
    parser.error("SDK, port and generated code must already exist")
for root in roots:
    count = 0
    for path in root.rglob("*"):
        if path.suffix not in {".cpp", ".h", ".hpp", ".inl", ".inja"} or not path.is_file():
            continue
        original = path.read_bytes()
        modified = original.replace(b"__imp__", b"reximp__")
        if modified != original:
            path.write_bytes(modified)
            count += 1
    print(f"{root}: {count} files changed")
