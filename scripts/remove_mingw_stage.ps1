param(
    [Parameter(Mandatory)][string]$Parent,
    [Parameter(Mandatory)][string]$Stage
)
$ErrorActionPreference = 'Stop'
$parentPath = (Resolve-Path -LiteralPath $Parent).Path
$stageItem = Get-Item -LiteralPath $Stage -Force
if (!$stageItem.PSIsContainer -or $stageItem.Parent.FullName -ne $parentPath -or
    $stageItem.Name -notmatch '^\.mingw-(?:[0-9a-f]{12}|[0-9a-f]{32})$' -or
    ($stageItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Carpeta temporal inesperada: $Stage"
}

# The game source is shared with the build through this one junction.
$original = Get-Item -LiteralPath (Join-Path $stageItem.FullName 'original') -Force -ErrorAction SilentlyContinue
if ($original -and $original.PSIsContainer -and !($original.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    $link = Get-Item -LiteralPath (Join-Path $original.FullName 'game') -Force -ErrorAction SilentlyContinue
    if ($link -and $link.LinkType -eq 'Junction') { [IO.Directory]::Delete($link.FullName, $false) }
}

if (Get-ChildItem -LiteralPath $stageItem.FullName -Force -Recurse -Attributes ReparsePoint | Select-Object -First 1) {
    throw "La carpeta temporal contiene enlaces inesperados: $Stage"
}
Remove-Item -LiteralPath $stageItem.FullName -Recurse -Force
