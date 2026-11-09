param(
    [Parameter(Mandatory)][string]$Destination,
    [string]$PackageCache = ''
)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
New-Item -ItemType Directory -Path $dest | Out-Null
$packages = @(
    @{ Name='7zr.exe'; Url='https://github.com/ip7z/7zip/releases/download/24.09/7zr.exe'; Hash='D2C0045523CF053A6B43F9315E9672FC2535F06AEADD4FFA53C729CD8B2B6DFE' },
    @{ Name='7z2409-x64.exe'; Url='https://github.com/ip7z/7zip/releases/download/24.09/7z2409-x64.exe'; Hash='BDD1A33DE78618D16EE4CE148B849932C05D0015491C34887846D431D29F308E' },
    @{ Name='LLVM-19.1.5-win64.exe'; Url='https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.5/LLVM-19.1.5-win64.exe'; Hash='9B29856202D82047B504A9E501D66080BED0EAFF3F1127191F4F361E0E00C770' }
)
foreach ($package in $packages) {
    $target = Join-Path $dest $package.Name
    $cached = if ($PackageCache) { Join-Path $PackageCache $package.Name } else { '' }
    if ($cached -and (Test-Path -LiteralPath $cached -PathType Leaf)) { Copy-Item -LiteralPath $cached -Destination $target }
    else { Write-Host "Descargando $($package.Name)..."; Invoke-WebRequest -Uri $package.Url -OutFile $target -UseBasicParsing }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $package.Hash) { throw "Descarga incorrecta: $($package.Name)" }
}
$zipTool = Join-Path $dest '7zip'
& (Join-Path $dest '7zr.exe') x (Join-Path $dest '7z2409-x64.exe') "-o$zipTool" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el extractor de LLVM.' }
$llvm = Join-Path $dest 'llvm'
& (Join-Path $zipTool '7z.exe') x (Join-Path $dest 'LLVM-19.1.5-win64.exe') "-o$llvm" 'bin\clang++.exe' 'bin\lld-link.exe' 'bin\llvm-lib.exe' 'bin\llvm-rc.exe' 'bin\llvm-mt.exe' 'lib\clang\19\include\*' -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudo extraer LLVM.' }
foreach ($file in @('bin/clang++.exe','bin/lld-link.exe','bin/llvm-lib.exe','bin/llvm-rc.exe','bin/llvm-mt.exe','lib/clang/19/include/stdint.h')) {
    if (!(Test-Path -LiteralPath (Join-Path $llvm $file) -PathType Leaf)) { throw "Falta un archivo de LLVM: $file" }
}
Write-Output "LLVM extraído: $llvm"
