param(
    [Parameter(Mandatory)][string]$Destination,
    [string[]]$RetryCache = @()
)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
New-Item -ItemType Directory -Path $dest | Out-Null
$zip = Join-Path $dest 'mingit.zip'
$url = 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/MinGit-2.56.0.4-64-bit.zip'
& (Join-Path $PSScriptRoot 'get_verified_archive.ps1') -Destination $zip -Url $url `
    -Sha256 'E3BF78351FE777FBA47DDEE5950082F8A98BB0F02604FDC7BA3EE2CB68FFA877' -RetryCache $RetryCache
Expand-Archive -LiteralPath $zip -DestinationPath $dest
$bin = Join-Path $dest 'cmd'
if (!(Test-Path -LiteralPath (Join-Path $bin 'git.exe') -PathType Leaf)) { throw 'Falta git.exe en la descarga.' }
Write-Output $bin
