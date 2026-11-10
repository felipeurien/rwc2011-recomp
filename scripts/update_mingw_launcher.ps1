param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath($Root)
$launcher = Join-Path $rootPath 'Jugar Rugby 2011.exe'
$stamp = Join-Path $rootPath 'work/mingw-launcher.json'
$source = Join-Path $rootPath 'scripts/RugbyLauncher.cs'
$recipe = Join-Path $rootPath 'scripts/build_launcher.ps1'
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$recipeHash = (Get-FileHash -LiteralPath $recipe -Algorithm SHA256).Hash
$valid = $false
try {
    $previous = Get-Content -LiteralPath $stamp -Raw | ConvertFrom-Json
    $valid = (Test-Path -LiteralPath $launcher -PathType Leaf) -and $previous.source -eq $sourceHash -and $previous.recipe -eq $recipeHash -and $previous.launcher -eq (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash
} catch { $valid = $false }
if (!$valid) {
    & $recipe
    New-Item -ItemType Directory -Path (Split-Path $stamp -Parent) -Force | Out-Null
    $record = [ordered]@{source=$sourceHash; recipe=$recipeHash; launcher=(Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash}
    $temporary = Join-Path (Split-Path $stamp -Parent) ('.launcher-stamp-' + [guid]::NewGuid().ToString('N'))
    $record | ConvertTo-Json | Set-Content -LiteralPath $temporary -Encoding UTF8
    if (Test-Path -LiteralPath $stamp) { [IO.File]::Replace($temporary, $stamp, (Join-Path (Split-Path $stamp -Parent) ('.launcher-stamp-previous-' + [guid]::NewGuid().ToString('N')))) }
    else { [IO.File]::Move($temporary, $stamp) }
}
