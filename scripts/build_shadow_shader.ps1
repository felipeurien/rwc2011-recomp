param(
    [Parameter(Mandatory)][string]$Fxc,
    [Parameter(Mandatory)][string]$Destination
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fxcPath = [IO.Path]::GetFullPath($Fxc)
$destinationPath = [IO.Path]::GetFullPath($Destination)
if (!(Test-Path -LiteralPath $fxcPath -PathType Leaf)) { throw 'No se encontró el compilador de shaders.' }
if (Test-Path -LiteralPath $destinationPath) { throw "El destino ya existe: $destinationPath" }
New-Item -ItemType Directory -Path $destinationPath | Out-Null
$manifest = Get-Content -LiteralPath (Join-Path $root 'analysis/rexglue/shadow-shader-sources.json') -Raw | ConvertFrom-Json
foreach ($file in $manifest.files) {
    $target = Join-Path $destinationPath $file.path
    New-Item -Path (Split-Path $target -Parent) -ItemType Directory -Force | Out-Null
    Invoke-WebRequest -Uri $file.url -OutFile $target -UseBasicParsing
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $file.sha256) { throw "Fuente incorrecta: $($file.path)" }
}
Push-Location $destinationPath
try {
    & (Join-Path $PSScriptRoot 'apply_exact_patch.ps1') -SourceRoot $destinationPath -Patch (Join-Path $root 'patches/shadow-signed-resolve.patch')
    $shader = Join-Path $destinationPath 'resolve-full32-signed.dxbc'
    & $fxcPath /T cs_5_1 /E main /O3 /D SHADING_LANGUAGE_HLSL_XE=1 /I $destinationPath /Fo $shader (Join-Path $destinationPath 'src/xenia/gpu/shaders/resolve_full_32bpp.cs.xesl')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el shader.' }
    $expected = '3BE64E932AC65FB2A41E3D379B053A530B1593158CE0FDD7A81185821C0A61C5'
    if ((Get-FileHash -LiteralPath $shader -Algorithm SHA256).Hash -ne $expected) { throw 'El shader generado difiere del shader probado; revisar la versión de fxc.' }
    $bytes = [IO.File]::ReadAllBytes($shader)
    $header = [Text.StringBuilder]::new()
    [void]$header.AppendLine('// Generated from pinned Xenia sources with shadow-signed-resolve.patch.')
    [void]$header.AppendLine('const BYTE resolve_full_32bpp_cs[] = {')
    for ($i = 0; $i -lt $bytes.Length; $i += 20) {
        $last = [Math]::Min($i + 19, $bytes.Length - 1)
        [void]$header.AppendLine('  ' + (($bytes[$i..$last] | ForEach-Object { $_.ToString() }) -join ', ') + ',')
    }
    [void]$header.AppendLine('};')
    $headerPath = Join-Path $destinationPath 'resolve_full_32bpp_cs.h'
    [IO.File]::WriteAllText($headerPath, $header.ToString(), [Text.Encoding]::ASCII)
    Write-Output "Shader validado: $shader"
    Write-Output "Header para ReXGlue: $headerPath"
} finally { Pop-Location }
