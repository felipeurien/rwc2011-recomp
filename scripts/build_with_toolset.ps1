param(
    [Parameter(Mandatory)][string]$Toolset,
    [string]$BuildDirectory = 'build/portable',
    [int]$Jobs = 4,
    [switch]$UseNugetWindowsSdk
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tool = [IO.Path]::GetFullPath($Toolset).Replace('\','/')
$build = [IO.Path]::GetFullPath((Join-Path $root $BuildDirectory))
if (!$build.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'La compilación debe quedar dentro del proyecto.'
}
$xex = Join-Path $root 'original/game/default.xex'
if (!(Test-Path -LiteralPath $xex -PathType Leaf)) { throw "Falta la extracción propia del juego: $xex" }
$expected = '8045c61254615b223591efee3bd9b34fa6a05ba1bfe1dd61719e248d454ea201'
if ((Get-FileHash -LiteralPath $xex -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    throw 'La revisión de default.xex no es compatible.'
}
& (Join-Path $PSScriptRoot 'get_build_components.ps1') -Toolset $tool
if ($UseNugetWindowsSdk) {
    & "$tool/python/python.exe" (Join-Path $PSScriptRoot 'get_windows_sdk.py') --toolset $tool
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el SDK de Windows.' }
}
& (Join-Path $PSScriptRoot 'get_llvm.ps1') -Toolset $tool
$rexSdk = Join-Path $tool 'rexglue'
& (Join-Path $PSScriptRoot 'get_rexglue_sdk.ps1') -Destination $rexSdk
$env:Path = "C:\Windows\System32;C:\Windows;$tool/llvm/bin;$tool/rexglue/bin"
Remove-Item Env:INCLUDE,Env:LIB,Env:LIBPATH,Env:WindowsSdkDir,Env:WindowsSDKVersion,Env:VCToolsInstallDir,Env:VSINSTALLDIR,Env:UniversalCRTSdkDir,Env:UCRTVersion,Env:CPATH,Env:CPLUS_INCLUDE_PATH,Env:SDKROOT,Env:CMAKE_PREFIX_PATH,Env:PYTHONHOME,Env:PYTHONPATH -ErrorAction SilentlyContinue
$sdkHeaders = if ($UseNugetWindowsSdk) { "$tool/winsdk-nuget/base/c/Include/10.0.26100.0" } else { "$tool/winsdk/include" }
$sdkLibraries = if ($UseNugetWindowsSdk) { "$tool/winsdk-nuget/x64/c" } else { "$tool/winsdk/lib" }
$env:LIB = "$tool/msvc/lib/x64;$sdkLibraries/ucrt/x64;$sdkLibraries/um/x64"
$include = @("$tool/llvm/lib/clang/19/include", "$tool/msvc/include", "$sdkHeaders/ucrt", "$sdkHeaders/shared", "$sdkHeaders/um", "$sdkHeaders/winrt", "$sdkHeaders/cppwinrt")
$flags = '-nostdinc -nostdinc++ ' + (($include | ForEach-Object { '-isystem "' + $_ + '"' }) -join ' ')
$logs = Join-Path $root 'analysis/rexglue'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
Push-Location $root
try {
    Push-Location 'port'
    try {
        try {
            $ErrorActionPreference = 'Continue'
            & "$tool/rexglue/bin/rexglue.exe" codegen rugby2011_manifest.toml *> (Join-Path $logs 'portable-codegen.log')
            $codegenExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = 'Stop' }
        if ($codegenExit -ne 0) { throw 'Falló la generación. Ver portable-codegen.log.' }
    } finally { Pop-Location }
    & "$tool/python/python.exe" scripts/check_task_sync.py
    if ($LASTEXITCODE -ne 0) { throw 'Falló la verificación de sincronización.' }
    try {
        $ErrorActionPreference = 'Continue'
        & "$tool/cmake/bin/cmake.exe" -S port -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$tool/ninja/ninja.exe" "-DCMAKE_CXX_COMPILER=$tool/llvm/bin/clang++.exe" "-DCMAKE_RC_COMPILER=$tool/llvm/bin/llvm-rc.exe" "-DCMAKE_AR=$tool/llvm/bin/llvm-lib.exe" "-DCMAKE_CXX_FLAGS=$flags" '-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld' '-DCMAKE_BUILD_TYPE=RelWithDebInfo' '-DCMAKE_TRY_COMPILE_CONFIGURATION=RelWithDebInfo' "-DCMAKE_PREFIX_PATH=$tool/rexglue" '-DREXSDK_VERSION=0.10.0' *> (Join-Path $logs 'portable-configure.log')
        $configureExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    if ($configureExit -ne 0) { throw 'Falló la configuración. Ver portable-configure.log.' }
    try {
        $ErrorActionPreference = 'Continue'
        & "$tool/cmake/bin/cmake.exe" --build $build --parallel $Jobs *> (Join-Path $logs 'portable-build.log')
        $buildExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    if ($buildExit -ne 0) { throw 'Falló la compilación. Ver portable-build.log.' }
    Write-Output "Ejecutable: $(Join-Path $build 'rugby2011.exe')"
} finally { Pop-Location }
