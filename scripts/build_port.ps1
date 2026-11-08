param([string]$BuildDirectory = 'build/port-shadow-integer-fetch', [int]$Jobs = 4)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$env:REXSDK -or !(Test-Path -LiteralPath "$env:REXSDK/bin/rexglue.exe")) {
    throw 'Set REXSDK to the extracted Windows x64 ReXGlue 0.10.0 SDK.'
}
$env:Path = "$env:REXSDK/bin;$env:Path"
if (!(Test-Path -LiteralPath (Join-Path $root 'original/game/default.xex'))) {
    throw 'Extract your Xbox 360 disc into original/game before building.'
}
Push-Location $root
try {
    New-Item -ItemType Directory -Path 'analysis/rexglue' -Force | Out-Null
    $buildPath = [IO.Path]::GetFullPath((Join-Path $root $BuildDirectory))
    if (!$buildPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'La compilación debe quedar dentro del proyecto.' }
    $run = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logBase = "analysis/rexglue/build-$run"
    # Generate before configuring: a fresh checkout has no sources.cmake yet.
    $codegenLog = Join-Path $root "$logBase-codegen.log"
    Push-Location (Join-Path $root 'port')
    try {
        & rexglue codegen rugby2011_manifest.toml 2>&1 | Tee-Object $codegenLog
        if ($LASTEXITCODE -ne 0) { throw "Generación fallida ($LASTEXITCODE). Ver $codegenLog" }
    } finally { Pop-Location }
    & python (Join-Path $PSScriptRoot 'check_task_sync.py')
    if ($LASTEXITCODE -ne 0) { throw 'La corrección sync no coincide con el código generado.' }
    & cmake -S port -B $buildPath -G Ninja '-DCMAKE_CXX_COMPILER=clang++' '-DCMAKE_BUILD_TYPE=RelWithDebInfo' "-DCMAKE_PREFIX_PATH=$env:REXSDK" '-DREXSDK_VERSION=0.10.0' 2>&1 | Tee-Object "$logBase-configure.log"
    $configureCode = $LASTEXITCODE
    if ($configureCode -ne 0) { throw "Configuración fallida ($configureCode). Ver $logBase-configure.log" }
    & cmake --build $buildPath --parallel $Jobs 2>&1 | Tee-Object "$logBase-build.log"
    $buildCode = $LASTEXITCODE
    @{timestamp=(Get-Date -Format o);build_directory=$buildPath;configure_exit=$configureCode;build_exit=$buildCode;executable=(Join-Path $buildPath 'rugby2011.exe')} | ConvertTo-Json | Set-Content "$logBase-result.json"
    if ($buildCode -ne 0) { throw "Compilación fallida ($buildCode). Ver $logBase-build.log" }
    Write-Output "Ejecutable: $buildPath/rugby2011.exe (dependencias junto al ejecutable)."
} finally { Pop-Location }
