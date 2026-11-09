param(
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string]$ReXGlue,
    [Parameter(Mandatory)][string]$Python,
    [string]$VisualStudio = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools',
    [string]$WindowsKit = 'C:\Program Files (x86)\Windows Kits\10'
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $root) { throw "Destination already exists: $root" }
$vs = [IO.Path]::GetFullPath($VisualStudio)
$kit = [IO.Path]::GetFullPath($WindowsKit)
function Copy-Tree($source, $destination) {
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    & robocopy $source $destination /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copy failed: $source ($LASTEXITCODE)" }
}
New-Item -ItemType Directory -Force "$root\llvm\bin" | Out-Null
Copy-Item "$vs\VC\Tools\Llvm\x64\bin\clang++.exe", "$vs\VC\Tools\Llvm\x64\bin\lld-link.exe", "$vs\VC\Tools\Llvm\x64\bin\llvm-lib.exe", "$vs\VC\Tools\Llvm\x64\bin\llvm-rc.exe" "$root\llvm\bin"
Copy-Tree "$vs\VC\Tools\Llvm\x64\lib\clang\19\include" "$root\llvm\lib\clang\19\include"
Copy-Tree "$vs\VC\Tools\MSVC\14.44.35207\include" "$root\msvc\include"
Copy-Tree "$vs\VC\Tools\MSVC\14.44.35207\lib\x64" "$root\msvc\lib\x64"
Copy-Tree "$kit\Include\10.0.26100.0" "$root\winsdk\include"
Copy-Tree "$kit\Lib\10.0.26100.0\ucrt\x64" "$root\winsdk\lib\ucrt\x64"
Copy-Tree "$kit\Lib\10.0.26100.0\um\x64" "$root\winsdk\lib\um\x64"
Copy-Tree "$vs\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake" "$root\cmake"
New-Item -ItemType Directory -Force "$root\ninja" | Out-Null
Copy-Item "$vs\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe" "$root\ninja"
Copy-Tree $ReXGlue "$root\rexglue"
Copy-Tree $Python "$root\python"
Write-Output "Toolset copied to $root"
