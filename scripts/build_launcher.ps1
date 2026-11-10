param([switch]$SelectionKits)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (!(Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'Falta el compilador de .NET Framework de Windows.'
}

$name = if ($SelectionKits) { 'Probar kits de selecciones.exe' } else { 'Jugar Rugby 2011.exe' }
$output = Join-Path $root $name
$temporary = Join-Path $root ('.launcher-' + [guid]::NewGuid().ToString('N') + '.exe')
$compilerArgs = @('/nologo', '/target:winexe', '/platform:x64', '/codepage:65001',
    '/optimize+', '/reference:System.Windows.Forms.dll', "/out:$temporary",
    (Join-Path $PSScriptRoot 'RugbyLauncher.cs'))
if ($SelectionKits) { $compilerArgs += '/define:SELECTION_KITS' }
try {
    & $compiler @compilerArgs
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $temporary -PathType Leaf)) {
        throw 'No se pudo compilar el lanzador de Rugby 2011.'
    }
    if (Test-Path -LiteralPath $output) {
        $previous = Join-Path $root ('.launcher-anterior-' + [guid]::NewGuid().ToString('N') + '.exe')
        [IO.File]::Replace($temporary, $output, $previous)
    } else {
        Move-Item -LiteralPath $temporary -Destination $output
    }
    Write-Output $output
} finally {
    if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
}
