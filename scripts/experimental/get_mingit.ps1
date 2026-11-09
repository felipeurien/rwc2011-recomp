param([Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
New-Item -ItemType Directory -Path $dest | Out-Null
$zip = Join-Path $dest 'mingit.zip'
$url = 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/MinGit-2.56.0.4-64-bit.zip'
Write-Host 'Descargando Git portable...'
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne 'E3BF78351FE777FBA47DDEE5950082F8A98BB0F02604FDC7BA3EE2CB68FFA877') {
    throw 'Git portable no coincide con el hash publicado.'
}
Expand-Archive -LiteralPath $zip -DestinationPath $dest
Remove-Item -LiteralPath $zip
$bin = Join-Path $dest 'cmd'
if (!(Test-Path -LiteralPath (Join-Path $bin 'git.exe') -PathType Leaf)) { throw 'Falta git.exe en la descarga.' }
Write-Output $bin
