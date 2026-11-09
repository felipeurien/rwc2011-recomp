param(
    [Parameter(Mandatory)][string]$Iso,
    [string]$Extractor,
    [Parameter(Mandatory)][string]$Toolset,
    [Parameter(Mandatory)][string]$CorrectedGpuPlugin
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'original/game'
$workGame = Join-Path $root 'work/game'
$target = Join-Path $root 'build/port-shadow-integer-fetch'
$gpu = [IO.Path]::GetFullPath($CorrectedGpuPlugin)
$expectedGpu = '2A3F9AA56FBC3454928BE7DD735F7095BD682B94B1C6470C9BD04209513A767F'
if (!(Test-Path -LiteralPath $gpu -PathType Leaf) -or (Get-FileHash -LiteralPath $gpu -Algorithm SHA256).Hash -ne $expectedGpu) {
    throw 'Falta el complemento gráfico corregido de la versión comprobada.'
}
if (!(Test-Path -LiteralPath $game)) {
    if (!$Extractor) { $Extractor = & (Join-Path $PSScriptRoot 'get_extractor.ps1') }
    & (Join-Path $PSScriptRoot 'prepare_iso.ps1') -Iso $Iso -Extractor $Extractor
} else {
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory $game
}
& (Join-Path $PSScriptRoot 'build_with_toolset.ps1') -Toolset $Toolset
$overlay = Join-Path $root 'work/updates/data/scripts/gamesystems/Unlocker.lua'
if (!(Test-Path -LiteralPath $overlay)) {
    & (Join-Path $Toolset 'python/python.exe') (Join-Path $PSScriptRoot 'prepare_unlock_prefill.py')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el texto de extras.' }
}
$build = Join-Path $root 'build/portable'
foreach ($file in @('rugby2011.exe','rexruntimerd.dll','TracyClientrd.dll')) {
    if (!(Test-Path -LiteralPath (Join-Path $build $file) -PathType Leaf)) { throw "Falta $file en $build" }
}
if (Test-Path -LiteralPath $target) {
    foreach ($file in @('rugby2011.exe','rexruntimerd.dll','TracyClientrd.dll','rexgpu-xenosrd.dll')) {
        $expected = if ($file -eq 'rexgpu-xenosrd.dll') { $gpu } else { Join-Path $build $file }
        $actual = Join-Path $target $file
        if (!(Test-Path -LiteralPath $actual -PathType Leaf) -or (Get-FileHash -LiteralPath $actual).Hash -ne (Get-FileHash -LiteralPath $expected).Hash) { throw "La carpeta $target ya existe y sus archivos difieren; no se reemplazará." }
    }
} else {
    $stage = Join-Path (Split-Path $target -Parent) ('.port-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Copy-Item -LiteralPath (Join-Path $build 'rugby2011.exe'),(Join-Path $build 'rexruntimerd.dll'),(Join-Path $build 'TracyClientrd.dll') -Destination $stage
    Copy-Item -LiteralPath $gpu -Destination (Join-Path $stage 'rexgpu-xenosrd.dll')
    Move-Item -LiteralPath $stage -Destination $target
}
New-Item -ItemType Directory -Path (Split-Path $workGame -Parent) -Force | Out-Null
if (Test-Path -LiteralPath $workGame) {
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory $workGame
} else {
    $stage = Join-Path (Split-Path $workGame -Parent) ('.game-' + [guid]::NewGuid().ToString('N'))
    & robocopy $game $stage /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "No se pudieron copiar los datos del juego ($LASTEXITCODE). Copia incompleta: $stage" }
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory $stage
    Move-Item -LiteralPath $stage -Destination $workGame
}
& (Join-Path $PSScriptRoot 'build_launcher.ps1')
Write-Output 'Preparación terminada: abrir Jugar Rugby 2011.exe.'
