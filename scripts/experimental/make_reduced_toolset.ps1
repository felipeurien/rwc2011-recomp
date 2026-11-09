param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination,
    [string]$PythonEmbed = ''
)
$ErrorActionPreference = 'Stop'
$src = [IO.Path]::GetFullPath($Source).TrimEnd('\')
$dst = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
if (Test-Path -LiteralPath $dst) { throw "Destination already exists: $dst" }
if ($dst.StartsWith($src + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Destination must be outside the source toolset.' }
New-Item -ItemType Directory -Path $dst | Out-Null
function Copy-Tree([string]$from, [string]$to) {
    New-Item -ItemType Directory -Force -Path $to | Out-Null
    & robocopy $from $to /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copy failed: $from ($LASTEXITCODE)" }
}
foreach ($dir in @('cmake','ninja','rexglue','llvm\bin')) {
    Copy-Tree (Join-Path $src $dir) (Join-Path $dst $dir)
}
if (!$PythonEmbed) { $PythonEmbed = Join-Path $src 'python' }
Copy-Tree $PythonEmbed (Join-Path $dst 'python')
foreach ($dir in @('llvm\lib\clang\19\include','msvc\include','msvc\lib\x64','winsdk\include\ucrt','winsdk\include\shared','winsdk\include\um','winsdk\include\winrt','winsdk\include\cppwinrt','winsdk\lib\ucrt\x64','winsdk\lib\um\x64')) {
    New-Item -ItemType Directory -Force (Join-Path $dst $dir) | Out-Null
}
foreach ($manifest in @('headers-observed.txt','libraries-observed.txt')) {
    foreach ($relative in Get-Content (Join-Path $PSScriptRoot $manifest)) {
        if (!$relative) { continue }
        $file = [IO.Path]::GetFullPath((Join-Path $src $relative))
        $target = [IO.Path]::GetFullPath((Join-Path $dst $relative))
        if (!$file.StartsWith($src + '\', [StringComparison]::OrdinalIgnoreCase) -or !$target.StartsWith($dst + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Invalid manifest path: $relative" }
        New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath $file -Destination $target
    }
}
Write-Output "Reduced experimental toolset: $dst"
