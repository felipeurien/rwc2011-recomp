param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
try {
    $rootPath = [IO.Path]::GetFullPath($Root)
    $target = Join-Path $rootPath 'build/mingw-playable'
    $manifest = Get-Content -LiteralPath (Join-Path $target 'preparado.json') -Raw | ConvertFrom-Json
    $expectedRevision = '8045C61254615B223591EFEE3BD9B34FA6A05BA1BFE1DD61719E248D454EA201'
    if ($manifest.revision -ne $expectedRevision -or $manifest.port_sha256 -ne (& (Join-Path $PSScriptRoot 'get_port_fingerprint.ps1') -Root $rootPath)) { return $false }
    foreach ($file in @('rugby2011.exe','librexruntime.dll','rexgpu-xenos.dll','libc++.dll','libunwind.dll')) {
        $path = Join-Path $target $file
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $manifest.files.$file) { return $false }
    }
    $xex = Join-Path $rootPath 'work/game/default.xex'
    $overlay = Join-Path $rootPath 'work/updates/data/scripts/gamesystems/Unlocker.lua'
    if (!(Test-Path -LiteralPath $xex -PathType Leaf) -or (Get-FileHash -LiteralPath $xex -Algorithm SHA256).Hash -ne $expectedRevision -or !(& (Join-Path $PSScriptRoot 'verify_unlock_prefill.ps1') -Path $overlay)) { return $false }
    & (Join-Path $PSScriptRoot 'verify_game.ps1') -GameDirectory (Join-Path $rootPath 'work/game') | Out-Null
    return $true
} catch { return $false }
