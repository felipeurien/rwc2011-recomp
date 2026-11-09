param(
    [Parameter(Mandatory)][string]$Destination,
    [string]$Cabinet = '',
    [string[]]$RetryCache = @()
)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
New-Item -ItemType Directory -Path $dest | Out-Null
$cab = Join-Path $dest 'sdk-tools.cab'
$url = 'https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/944d105a33e16da614cbf2a17da22954/69661e20556b3ca9456b946c2c881ddd.cab'
if ($Cabinet -and !(Test-Path -LiteralPath $Cabinet -PathType Leaf)) { throw "Falta el paquete del SDK: $Cabinet" }
& (Join-Path $PSScriptRoot 'get_verified_archive.ps1') -Destination $cab -Url $url `
    -Sha256 'BEF5B038FCE288FA1DB234BD61C3E450ABECC02F5A386248625073A83010F61E' -Cached $Cabinet -RetryCache $RetryCache
$files = @(
    @{Id='fil6dfaf6bbf56939fbab75b569ffa0fd41';Name='fxc.exe';Hash='31FA10504B1551337DE4D06EC2194143885A76A8B5A81177999E2FAA34729183'},
    @{Id='fil0d3f984977487cd87127d614f654195b';Name='d3dcompiler_47.dll';Hash='2B23EFDC8B45ADC4B79C1C0B940A906336628CD35ED80DEFD489D70D22FF6D74'}
)
foreach ($file in $files) {
    & (Join-Path $env:WINDIR 'System32/expand.exe') $cab "-F:$($file.Id)" $dest | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "No se pudo extraer $($file.Name)." }
    $source = Join-Path $dest $file.Id
    if (!(Test-Path -LiteralPath $source -PathType Leaf) -or (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $file.Hash) { throw "Archivo incorrecto: $($file.Name)" }
    Move-Item -LiteralPath $source -Destination (Join-Path $dest $file.Name)
}
Write-Output "Compilador de shaders: $(Join-Path $dest 'fxc.exe')"
