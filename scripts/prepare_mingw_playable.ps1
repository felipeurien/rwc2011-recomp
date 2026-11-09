param(
    [string]$Iso,
    [Parameter(Mandatory)][string]$Toolset,
    [string]$Extractor
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tool = [IO.Path]::GetFullPath($Toolset)
$game = Join-Path $root 'original/game'
$shader = Join-Path $tool 'shader/resolve-full32-signed.dxbc'
$sdk = Join-Path $tool 'rexglue'
$python = Join-Path $tool 'python/python.exe'
$target = Join-Path $root 'build/mingw-playable'
$files = @('rugby2011.exe', 'librexruntime.dll', 'rexgpu-xenos.dll', 'libc++.dll', 'libunwind.dll')

if (Test-Path -LiteralPath $target) {
    foreach ($file in $files) {
        if (!(Test-Path -LiteralPath (Join-Path $target $file) -PathType Leaf)) { throw "Falta $file en $target" }
    }
    & (Join-Path $PSScriptRoot 'verify_shadow_plugin.ps1') -Plugin (Join-Path $target 'rexgpu-xenos.dll') -Shader $shader
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory $game
    & (Join-Path $PSScriptRoot 'build_launcher.ps1')
    return
}

if (!(Test-Path -LiteralPath $game)) {
    if (!$Iso) { throw 'Elegi una ISO para preparar los archivos del juego.' }
    if (!$Extractor) { $Extractor = & (Join-Path $PSScriptRoot 'get_extractor.ps1') }
    & (Join-Path $PSScriptRoot 'prepare_iso.ps1') -Iso $Iso -Extractor $Extractor
} else {
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory $game
}
if (!(Test-Path -LiteralPath $tool -PathType Container)) {
    & (Join-Path $PSScriptRoot 'prepare_mingw_toolset.ps1') -Destination $tool
}
& (Join-Path $PSScriptRoot 'verify_shadow_plugin.ps1') -Plugin (Join-Path $sdk 'bin/librexgpu-xenos.dll') -Shader $shader

# Build in a separate tree because MinGW changes the native hook sources.
$stage = Join-Path $root ('build/.mingw-' + [guid]::NewGuid().ToString('N'))
foreach ($folder in @('original', 'scripts', 'analysis/rexglue', 'port/generated')) {
    New-Item -ItemType Directory -Path (Join-Path $stage $folder) -Force | Out-Null
}
& robocopy (Join-Path $root 'port') (Join-Path $stage 'port') /E /XD generated build out .cache /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "No se pudo copiar el port a $stage" }
Copy-Item -LiteralPath (Join-Path $root 'port/generated/rexglue.cmake') -Destination (Join-Path $stage 'port/generated')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'check_task_sync.py') -Destination (Join-Path $stage 'scripts')
New-Item -ItemType Junction -Path (Join-Path $stage 'original/game') -Target $game | Out-Null
& (Join-Path $PSScriptRoot 'experimental/build_mingw_port.ps1') -Project $stage -Sdk $sdk `
    -Mingw (Join-Path $tool 'mingw') -Cmake (Join-Path $tool 'cmake/bin/cmake.exe') `
    -Ninja (Join-Path $tool 'ninja/ninja.exe') -Python $python -Shader $shader

$overlay = Join-Path $root 'work/updates/data/scripts/gamesystems/Unlocker.lua'
if (!(Test-Path -LiteralPath $overlay)) {
    & $python (Join-Path $PSScriptRoot 'prepare_unlock_prefill.py')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el texto de extras.' }
}

$ready = Join-Path $stage 'playable'
New-Item -ItemType Directory -Path $ready | Out-Null
foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $stage "build/mingw/$file") -Destination $ready
}
[IO.Directory]::Move($ready, $target)
& (Join-Path $PSScriptRoot 'build_launcher.ps1')
try { & (Join-Path $PSScriptRoot 'remove_mingw_stage.ps1') -Parent (Split-Path $target -Parent) -Stage $stage }
catch { Write-Warning "El juego esta listo. No se pudo limpiar $stage : $($_.Exception.Message)" }
