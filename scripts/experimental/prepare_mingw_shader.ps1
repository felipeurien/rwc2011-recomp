param(
    [Parameter(Mandatory)][string]$Toolset,
    [Parameter(Mandatory)][string]$Fxc
)
$ErrorActionPreference = 'Stop'
$tool = [IO.Path]::GetFullPath($Toolset)
New-Item -ItemType Directory -Path $tool -Force | Out-Null
$scripts = Split-Path $PSScriptRoot -Parent
$expected = '3BE64E932AC65FB2A41E3D379B053A530B1593158CE0FDD7A81185821C0A61C5'
function Test-Shader([string]$directory) {
    try {
        $item = Get-Item -LiteralPath $directory -Force
        if (!$item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        $shader = Join-Path $directory 'resolve-full32-signed.dxbc'
        $headerPath = Join-Path $directory 'resolve_full_32bpp_cs.h'
        foreach ($path in @($shader, $headerPath)) {
            $file = Get-Item -LiteralPath $path -Force
            if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        }
        if ((Get-FileHash -LiteralPath $shader -Algorithm SHA256).Hash -ne $expected) { return $false }
        $bytes = [IO.File]::ReadAllBytes($shader)
        $header = [Text.StringBuilder]::new()
        [void]$header.AppendLine('// Generated from pinned Xenia sources with shadow-signed-resolve.patch.')
        [void]$header.AppendLine('const BYTE resolve_full_32bpp_cs[] = {')
        for ($i = 0; $i -lt $bytes.Length; $i += 20) {
            $last = [Math]::Min($i + 19, $bytes.Length - 1)
            [void]$header.AppendLine('  ' + (($bytes[$i..$last] | ForEach-Object { $_.ToString() }) -join ', ') + ',')
        }
        [void]$header.AppendLine('};')
        return ([IO.File]::ReadAllText($headerPath) -ceq $header.ToString())
    } catch { return $false }
}
try { $lock = [IO.File]::Open((Join-Path $tool '.shader.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Ya hay una preparación del shader en curso.' }
try {
    $destination = Join-Path $tool 'shader'
    if (Test-Shader $destination) { Write-Host 'Se reutiliza el shader verificado.'; return }
    $stage = $null
    foreach ($candidate in @(Get-ChildItem -LiteralPath $tool -Directory -Force -Filter '.shader-*')) {
        if ($candidate.Name -cmatch '^\.shader-[0-9a-f]{32}$' -and (Test-Shader $candidate.FullName)) {
            $stage = $candidate.FullName
            Write-Host "Se recuperó el shader verificado: $stage"
            break
        }
    }
    if (!$stage) {
        $stage = Join-Path $tool ('.shader-' + [guid]::NewGuid().ToString('N'))
        & (Join-Path $scripts 'build_shadow_shader.ps1') -Fxc $Fxc -Destination $stage
        if (!(Test-Shader $stage)) { throw "El shader generado no pasó la verificación: $stage" }
    }
    $previous = $null
    if (Test-Path -LiteralPath $destination) {
        $previous = Join-Path $tool ('.shader-anterior-' + [guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $destination -Destination $previous
    }
    try { [IO.Directory]::Move($stage, $destination) }
    catch {
        if ($previous -and !(Test-Path -LiteralPath $destination)) { Move-Item -LiteralPath $previous -Destination $destination }
        throw
    }
    if ($previous) { Write-Host "El shader anterior se conservó en $previous" }
    Write-Host "Shader verificado: $destination"
} finally { $lock.Dispose() }
