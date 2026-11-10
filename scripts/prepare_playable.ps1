param(
    [string]$Iso,
    [string]$Extractor,
    [Parameter(Mandatory)][string]$Toolset,
    [Parameter(Mandatory)][string]$CorrectedGpuPlugin,
    [Parameter(Mandatory)][string]$RuntimeDirectory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'original/game'
$workGame = Join-Path $root 'work/game'
$target = Join-Path $root 'build/port-shadow-integer-fetch'
$gpu = [IO.Path]::GetFullPath($CorrectedGpuPlugin)
$expectedGpu = '2A3F9AA56FBC3454928BE7DD735F7095BD682B94B1C6470C9BD04209513A767F'
& (Join-Path $PSScriptRoot 'verify_runtime.ps1') -RuntimeDirectory $RuntimeDirectory
if (!(Test-Path -LiteralPath $gpu -PathType Leaf) -or (Get-FileHash -LiteralPath $gpu -Algorithm SHA256).Hash -ne $expectedGpu) {
    throw 'Falta el complemento gráfico corregido de la versión comprobada.'
}
Write-Host '[1/4] Verificando y preparando los datos del juego...'
if (!(Test-Path -LiteralPath $game)) {
    if (!$Iso) { throw 'Elegí una ISO para preparar el juego.' }
    if (!$Extractor) { $Extractor = & (Join-Path $PSScriptRoot 'get_extractor.ps1') }
    & (Join-Path $PSScriptRoot 'prepare_iso.ps1') -Iso $Iso -Extractor $Extractor
} else {
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory $game
}
Write-Host '[2/4] Generando y compilando el juego...'
& (Join-Path $PSScriptRoot 'build_with_toolset.ps1') -Toolset $Toolset
$build = Join-Path $root 'build/portable'
foreach ($file in @('rugby2011.exe','rexruntimerd.dll','TracyClientrd.dll')) {
    if (!(Test-Path -LiteralPath (Join-Path $build $file) -PathType Leaf)) { throw "Falta $file en $build" }
}
& (Join-Path $PSScriptRoot 'publish_build.ps1') -Build $build -Gpu $gpu -RuntimeDirectory $RuntimeDirectory -Target $target
Write-Host '[3/4] Verificando los datos para jugar...'
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
Write-Host '[4/4] Preparando el lanzador...'
& (Join-Path ([IO.Path]::GetFullPath($Toolset)) 'python/python.exe') (Join-Path $PSScriptRoot 'prepare_unlock_prefill.py')
if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el campo de extras.' }
& (Join-Path $PSScriptRoot 'build_launcher.ps1')
Write-Output 'Preparación terminada: abrir Jugar Rugby 2011.exe.'
