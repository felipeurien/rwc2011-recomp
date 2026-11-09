param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$Sdk,
    [Parameter(Mandatory)][string]$Mingw,
    [Parameter(Mandatory)][string]$Cmake,
    [Parameter(Mandatory)][string]$Ninja,
    [Parameter(Mandatory)][string]$Python,
    [Parameter(Mandatory)][string]$Shader,
    [ValidateRange(1, 64)][int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
# Project is a disposable export. The hook sources and generated files change here.
$root = (Resolve-Path -LiteralPath $Project).Path
if (Test-Path -LiteralPath (Join-Path $root '.git')) {
    throw 'Usa una exportacion del proyecto. Este paso modifica los hooks y los archivos generados.'
}
$sdkRoot = (Resolve-Path -LiteralPath $Sdk).Path
$mingwBin = Join-Path (Resolve-Path -LiteralPath $Mingw).Path 'bin'
$port = Join-Path $root 'port'
$build = Join-Path $root 'build/mingw'
$generator = Join-Path $sdkRoot 'bin/rexglue.exe'
$gpu = Join-Path $sdkRoot 'bin/librexgpu-xenos.dll'
$compiler = Join-Path $mingwBin 'x86_64-w64-mingw32-clang++.exe'
$xex = Join-Path $root 'original/game/default.xex'
$scripts = Split-Path $PSScriptRoot -Parent
if ((Get-FileHash -LiteralPath $xex -Algorithm SHA256).Hash -ne '8045C61254615B223591EFEE3BD9B34FA6A05BA1BFE1DD61719E248D454EA201') {
    throw 'La revision de default.xex no es compatible.'
}
& (Join-Path $scripts 'verify_shadow_plugin.ps1') -Plugin $gpu -Shader $Shader

$savedPath = $env:Path
try {
    $env:Path = "$mingwBin;$env:WINDIR\System32;$env:WINDIR"
    Push-Location -LiteralPath $port
    try {
        & $generator codegen rugby2011_manifest.toml
        if ($LASTEXITCODE -ne 0) { throw 'Fallo la generacion del juego.' }
    } finally { Pop-Location }

    $header = Get-Content -LiteralPath (Join-Path $port 'generated/default/rugby2011_pch.h') -Raw
    if (!$header.Contains('alignas(16) aligned_jmp_buf') -or $header.Contains('__imp__##name')) {
        throw 'El generador no incluye los ajustes requeridos para MinGW.'
    }
    & $Python (Join-Path $PSScriptRoot 'rename_mingw_imports.py') --port $port
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la preparacion de los hooks.' }
    & $Python (Join-Path $root 'scripts/check_task_sync.py')
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la verificacion de sincronizacion.' }

    & $Cmake -S $port -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$Ninja" "-DCMAKE_CXX_COMPILER=$compiler" `
        "-Drexglue_DIR=$sdkRoot/lib/cmake/rexglue" '-DCMAKE_BUILD_TYPE=Release' '-DCMAKE_CXX_FLAGS=-mssse3'
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la configuracion del juego.' }
    & $Cmake --build $build --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion del juego.' }

    Copy-Item -LiteralPath $gpu -Destination (Join-Path $build 'rexgpu-xenos.dll') -Force
    foreach ($dll in @('libc++.dll', 'libunwind.dll')) {
        Copy-Item -LiteralPath (Join-Path $mingwBin $dll) -Destination $build -Force
    }
    Write-Output "Ejecutable: $(Join-Path $build 'rugby2011.exe')"
} finally { $env:Path = $savedPath }
