"""Fetch and patch the pinned ReXGlue sources for a Windows LLVM/MinGW build."""

import argparse
from pathlib import Path
import subprocess
import sys


REVISION = "f5337cdc947ff6d4c4196737e2c807a48f2a1fc2"
SUBMODULES = (
    "FFmpeg", "cli11", "fmt", "imgui", "inja", "libmspack", "o1heap", "sdl3",
    "simde", "spdlog", "tomlplusplus", "utfcpp", "xxHash",
)
SCRIPTS = Path(__file__).resolve().parent
PATCHES = SCRIPTS.parents[1] / "patches"


def git(*args, cwd=None, capture=False):
    result = subprocess.run(
        ["git", "-c", "core.autocrlf=false", "-c", "core.symlinks=false", *args],
        cwd=cwd, check=True, stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout


def materialize_mspack_links(root):
    entries = git("ls-files", "-sz", "--", "cabextract/mspack", cwd=root, capture=True)
    for entry in entries.split(b"\0"):
        if not entry.startswith(b"120000 "):
            continue
        metadata, name = entry.split(b"\t", 1)
        link = root / name.decode("utf-8")
        target_name = git("cat-file", "blob", metadata.split()[1].decode("ascii"), cwd=root, capture=True)
        target = (link.parent / target_name.decode("utf-8")).resolve(strict=True)
        if not target.is_relative_to(root) or link.read_bytes() != target_name:
            raise ValueError(f"Unexpected libmspack link: {link}")
        link.write_bytes(target.read_bytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    source = args.destination.resolve()
    if source.exists():
        parser.error(f"destination already exists: {source}")

    git("clone", "--depth", "1", "--branch", "v0.10.0",
        "https://github.com/rexglue/rexglue-sdk.git", str(source))
    if git("rev-parse", "HEAD", cwd=source, capture=True).decode().strip() != REVISION:
        raise ValueError("Unexpected ReXGlue revision")
    git("submodule", "update", "--init", "--depth", "1", "--jobs", "6", "--",
        *(f"thirdparty/{name}" for name in SUBMODULES), cwd=source)

    git("apply", str(PATCHES / "experimental-rexglue-mingw.patch"), cwd=source)
    git("apply", "--unidiff-zero", str(PATCHES / "experimental-mingw-jmp-alignment.patch"), cwd=source)
    config = source / "thirdparty/FFmpeg/config_windows_x86_64.h"
    original = config.read_bytes()
    define = b"#define HAVE_LIBC_MSVCRT 1"
    if original.count(define) != 1:
        raise ValueError(f"Unexpected FFmpeg configuration: {config}")
    config.write_bytes(original.replace(define, b"#define HAVE_LIBC_MSVCRT 0"))
    materialize_mspack_links(source / "thirdparty/libmspack")
    subprocess.run([sys.executable, str(SCRIPTS / "rename_mingw_imports.py"),
                    "--sdk", str(source)], check=True)
    print(f"ReXGlue sources prepared: {source}")


if __name__ == "__main__":
    main()
