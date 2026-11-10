param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\','/')
$scripts = Join-Path $rootPath 'scripts'
$files = @(
    (Join-Path $rootPath 'port/CMakeLists.txt'), (Join-Path $rootPath 'port/rugby2011_manifest.toml'),
    (Join-Path $rootPath 'port/generated/rexglue.cmake'), (Join-Path $scripts 'check_task_sync.py'),
    (Join-Path $scripts 'experimental/build_mingw_port.ps1'), (Join-Path $scripts 'experimental/rename_mingw_imports.py'),
    (Join-Path $scripts 'experimental/check_mingw_seh.py')
) + @(Get-ChildItem -LiteralPath (Join-Path $rootPath 'port/src') -Recurse -File | Sort-Object FullName | Select-Object -ExpandProperty FullName) `
  + @(Get-ChildItem -LiteralPath (Join-Path $rootPath 'port/config') -Recurse -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$hasher = [Security.Cryptography.SHA256]::Create()
try {
    $text = ($files | ForEach-Object {
        if (!(Test-Path -LiteralPath $_ -PathType Leaf)) { throw "Falta un archivo del port: $_" }
        $_.Substring($rootPath.Length).Replace('\','/') + ' ' + (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash
    }) -join "`n"
    [BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace('-','')
} finally { $hasher.Dispose() }
