param(
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [string]$CacheRoot = ''
)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
$work = [IO.Path]::GetFullPath($WorkingDirectory)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
if (Test-Path -LiteralPath $work) { throw "La carpeta temporal ya existe: $work" }
if ($dest.StartsWith($work + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    $work.StartsWith($dest + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $work -eq $dest) {
    throw 'El destino y la carpeta temporal deben ser independientes.'
}
New-Item -ItemType Directory -Path $work | Out-Null
$cache = @{}
foreach ($name in @('msvc','windows-sdk','llvm','utilities')) {
    $cache[$name] = if ($CacheRoot) { Join-Path ([IO.Path]::GetFullPath($CacheRoot)) $name } else { '' }
}
try {
    & (Join-Path $PSScriptRoot 'get_msvc.ps1') -Destination (Join-Path $work 'msvc') -PackageCache $cache['msvc']
    & (Join-Path $PSScriptRoot 'get_windows_sdk.ps1') -Destination (Join-Path $work 'windows-sdk') -PackageCache $cache['windows-sdk']
    & (Join-Path $PSScriptRoot 'get_llvm.ps1') -Destination (Join-Path $work 'llvm') -PackageCache $cache['llvm']
    & (Join-Path $PSScriptRoot 'get_build_utilities.ps1') -Destination (Join-Path $work 'utilities') -PackageCache $cache['utilities']
    & (Join-Path (Split-Path $PSScriptRoot -Parent) 'get_rexglue_sdk.ps1') -Destination (Join-Path $work 'rexglue')
    $staged = Join-Path $work 'assembled'
    & (Join-Path $PSScriptRoot 'assemble_toolset.ps1') -Destination $staged -ComponentsRoot $work
    New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
    Move-Item -LiteralPath $staged -Destination $dest
    Write-Output "Conjunto preparado: $dest"
} catch {
    Write-Warning "La preparación quedó incompleta en $work. El destino final no se reemplazó."
    throw
}
