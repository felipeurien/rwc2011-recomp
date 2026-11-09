param(
    [Parameter(Mandatory)][string]$Destination,
    [string]$PackageCache = '',
    [string[]]$RetryCache = @()
)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
New-Item -ItemType Directory -Path $dest | Out-Null
$packages = @(
    @{Name='cmake.zip';Url='https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-windows-x86_64.zip';Hash='D163CD3AB4959B0A53FA8988F2DDBD2E6C501658201E6A154386BAD9DBE4F836'},
    @{Name='ninja.zip';Url='https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip';Hash='F550FEC705B6D6FF58F2DB3C374C2277A37691678D6ABA463ADCBB129108467A'},
    @{Name='python.zip';Url='https://www.python.org/ftp/python/3.14.0/python-3.14.0-embed-amd64.zip';Hash='8D4D3590C10449D78AA4375F534E6D5F3027D67FDC362DD1A882279DB6F90FDF'}
)
foreach ($p in $packages) {
    $target = Join-Path $dest $p.Name
    $cached = if ($PackageCache) { Join-Path $PackageCache $p.Name } else { '' }
    & (Join-Path $PSScriptRoot 'get_verified_archive.ps1') -Destination $target -Url $p.Url -Sha256 $p.Hash `
        -Cached $cached -RetryCache $RetryCache
}
$cmakeTemp = Join-Path $dest 'cmake-extract'
Expand-Archive -LiteralPath (Join-Path $dest 'cmake.zip') -DestinationPath $cmakeTemp
Move-Item -LiteralPath (Join-Path $cmakeTemp 'cmake-3.31.6-windows-x86_64') -Destination (Join-Path $dest 'cmake')
Remove-Item -LiteralPath $cmakeTemp
Expand-Archive -LiteralPath (Join-Path $dest 'ninja.zip') -DestinationPath (Join-Path $dest 'ninja')
Expand-Archive -LiteralPath (Join-Path $dest 'python.zip') -DestinationPath (Join-Path $dest 'python')
foreach ($file in @('cmake/bin/cmake.exe','ninja/ninja.exe','python/python.exe')) {
    if (!(Test-Path -LiteralPath (Join-Path $dest $file) -PathType Leaf)) { throw "Falta la herramienta: $file" }
}
Write-Output "Herramientas extraídas: $dest"
