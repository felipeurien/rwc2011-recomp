param([Parameter(Mandatory)][string]$Toolset, [Parameter(Mandatory)][string]$Root, [int]$Jobs = 4)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Root)
$Toolset = [IO.Path]::GetFullPath($Toolset).Replace('\','/')
$env:Path = "C:\Windows\System32;C:\Windows;$Toolset/llvm/bin;$Toolset/rexglue/bin"
Remove-Item Env:INCLUDE,Env:LIB,Env:LIBPATH,Env:WindowsSdkDir,Env:WindowsSDKVersion,Env:VCToolsInstallDir,Env:VSINSTALLDIR,Env:UniversalCRTSdkDir,Env:UCRTVersion,Env:CPATH,Env:CPLUS_INCLUDE_PATH,Env:SDKROOT,Env:CMAKE_PREFIX_PATH,Env:PYTHONHOME,Env:PYTHONPATH -ErrorAction SilentlyContinue
$env:LIB = "$Toolset/msvc/lib/x64;$Toolset/winsdk/lib/ucrt/x64;$Toolset/winsdk/lib/um/x64"
$inc = @("$Toolset/llvm/lib/clang/19/include", "$Toolset/msvc/include", "$Toolset/winsdk/include/ucrt", "$Toolset/winsdk/include/shared", "$Toolset/winsdk/include/um", "$Toolset/winsdk/include/winrt", "$Toolset/winsdk/include/cppwinrt")
$flags = '-nostdinc -nostdinc++ ' + (($inc | ForEach-Object { '-isystem "' + $_ + '"' }) -join ' ')
Push-Location $root
try {
  $expected = '8045c61254615b223591efee3bd9b34fa6a05ba1bfe1dd61719e248d454ea201'
  if ((Get-FileHash 'original/game/default.xex' -Algorithm SHA256).Hash -ne $expected) { throw 'Incompatible XEX' }
  New-Item -ItemType Directory -Force 'analysis/rexglue' | Out-Null
  Push-Location port
  try { & "$Toolset/rexglue/bin/rexglue.exe" codegen rugby2011_manifest.toml *> "$root/codegen.log"; if ($LASTEXITCODE -ne 0) { throw 'Codegen failed; see codegen.log' } } finally { Pop-Location }
  & "$Toolset/python/python.exe" scripts/check_task_sync.py
  if ($LASTEXITCODE -ne 0) { throw 'Sync audit failed' }
  & "$Toolset/python/python.exe" scripts/prepare_unlock_prefill.py
  if ($LASTEXITCODE -ne 0) { throw 'Prefill preparation failed' }
  & "$Toolset/cmake/bin/cmake.exe" -S port -B build -G Ninja "-DCMAKE_MAKE_PROGRAM=$Toolset/ninja/ninja.exe" "-DCMAKE_CXX_COMPILER=$Toolset/llvm/bin/clang++.exe" "-DCMAKE_RC_COMPILER=$Toolset/llvm/bin/llvm-rc.exe" "-DCMAKE_AR=$Toolset/llvm/bin/llvm-lib.exe" "-DCMAKE_CXX_FLAGS=$flags" '-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld' '-DCMAKE_BUILD_TYPE=RelWithDebInfo' '-DCMAKE_TRY_COMPILE_CONFIGURATION=RelWithDebInfo' "-DCMAKE_PREFIX_PATH=$Toolset/rexglue" '-DREXSDK_VERSION=0.10.0' *> configure.log
  if ($LASTEXITCODE -ne 0) { throw 'Configure failed; see configure.log' }
  & "$Toolset/cmake/bin/cmake.exe" --build build --parallel $Jobs *> build.log
  if ($LASTEXITCODE -ne 0) { throw 'Build failed; see build.log' }
  Write-Output 'Complete: build/rugby2011.exe'
} finally { Pop-Location }
