$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (!(Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'Falta el compilador de .NET Framework de Windows.'
}

$name = 'Jugar Rugby 2011.exe'
$output = Join-Path $root $name
$compilerArgs = @('/nologo', '/target:winexe', '/platform:x64', '/codepage:65001',
    '/optimize+', '/reference:System.Windows.Forms.dll', "/out:$output",
    (Join-Path $PSScriptRoot 'RugbyLauncher.cs'))
& $compiler @compilerArgs
if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo compilar el lanzador de Rugby 2011.'
}
Write-Output $output
