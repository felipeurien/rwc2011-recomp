"""Prepare a local overlay that prefills the game's Enter Code field."""
import argparse
import getpass
import gzip
import hashlib
from pathlib import Path
import re
import struct
from tempfile import NamedTemporaryFile


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = Path("data/scripts/gamesystems/Unlocker.lua")
SOURCE_HASH = "bc284e765f94f5241501e67d5927447a094e80947a74232d260caae50bb235a7"

# Offsets in the supported revision's decompressed Lua 5.1 chunk.
DEFAULT_TEXT = 0xADC
CONSTANT_COUNT = 0xC00
CONSTANTS_END = 0xDE9


def prefill(original, code):
    if hashlib.sha256(original).hexdigest() != SOURCE_HASH:
        raise ValueError("Unlocker.lua does not match the supported disc revision.")
    chunk = bytearray(gzip.decompress(original))
    value = code.encode("ascii") + b"\0"
    # Append a string constant and replace LOADNIL with LOADK R6, K31.
    # R6 is the editor's initial text. Its confirmation path is untouched.
    chunk[CONSTANTS_END:CONSTANTS_END] = struct.pack("<BI", 4, len(value)) + value
    struct.pack_into("<I", chunk, CONSTANT_COUNT, 32)
    struct.pack_into("<I", chunk, DEFAULT_TEXT, 1 | (6 << 6) | (31 << 14))
    return gzip.compress(chunk, mtime=0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clear", action="store_true", help="Remove the local overlay.")
    args = parser.parse_args()
    destination = ROOT / "work/updates" / SCRIPT
    if args.clear:
        destination.unlink(missing_ok=True)
        print("Local prefill removed.")
        return
    code = getpass.getpass("Enter your 16-character game code: ").strip()
    if not re.fullmatch(r"[A-Za-z0-9]{16}", code):
        parser.error("The code must have 16 letters or digits.")
    original = (ROOT / "original/game" / SCRIPT).read_bytes()
    try:
        patched = prefill(original, code)
    except ValueError as error:
        parser.error(str(error))
    destination.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
        temporary_path = Path(temporary.name)
        temporary.write(patched)
    try:
        temporary_path.replace(destination)
    finally:
        temporary_path.unlink(missing_ok=True)
    print("Local prefill ready. Open Enter Code in the game and confirm it yourself.")


if __name__ == "__main__":
    main()
