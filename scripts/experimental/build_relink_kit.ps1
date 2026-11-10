param(
    [Parameter(Mandatory)][string]$Toolset,
    [Parameter(Mandatory)][string]$Destination,
    [ValidateRange(1,64)][int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source = Join-Path $root 'src'
$tool = [IO.Path]::GetFullPath($Toolset)
$destinationPath = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) { throw "El destino ya existe: $destinationPath" }
foreach ($path in @($root, $tool, $destinationPath)) {
    if ($path.Contains(' ')) { throw 'Esta receta experimental requiere rutas sin espacios.' }
}
& (Join-Path $root 'scripts/get_build_components.ps1') -Toolset $tool
$python = Join-Path $tool 'python/python.exe'
& $python (Join-Path $PSScriptRoot 'get_llvm_mingw.py') --toolset $tool
if ($LASTEXITCODE -ne 0) { throw 'No se pudo verificar LLVM/MinGW.' }
$shader = Join-Path $root 'shader'
if ((Get-FileHash -LiteralPath (Join-Path $shader 'resolve-full32-signed.dxbc')).Hash -ne '3BE64E932AC65FB2A41E3D379B053A530B1593158CE0FDD7A81185821C0A61C5' -or
    (Get-FileHash -LiteralPath (Join-Path $shader 'resolve_full_32bpp_cs.h')).Hash -ne '2F1C1433BF3AE32287F740BC2A1C93536739F6EC16B6CD5D1DE844A9D1612690') { throw 'El shader o su header no coinciden con la versión fijada.' }
# ReXGlue checks for these markers even when all sources came from an archive.
# Do not overwrite an actual checkout or create missing source directories.
foreach ($name in @('cli11','libmspack','FFmpeg','tomlplusplus','simde','xxHash','spdlog','fmt','utfcpp','imgui','sdl3')) {
    $folder = Join-Path $source "thirdparty/$name"
    if (!(Test-Path -LiteralPath $folder -PathType Container) -or !(Get-ChildItem -LiteralPath $folder -Force | Select-Object -First 1)) { throw "Faltan fuentes: $folder" }
    $marker = Join-Path $folder '.git'
    if (!(Test-Path -LiteralPath $marker)) { [IO.File]::WriteAllText($marker, 'source archive; not a Git checkout') }
}
$cmake = Join-Path $tool 'cmake/bin/cmake.exe'
$ninja = Join-Path $tool 'ninja/ninja.exe'
$mingw = Join-Path $tool 'mingw/bin'
$build = Join-Path $destinationPath 'build'
$sdk = Join-Path $destinationPath 'sdk'
New-Item -ItemType Directory -Path $destinationPath | Out-Null
$maps = "-ffile-prefix-map=$($source.Replace('\','/'))=rexglue-source -ffile-prefix-map=$($build.Replace('\','/'))=rexglue-build -ffile-prefix-map=$($tool.Replace('\','/'))=toolset"
$savedPath = $env:Path
try {
    $env:Path = "$mingw;$env:WINDIR\System32;$env:WINDIR"
    & $cmake -S $source -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$ninja" `
        "-DCMAKE_C_COMPILER=$mingw/x86_64-w64-mingw32-clang.exe" `
        "-DCMAKE_CXX_COMPILER=$mingw/x86_64-w64-mingw32-clang++.exe" `
        '-DCMAKE_BUILD_TYPE=Release' "-DCMAKE_C_FLAGS=$maps" "-DCMAKE_CXX_FLAGS=-mssse3 $maps" `
        '-DREXGLUE_ENABLE_TRACY=OFF'
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo configurar ReXGlue.' }
    & (Join-Path $PSScriptRoot 'build_mingw_graphics.ps1') -BuildDirectory $build -ShaderDirectory $shader -Cmake $cmake -Jobs $Jobs
    & $cmake --build $build --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar ReXGlue.' }
    & $cmake --install $build --prefix $sdk
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar el SDK reconstruido.' }
    & (Join-Path $root 'scripts/verify_shadow_plugin.ps1') -Plugin (Join-Path $sdk 'bin/librexgpu-xenos.dll') -Shader (Join-Path $shader 'resolve-full32-signed.dxbc')
    Write-Host "SDK reconstruido: $sdk. Las fuentes pueden editarse antes de volver a ejecutar en otro destino."
} finally { $env:Path = $savedPath }
