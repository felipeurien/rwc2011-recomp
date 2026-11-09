param(
    [Parameter(Mandatory)][string]$Destination,
    [string]$PackageCache = '',
    [ValidateRange(1, 64)][int]$Jobs = 6
)
$ErrorActionPreference = 'Stop'
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) { throw "El destino ya existe: $dest" }
if (!(Get-Command git.exe -ErrorAction SilentlyContinue)) { throw 'Se necesita Git para obtener las fuentes de ReXGlue.' }
$parent = Split-Path $dest -Parent
$work = Join-Path $parent ('.mingw-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$stage = Join-Path $work 'toolset'
$experimental = Join-Path $PSScriptRoot 'experimental'
$savedPath = $env:Path
$savedProgress = $ProgressPreference
try {
    $ProgressPreference = 'SilentlyContinue'
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    & (Join-Path $experimental 'get_build_utilities.ps1') -Destination $stage -PackageCache $PackageCache
    $archive = Join-Path $work 'llvm-mingw-20251021.zip'
    $cached = if ($PackageCache) { Join-Path $PackageCache 'llvm-mingw-20251021.zip' } else { '' }
    if ($cached -and (Test-Path -LiteralPath $cached -PathType Leaf)) {
        Copy-Item -LiteralPath $cached -Destination $archive
    } else {
        Write-Host 'Descargando LLVM/MinGW...'
        $url = 'https://github.com/mstorsjo/llvm-mingw/releases/download/20251021/llvm-mingw-20251021-ucrt-x86_64.zip'
        Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '0A0CE4733B54DE8C4858ECFC2A08447DE57728DCCF9FBF7FCBA3CE7E0D0C6AF8') {
        throw 'La descarga de LLVM/MinGW no coincide con el hash esperado.'
    }
    & (Join-Path $env:WINDIR 'System32/tar.exe') -xf $archive -C $work
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo extraer LLVM/MinGW.' }
    Move-Item -LiteralPath (Join-Path $work 'llvm-mingw-20251021-ucrt-x86_64') -Destination (Join-Path $stage 'mingw')

    $fxc = Join-Path $work 'fxc'
    $cabinet = if ($PackageCache) { Join-Path $PackageCache 'sdk-tools.cab' } else { '' }
    if ($cabinet -and !(Test-Path -LiteralPath $cabinet -PathType Leaf)) { $cabinet = '' }
    & (Join-Path $experimental 'get_shader_compiler.ps1') -Destination $fxc -Cabinet $cabinet
    $shader = Join-Path $stage 'shader'
    & (Join-Path $PSScriptRoot 'build_shadow_shader.ps1') -Fxc (Join-Path $fxc 'fxc.exe') -Destination $shader

    $source = Join-Path $work 'src'
    $build = Join-Path $work 'build'
    $cmake = Join-Path $stage 'cmake/bin/cmake.exe'
    $mingw = Join-Path $stage 'mingw/bin'
    & (Join-Path $stage 'python/python.exe') (Join-Path $experimental 'prepare_mingw_sdk_sources.py') $source
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron preparar las fuentes de ReXGlue.' }

    Write-Host 'Compilando ReXGlue. Este paso puede tardar varios minutos...'
    $env:Path = "$mingw;$env:WINDIR\System32;$env:WINDIR"
    & $cmake -S $source -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$stage/ninja/ninja.exe" `
        "-DCMAKE_C_COMPILER=$mingw/x86_64-w64-mingw32-clang.exe" `
        "-DCMAKE_CXX_COMPILER=$mingw/x86_64-w64-mingw32-clang++.exe" `
        '-DCMAKE_BUILD_TYPE=Release' '-DCMAKE_CXX_FLAGS=-mssse3' '-DREXGLUE_ENABLE_TRACY=OFF'
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo configurar ReXGlue.' }
    # Build the corrected graphics target first so the full build can reuse it.
    & (Join-Path $experimental 'build_mingw_graphics.ps1') -BuildDirectory $build -ShaderDirectory $shader -Cmake $cmake -Jobs $Jobs
    & $cmake --build $build --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar ReXGlue.' }
    $sdk = Join-Path $stage 'rexglue'
    & $cmake --install $build --prefix $sdk
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el SDK de ReXGlue.' }
    & (Join-Path $PSScriptRoot 'verify_shadow_plugin.ps1') -Plugin (Join-Path $sdk 'bin/librexgpu-xenos.dll') -Shader (Join-Path $shader 'resolve-full32-signed.dxbc')
    foreach ($name in @('cmake.zip', 'ninja.zip', 'python.zip')) { Remove-Item -LiteralPath (Join-Path $stage $name) }
    [IO.Directory]::Move($stage, $dest)
    Write-Output "Herramientas preparadas: $dest"
} catch {
    Write-Warning "Preparacion incompleta en $work"
    throw
} finally {
    $env:Path = $savedPath
    $ProgressPreference = $savedProgress
}
