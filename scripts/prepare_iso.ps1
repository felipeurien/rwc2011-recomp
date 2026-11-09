param(
    [Parameter(Mandatory)][string]$Iso,
    [Parameter(Mandatory)][string]$Extractor,
    [string]$Destination = 'original/game'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$isoPath = [IO.Path]::GetFullPath($Iso)
$extractorPath = [IO.Path]::GetFullPath($Extractor)
$destinationPath = if ([IO.Path]::IsPathRooted($Destination)) {
    [IO.Path]::GetFullPath($Destination)
} else {
    [IO.Path]::GetFullPath((Join-Path $root $Destination))
}
if (!(Test-Path -LiteralPath $isoPath -PathType Leaf)) { throw "No se encontró la ISO: $isoPath" }
if (!(Test-Path -LiteralPath $extractorPath -PathType Leaf)) { throw "No se encontró el extractor: $extractorPath" }
if (Test-Path -LiteralPath $destinationPath) { throw "El destino ya existe; no se reemplazará: $destinationPath" }
$parent = Split-Path $destinationPath -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$staging = Join-Path $parent ('.game-extract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging | Out-Null
try {
    & $extractorPath -q -x -d $staging $isoPath
    if ($LASTEXITCODE -ne 0) { throw "Falló la extracción ($LASTEXITCODE)." }
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory $staging
    [IO.Directory]::Move($staging, $destinationPath)
    Write-Output "Copia del juego preparada: $destinationPath"
} catch {
    Write-Warning "La extracción incompleta queda para inspección en: $staging"
    throw
}
