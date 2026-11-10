param(
    [Parameter(Mandatory)][string]$BuildDirectory,
    [Parameter(Mandatory)][string]$ShaderDirectory,
    [Parameter(Mandatory)][string]$Cmake,
    [ValidateRange(1, 64)][int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$scripts = Split-Path $PSScriptRoot -Parent
$root = Split-Path $scripts -Parent
$cache = Get-Content -LiteralPath (Join-Path $BuildDirectory 'CMakeCache.txt')
$sourceEntry = $cache | Where-Object { $_ -like 'CMAKE_HOME_DIRECTORY:INTERNAL=*' }
$compilerEntry = $cache | Where-Object { $_ -match '^CMAKE_CXX_COMPILER:[^=]+=[^=]+mingw32-clang\+\+\.exe$' }
if (!$sourceEntry -or !$compilerEntry) { throw 'Se necesita una carpeta CMake de ReXGlue configurada con LLVM/MinGW.' }
$source = ($sourceEntry -split '=', 2)[1]
$compiler = ($compilerEntry -split '=', 2)[1]

& (Join-Path $scripts 'apply_exact_patch.ps1') -SourceRoot $source -Patch (Join-Path $root 'patches/shadow-integer-r16-fetch.patch') -AllowApplied
$header = 'resolve_full_32bpp_cs.h'
$target = Join-Path $source "src/graphics/shaders/bytecode/d3d12_5_1/$header"
Copy-Item -LiteralPath (Join-Path $ShaderDirectory $header) -Destination $target -Force
# Copy-Item can preserve the source timestamp and leave an older object in Ninja.
(Get-Item -LiteralPath $target).LastWriteTimeUtc = [DateTime]::UtcNow

$savedPath = $env:Path
try {
    $env:Path = "$(Split-Path $compiler -Parent);$savedPath"
    & $Cmake --build $BuildDirectory --target rexgpu-xenos --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el complemento grafico.' }
} finally {
    $env:Path = $savedPath
}
$plugin = Join-Path $source 'out/win-amd64/librexgpu-xenos.dll'
& (Join-Path $scripts 'verify_shadow_plugin.ps1') -Plugin $plugin -Shader (Join-Path $ShaderDirectory 'resolve-full32-signed.dxbc')
Write-Output "Complemento grafico verificado: $plugin"
