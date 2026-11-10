"""Fetch and patch the pinned ReXGlue sources for a Windows LLVM/MinGW build."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import uuid


REVISION = "f5337cdc947ff6d4c4196737e2c807a48f2a1fc2"
SUBMODULES = (
    "FFmpeg", "cli11", "fmt", "imgui", "inja", "libmspack", "o1heap", "sdl3",
    "simde", "spdlog", "tomlplusplus", "utfcpp", "xxHash",
)
SCRIPTS = Path(__file__).resolve().parent
PATCHES = SCRIPTS.parents[1] / "patches"


def git(*args, cwd=None, capture=False, input_bytes=None):
    result = subprocess.run(
        ["git", "-c", "core.autocrlf=false", "-c", "core.symlinks=false", *args],
        cwd=cwd, check=True, stdout=subprocess.PIPE if capture else None, input=input_bytes,
    )
    return result.stdout


def apply_patch(source, filename, *options):
    patch = (PATCHES / filename).read_bytes().replace(b"\r\n", b"\n")
    git("apply", *options, "-", cwd=source, input_bytes=patch)


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


def verify_checkout(source, *, preserve_incomplete=False):
    if source.is_symlink() or source.is_junction():
        raise ValueError(f"Unexpected link: {source}")
    if git("rev-parse", "HEAD", cwd=source, capture=True).decode().strip() != REVISION:
        raise ValueError("Unexpected ReXGlue revision")
    if git("status", "--porcelain", "--untracked-files=all", "--ignore-submodules=all", cwd=source, capture=True):
        raise ValueError(f"Unexpected changes in downloaded source: {source}")
    for name in SUBMODULES:
        relative = f"thirdparty/{name}"
        path = source / relative
        if path.is_symlink() or path.is_junction():
            raise ValueError(f"Unexpected link in submodule: {relative}")
        expected = git("rev-parse", f"HEAD:{relative}", cwd=source, capture=True).decode().strip()
        valid = False
        if (path / '.git').exists():
            try:
                actual = git("rev-parse", "HEAD", cwd=path, capture=True).decode().strip()
                valid = actual == expected and not git("status", "--porcelain", "--untracked-files=all", cwd=path, capture=True)
            except subprocess.CalledProcessError:
                pass
        elif not path.exists() or not any(path.iterdir()):
            continue
        if not valid:
            if not preserve_incomplete:
                raise ValueError(f"Unexpected changes in downloaded submodule: {relative}")
            saved = source.parent / (source.name + '-preserved-' + name + '-' + uuid.uuid4().hex)
            saved.mkdir()
            module = source / '.git' / 'modules' / 'thirdparty' / name
            if module.is_symlink() or module.is_junction():
                raise ValueError(f"Unexpected linked submodule metadata: {relative}")
            if path.exists():
                path.rename(saved / 'worktree')
            if module.exists():
                module.rename(saved / 'git-metadata')
            print(f"Preserved incomplete or changed submodule {relative}: {saved}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    source = args.destination.resolve()
    if source.exists():
        parser.error(f"destination already exists: {source}")

    download = source.with_name(source.name + '-download')
    if download.exists():
        if download.is_symlink() or download.is_junction() or not download.is_dir():
            raise ValueError(f"Unexpected download location: {download}")
        try:
            git("rev-parse", "--verify", "HEAD", cwd=download, capture=True)
        except subprocess.CalledProcessError:
            incomplete = download.with_name(download.name + '-incomplete-' + uuid.uuid4().hex)
            download.rename(incomplete)
            print(f"Incomplete clone preserved: {incomplete}", flush=True)
    if not download.exists():
        git("clone", "--depth", "1", "--branch", "v0.10.0",
            "https://github.com/rexglue/rexglue-sdk.git", str(download))
    else:
        print(f"Checking previous download: {download}", flush=True)
    verify_checkout(download, preserve_incomplete=True)
    git("submodule", "update", "--init", "--depth", "1", "--jobs", "6", "--",
        *(f"thirdparty/{name}" for name in SUBMODULES), cwd=download)
    verify_checkout(download)
    staging = source.with_name(source.name + '-patch-' + uuid.uuid4().hex)
    shutil.copytree(download, staging)
    source = staging

    apply_patch(source, "experimental-rexglue-mingw.patch")
    apply_patch(source, "experimental-mingw-jmp-alignment.patch", "--unidiff-zero")
    config = source / "thirdparty/FFmpeg/config_windows_x86_64.h"
    original = config.read_bytes()
    define = b"#define HAVE_LIBC_MSVCRT 1"
    if original.count(define) != 1:
        raise ValueError(f"Unexpected FFmpeg configuration: {config}")
    config.write_bytes(original.replace(define, b"#define HAVE_LIBC_MSVCRT 0"))
    materialize_mspack_links(source / "thirdparty/libmspack")
    install = source / "cmake/rexglue_install.cmake"
    contents = install.read_bytes()
    marker = b"# Register in the CMake User Package Registry after install."
    if contents.count(marker) != 1:
        raise ValueError(f"Unexpected ReXGlue install rules: {install}")
    install.write_bytes(contents.split(marker, 1)[0])
    subprocess.run([sys.executable, str(SCRIPTS / "rename_mingw_imports.py"),
                    "--sdk", str(source)], check=True)
    destination = args.destination.resolve()
    source.rename(destination)
    print(f"ReXGlue sources prepared: {destination}")


if __name__ == "__main__":
    main()
