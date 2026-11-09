"""Rename guest symbols in isolated, disposable MinGW experiment trees.

Run after code generation and before building the SDK and port. This is not
part of the playable setup: the resulting executable has not passed startup.
"""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--sdk", type=Path, required=True)
parser.add_argument("--port", type=Path, required=True)
args = parser.parse_args()

roots = [args.sdk / "include", args.sdk / "src", args.port / "src",
         args.port / "generated" / "default"]
if any(not root.is_dir() for root in roots):
    parser.error("SDK, port and generated code must already exist")
for root in roots:
    count = 0
    for path in root.rglob("*"):
        if path.suffix not in {".cpp", ".h", ".hpp", ".inl"} or not path.is_file():
            continue
        original = path.read_bytes()
        modified = original.replace(b"__imp__", b"reximp__")
        if modified != original:
            path.write_bytes(modified)
            count += 1
    print(f"{root}: {count} files changed")
