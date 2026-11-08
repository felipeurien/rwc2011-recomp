"""Apply the vanilla GPU fixes to an extracted ReXGlue 0.10.0 source tree."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.request import urlopen

root = Path(__file__).resolve().parent.parent
sdk = Path(sys.argv[1]).resolve()
fxc = Path(sys.argv[2]).resolve()
manifest = json.loads((root / "analysis/rexglue/shadow-shader-sources.json").read_text())
expected_shader = "3be64e932ac65fb2a41e3d379b053a530b1593158ce0fdd7a81185821c0a61c5"


def apply_patch(tree, filename):
    patch = root / "patches" / filename
    environment = dict(os.environ, GIT_CEILING_DIRECTORIES=str(tree.parent))
    subprocess.run(["git", "apply", "--ignore-space-change", str(patch)], cwd=tree, env=environment, check=True)


with tempfile.TemporaryDirectory() as temporary:
    shader_tree = Path(temporary)
    for source in manifest["files"]:
        with urlopen(source["url"], timeout=30) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != source["sha256"]:
            raise RuntimeError(f"Unexpected contents for {source['path']}")
        target = shader_tree / source["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    apply_patch(shader_tree, "shadow-signed-resolve.patch")
    shader = shader_tree / "src/xenia/gpu/shaders/resolve_full_32bpp.cs.xesl"
    output = shader_tree / "resolve.dxbc"
    subprocess.run(
        [str(fxc), "/nologo", "/T", "cs_5_1", "/E", "main", "/O3",
         "/D", "SHADING_LANGUAGE_HLSL_XE=1", "/Fo", str(output), str(shader)],
        check=True,
    )
    bytecode = output.read_bytes()
    if hashlib.sha256(bytecode).hexdigest() != expected_shader:
        raise RuntimeError("Unexpected shader output. Use fxc from Windows SDK 10.0.26100.0.")

    apply_patch(sdk, "shadow-integer-r16-fetch.patch")
    graphics = sdk / "src/graphics"
    cmake = graphics / "CMakeLists.txt"
    # The imported SDK already defines this alias.
    alias = "add_library(rex::gpu-xenos ALIAS rexgpu-xenos)"
    cmake.write_text(cmake.read_text().replace(alias, ""), encoding="utf-8")
    rows = [", ".join(map(str, bytecode[i:i + 20])) for i in range(0, len(bytecode), 20)]
    header = graphics / "shaders/bytecode/d3d12_5_1/resolve_full_32bpp_cs.h"
    header.write_text(
        "// Generated from the pinned Xenia sources.\n"
        "const BYTE resolve_full_32bpp_cs[] = {\n  " + ",\n  ".join(rows) + "\n};\n",
        encoding="utf-8",
    )
