param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$BundleDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$Sha256,
    [Parameter(Mandatory)][ValidateRange(1,9223372036854775807)][long]$Size,
    [string]$Url = '',
    [string]$Archive = '',
    [switch]$PrepareOnly
)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath($Project)
$startup = Join-Path $projectPath 'scripts/start_game.ps1'
if (!(Test-Path -LiteralPath $startup -PathType Leaf)) { throw 'No se encontró la entrada del proyecto.' }
& (Join-Path $PSScriptRoot 'get_release_bundle.ps1') -Destination $BundleDirectory -Sha256 $Sha256 -Size $Size -Url $Url -Archive $Archive
& $startup -UseMingw -PrepareOnly:$PrepareOnly -BundleDirectory $BundleDirectory
