param([Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
$parent = Split-Path $dest -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$id = [guid]::NewGuid().ToString('N')
$zip = Join-Path $parent ('.rexglue-' + $id + '.zip')
$stage = Join-Path $parent ('.rexglue-' + $id)
$url = 'https://github.com/rexglue/rexglue-sdk/releases/download/v0.10.0/rexglue-sdk-0.10.0-win-amd64.zip'
$expected = 'AD4485DA853FBE932E9F5DBB643F9B5FE85DC73775EBBAD4DF6879FE6DF0C11B'
try {
    Write-Host 'Descargando ReXGlue 0.10.0...'
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $expected) { throw 'La descarga de ReXGlue no coincide con el hash esperado.' }
    Expand-Archive -LiteralPath $zip -DestinationPath $stage
    $sdkRoot = Join-Path $stage 'win-amd64'
    $exe = Join-Path $sdkRoot 'bin/rexglue.exe'
    if (!(Test-Path -LiteralPath $exe -PathType Leaf) -or (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne '04014C2E5EEF3C40BDDC490D413E910E5BA98D81AA3DA1C1F5D43DD29728EE3A') { throw 'El contenido de ReXGlue no coincide con la versión esperada.' }
    Move-Item -LiteralPath $sdkRoot -Destination $dest
    Remove-Item -LiteralPath $stage
    Write-Output "ReXGlue preparado: $dest"
} finally {
    if (Test-Path -LiteralPath $zip -PathType Leaf) { Remove-Item -LiteralPath $zip }
}
