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
$manifest = Get-Content -LiteralPath (Join-Path $root 'analysis/baseline/game-manifest.json') -Raw | ConvertFrom-Json
if (@($manifest.files).Count -ne $manifest.file_count) { throw 'El inventario del juego está incompleto.' }
[long]$dataBytes = ($manifest.files | Measure-Object -Property size -Sum).Sum
& (Join-Path $PSScriptRoot 'check_free_space.ps1') -Path $parent -RequiredBytes ($dataBytes + 64MB) -Step 'extraer el disco'
$staging = Join-Path $parent ('.game-extract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging | Out-Null
try {
    & $extractorPath -q -x -d $staging $isoPath
    if ($LASTEXITCODE -ne 0) { throw "No se pudo extraer la imagen ($LASTEXITCODE). Comprobá que sea una ISO de Xbox 360 y que no esté dañada." }
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory $staging
    Move-Item -LiteralPath $staging -Destination $destinationPath
    Write-Output "Copia del juego preparada: $destinationPath"
} catch {
    Write-Warning "La extracción incompleta queda para inspección en: $staging"
    throw
}
