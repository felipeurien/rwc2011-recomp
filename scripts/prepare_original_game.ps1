param(
    [string]$Iso = '',
    [string]$Extractor = '',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$parent = Join-Path $root 'original'
$game = Join-Path $parent 'game'
$verifier = Join-Path $PSScriptRoot 'verify_game.ps1'
function Test-Game([string]$path) {
    try {
        if (!(Test-Path -LiteralPath $path -PathType Container)) { return $false }
        & $verifier -GameDirectory $path | Out-Null
        return $true
    } catch { return $false }
}
if (Test-Game $game) {
    if ($CheckOnly) { return $true }
    Write-Host 'Se reutiliza la extracción original verificada.'
    return
}
$ready = $null
if (Test-Path -LiteralPath $parent -PathType Container) {
    foreach ($candidate in @(Get-ChildItem -LiteralPath $parent -Directory -Force -Filter '.game-ready-*')) {
        if ($candidate.Name -cnotmatch '^\.game-ready-[0-9a-f]{32}$' -or ($candidate.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
        if (Test-Game $candidate.FullName) { $ready = $candidate.FullName; break }
    }
}
if ($CheckOnly) { return [bool]$ready }
if (!$ready) {
    if (!$Iso) { throw 'La extracción original falta o está dañada. Elegí una ISO compatible para recuperarla.' }
    if (!$Extractor) { $Extractor = & (Join-Path $PSScriptRoot 'get_extractor.ps1') }
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $ready = Join-Path $parent ('.game-ready-' + [guid]::NewGuid().ToString('N'))
    & (Join-Path $PSScriptRoot 'prepare_iso.ps1') -Iso $Iso -Extractor $Extractor -Destination $ready
} else { Write-Host "Se recuperó una extracción terminada: $ready" }
$previous = $null
if (Test-Path -LiteralPath $game) {
    $previous = Join-Path $parent ('.game-anterior-' + [guid]::NewGuid().ToString('N'))
    Move-Item -LiteralPath $game -Destination $previous
}
try { [IO.Directory]::Move($ready, $game) }
catch {
    if ($previous -and !(Test-Path -LiteralPath $game)) { Move-Item -LiteralPath $previous -Destination $game }
    throw
}
if ($previous) { Write-Host "La extracción anterior se conservó en $previous" }
Write-Host "Extracción original verificada: $game"
