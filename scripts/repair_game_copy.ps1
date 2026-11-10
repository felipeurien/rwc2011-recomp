param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string]$Verifier
)
$ErrorActionPreference = 'Stop'
$sourcePath = [IO.Path]::GetFullPath($Source)
$destinationPath = [IO.Path]::GetFullPath($Destination)
$parent = Split-Path $destinationPath -Parent
if ($sourcePath.TrimEnd('\') -eq $destinationPath.TrimEnd('\')) { throw 'El origen y el destino deben ser distintos.' }
New-Item -ItemType Directory -Path $parent -Force | Out-Null
if (Test-Path -LiteralPath $destinationPath) {
    try {
        & $Verifier -GameDirectory $destinationPath
        return
    } catch {
        Write-Host 'La copia de juego no pasó la verificación; se preparará otra antes de reemplazarla.'
    }
}
# La extracción original debe estar intacta antes de tocar la copia existente.
& $Verifier -GameDirectory $sourcePath
[long]$dataBytes = (Get-ChildItem -LiteralPath $sourcePath -Recurse -File | Measure-Object -Property Length -Sum).Sum
& (Join-Path $PSScriptRoot 'check_free_space.ps1') -Path $parent -RequiredBytes ($dataBytes + 64MB) -Step 'preparar los datos del juego'
$stage = Join-Path $parent ('.game-' + [guid]::NewGuid().ToString('N'))
& robocopy $sourcePath $stage /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "No se pudieron copiar los datos ($LASTEXITCODE). Carpeta temporal: $stage" }
& $Verifier -GameDirectory $stage
$previous = $null
if (Test-Path -LiteralPath $destinationPath) {
    $previous = Join-Path $parent ('.game-anterior-' + [guid]::NewGuid().ToString('N'))
    Move-Item -LiteralPath $destinationPath -Destination $previous
}
try { [IO.Directory]::Move($stage, $destinationPath) }
catch {
    if ($previous -and !(Test-Path -LiteralPath $destinationPath)) { Move-Item -LiteralPath $previous -Destination $destinationPath }
    throw
}
if ($previous) { Write-Host "La copia anterior se conservó en $previous" }
