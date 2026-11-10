param([Parameter(Mandatory)][string]$RuntimeDirectory)
$ErrorActionPreference = 'Stop'
$expected = @{
    'msvcp140.dll' = '0F885B509A685D2BBFA652FED26B5FB31D88FBDAB0A978C641D1C7B8AA460AA9'
    'msvcp140_atomic_wait.dll' = '640B2AEFCED484D0368EEA5BDD06ADDD0658A3A70A49256E560D6923B404A479'
    'vcruntime140.dll' = 'D5E4D9A3E835FA679450145D6A7D94E36573A509317111904D9B3712C30D9066'
    'vcruntime140_1.dll' = '1F2D41C4AA5DB0BC33EBF7B66D72943A817D7CE6CBE880502A9403823633093F'
}
foreach ($file in $expected.Keys) {
    $path = Join-Path $RuntimeDirectory $file
    if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected[$file]) {
        throw "Falta el runtime de Visual C++ comprobado o su contenido difiere: $path"
    }
}
