param(
    [Parameter(Mandatory)][string]$Destination,
    [string]$PackageCache = ''
)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
New-Item -ItemType Directory -Path $dest | Out-Null
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'msvc_packages.json') -Raw | ConvertFrom-Json
foreach ($package in $manifest.packages) {
    if ([IO.Path]::GetFileName($package.name) -ne $package.name -or $package.id -notmatch '^[a-zA-Z0-9.]+$') { throw 'Nombre de paquete inválido.' }
    $url = [Uri]$package.url
    if ($url.Scheme -ne 'https' -or $url.Host -ne 'download.visualstudio.microsoft.com') { throw 'Origen de paquete inválido.' }
    $zip = Join-Path $dest ($package.id + '.zip')
    $cached = if ($PackageCache) { Join-Path $PackageCache ($package.id + '.zip') } else { '' }
    if ($cached -and (Test-Path -LiteralPath $cached -PathType Leaf)) { Copy-Item -LiteralPath $cached -Destination $zip }
    else { Write-Host "Descargando $($package.name)..."; Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing }
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $package.sha256) { throw "Paquete incorrecto: $($package.name)" }
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $dest $package.id)
}
Write-Output "Paquetes de C++ extraídos: $dest"
