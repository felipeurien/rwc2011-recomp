param(
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string]$ComponentsRoot
)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
$components = [IO.Path]::GetFullPath($ComponentsRoot)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
$msvc = Join-Path $components 'msvc'
$sdk = Join-Path $components 'windows-sdk/extracted/Windows Kits/10'
$llvm = Join-Path $components 'llvm/llvm'
$utils = Join-Path $components 'utilities'
$rex = Join-Path $components 'rexglue'
$items = @(
    @((Join-Path $msvc 'Microsoft.VC.14.44.17.14.CRT.Headers.base/Contents/VC/Tools/MSVC/14.44.35207/include'), 'msvc/include'),
    @((Join-Path $msvc 'Microsoft.VC.14.44.17.14.CRT.x64.Store.base/Contents/VC/Tools/MSVC/14.44.35207/lib/x64'), 'msvc/lib/x64'),
    @((Join-Path $sdk 'Include/10.0.26100.0'), 'winsdk/include'),
    @((Join-Path $sdk 'Lib/10.0.26100.0/ucrt/x64'), 'winsdk/lib/ucrt/x64'),
    @((Join-Path $sdk 'Lib/10.0.26100.0/um/x64'), 'winsdk/lib/um/x64'),
    @($llvm, 'llvm'), @((Join-Path $utils 'cmake'), 'cmake'),
    @((Join-Path $utils 'ninja'), 'ninja'), @((Join-Path $utils 'python'), 'python'), @($rex, 'rexglue')
)
foreach ($item in $items) { if (!(Test-Path -LiteralPath $item[0] -PathType Container)) { throw "Falta el componente: $($item[0])" } }
New-Item -ItemType Directory -Path $dest | Out-Null
foreach ($item in $items) {
    $target = Join-Path $dest $item[1]
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    & robocopy $item[0] $target /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "No se pudo copiar $($item[0]) (código $LASTEXITCODE)." }
}
foreach ($name in @('winrt','cppwinrt')) { New-Item -ItemType Directory -Path (Join-Path $dest "winsdk/include/$name") -Force | Out-Null }
Write-Output "Conjunto armado: $dest"
