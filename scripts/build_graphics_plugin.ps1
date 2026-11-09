param(
    [Parameter(Mandatory)][string]$Sdk,
    [Parameter(Mandatory)][string]$Fxc,
    [Parameter(Mandatory)][string]$Destination,
    [string]$Toolset = '',
    [int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$destinationPath = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) { throw "El destino ya existe: $destinationPath" }
New-Item -ItemType Directory -Path $destinationPath | Out-Null
$source = Join-Path $destinationPath 'rexglue-source'
$archive = Join-Path $destinationPath 'rexglue-source.zip'
$commit = 'f5337cdc947ff6d4c4196737e2c807a48f2a1fc2'
Write-Host 'Descargando fuentes ReXGlue...'
Invoke-WebRequest -Uri "https://codeload.github.com/rexglue/rexglue-sdk/zip/$commit" -OutFile $archive -UseBasicParsing
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne 'E116DD1561F1E163600E6393D3C3DF12CEAF089771B23B41D0E572056E9DB394') { throw 'Las fuentes ReXGlue no coinciden con la versión fijada.' }
$unpacked = Join-Path $destinationPath 'source-extract'
Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
Move-Item -LiteralPath (Join-Path $unpacked "rexglue-sdk-$commit") -Destination $source
Remove-Item -LiteralPath $unpacked
& (Join-Path $PSScriptRoot 'apply_exact_patch.ps1') -SourceRoot $source -Patch (Join-Path $root 'patches/shadow-integer-r16-fetch.patch')
$cmakeFile = Join-Path $source 'src/graphics/CMakeLists.txt'
$cmakeText = [IO.File]::ReadAllText($cmakeFile)
$alias = 'add_library(rex::gpu-xenos ALIAS rexgpu-xenos)'
if (([regex]::Matches($cmakeText, [regex]::Escape($alias))).Count -ne 1) { throw 'No se encontró el alias gráfico esperado.' }
[IO.File]::WriteAllText($cmakeFile, $cmakeText.Replace($alias, '# Alias provided by the installed SDK.'), [Text.UTF8Encoding]::new($false))
$shaderDir = Join-Path $destinationPath 'shader'
& (Join-Path $PSScriptRoot 'build_shadow_shader.ps1') -Fxc $Fxc -Destination $shaderDir
Copy-Item -LiteralPath (Join-Path $shaderDir 'resolve_full_32bpp_cs.h') -Destination (Join-Path $source 'src/graphics/shaders/bytecode/d3d12_5_1/resolve_full_32bpp_cs.h') -Force
$build = Join-Path $destinationPath 'build'
$cmake = 'cmake'
$extra = @('-DCMAKE_CXX_COMPILER=clang-cl')
$saved = @{}
if ($Toolset) {
    $tool = [IO.Path]::GetFullPath($Toolset).Replace('\','/')
    foreach ($file in @('llvm/bin/clang++.exe','llvm/bin/lld-link.exe','llvm/bin/llvm-rc.exe','llvm/bin/llvm-lib.exe','llvm/bin/llvm-mt.exe','ninja/ninja.exe','cmake/bin/cmake.exe')) {
        if (!(Test-Path -LiteralPath "$tool/$file" -PathType Leaf)) { throw "Falta en el conjunto portable: $file" }
    }
    $compiler = Join-Path $destinationPath 'compiler'
    New-Item -ItemType Directory -Path (Join-Path $compiler 'bin') | Out-Null
    Copy-Item -LiteralPath "$tool/llvm/bin/clang++.exe" -Destination (Join-Path $compiler 'bin/clang-cl.exe')
    New-Item -ItemType Junction -Path (Join-Path $compiler 'lib') -Target "$tool/llvm/lib" | Out-Null
    $compilerPath = ([IO.Path]::GetFullPath((Join-Path $compiler 'bin/clang-cl.exe'))).Replace('\','/')
    $names = @('Path','INCLUDE','LIB','LIBPATH','WindowsSdkDir','VCToolsInstallDir','VSINSTALLDIR','CMAKE_PREFIX_PATH')
    foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    $env:Path = "$env:WINDIR/System32;$env:WINDIR;$compiler/bin;$tool/llvm/bin;$tool/ninja;$tool/cmake/bin;$tool/rexglue/bin"
    $env:INCLUDE = "$tool/msvc/include;$tool/winsdk/include/ucrt;$tool/winsdk/include/shared;$tool/winsdk/include/um;$tool/winsdk/include/winrt;$tool/winsdk/include/cppwinrt"
    $env:LIB = "$tool/msvc/lib/x64;$tool/winsdk/lib/ucrt/x64;$tool/winsdk/lib/um/x64"
    foreach ($name in @('LIBPATH','WindowsSdkDir','VCToolsInstallDir','VSINSTALLDIR','CMAKE_PREFIX_PATH')) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
    $cmake = "$tool/cmake/bin/cmake.exe"
    $extra = @("-DCMAKE_CXX_COMPILER=$compilerPath", "-DCMAKE_MAKE_PROGRAM=$tool/ninja/ninja.exe", "-DCMAKE_RC_COMPILER=$tool/llvm/bin/llvm-rc.exe", "-DCMAKE_MT=$tool/llvm/bin/llvm-mt.exe", "-DCMAKE_LINKER=$tool/llvm/bin/lld-link.exe", "-DCMAKE_AR=$tool/llvm/bin/llvm-lib.exe", '-DCMAKE_TRY_COMPILE_CONFIGURATION=RelWithDebInfo')
}
try {
    & $cmake -S (Join-Path $root 'scripts/gpu/plugin') -B $build -G Ninja '-DCMAKE_BUILD_TYPE=RelWithDebInfo' @extra "-DCMAKE_PREFIX_PATH=$([IO.Path]::GetFullPath($Sdk))" "-DRUGBY_SDK_SOURCE=$source"
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo configurar el complemento gráfico.' }
    & $cmake --build $build --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el complemento gráfico.' }
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}
$plugin = Join-Path $build 'graphics/rexgpu-xenosrd.dll'
if (!(Test-Path -LiteralPath $plugin -PathType Leaf)) { throw 'No se encontró el complemento gráfico compilado.' }
& (Join-Path $PSScriptRoot 'verify_shadow_plugin.ps1') -Plugin $plugin -Shader (Join-Path $shaderDir 'resolve-full32-signed.dxbc')
Write-Output "Complemento gráfico: $plugin"
Write-Output "SHA-256: $((Get-FileHash -LiteralPath $plugin).Hash)"
