param([string]$Destination = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$Destination) { $Destination = Join-Path $root 'tools/extract-xiso-portable' }
$destinationPath = [IO.Path]::GetFullPath($Destination)
$exe = Join-Path $destinationPath 'artifacts/extract-xiso.exe'
$license = Join-Path $destinationPath 'artifacts/LICENSE.TXT'
$exeHash = '7E97536F978735D586A2F78327AA337B9A19B3E364FA715316FB42D07D33E0B7'
if (Test-Path -LiteralPath $destinationPath) {
    if (!(Test-Path -LiteralPath $exe -PathType Leaf) -or !(Test-Path -LiteralPath $license -PathType Leaf) -or (Get-FileHash -LiteralPath $exe).Hash -ne $exeHash) {
        throw "El extractor existente no coincide con la versión esperada: $destinationPath"
    }
    Write-Output $exe
    return
}
$parent = Split-Path $destinationPath -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$id = [guid]::NewGuid().ToString('N')
$zip = Join-Path $parent ('.extract-xiso-' + $id + '.zip')
$stage = Join-Path $parent ('.extract-xiso-' + $id)
$url = 'https://github.com/XboxDev/extract-xiso/releases/download/build-202609111233/extract-xiso-Win64_Release.zip'
$expected = 'FC891DFA72F08E3838A2F8B7EC34A8E4D61678DA1CC8FEE879677F00BF114CE3'
try {
    Write-Host 'Descargando el extractor de la ISO...'
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $expected) { throw 'La descarga del extractor no coincide con el hash esperado.' }
    Expand-Archive -LiteralPath $zip -DestinationPath $stage
    $stagedExe = Join-Path $stage 'artifacts/extract-xiso.exe'
    if (!(Test-Path -LiteralPath (Join-Path $stage 'artifacts/LICENSE.TXT') -PathType Leaf) -or !(Test-Path -LiteralPath $stagedExe -PathType Leaf) -or (Get-FileHash -LiteralPath $stagedExe).Hash -ne $exeHash) { throw 'El contenido del extractor no coincide con la versión esperada.' }
    Move-Item -LiteralPath $stage -Destination $destinationPath
    Write-Output $exe
} finally {
    if (Test-Path -LiteralPath $zip -PathType Leaf) { Remove-Item -LiteralPath $zip }
}
