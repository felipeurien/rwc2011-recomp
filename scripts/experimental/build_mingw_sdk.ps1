param(
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string]$Toolset,
    [ValidateRange(1,64)][int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$destinationPath = [IO.Path]::GetFullPath($Destination)
$tool = [IO.Path]::GetFullPath($Toolset)
$exists = Test-Path -LiteralPath $destinationPath
$resume = Test-Path -LiteralPath (Join-Path $destinationPath 'sdk-build-inputs.json') -PathType Leaf
$owner = Join-Path $destinationPath '.sdk-work-owner.json'
if ($exists -and !$resume -and !(Test-Path -LiteralPath $owner -PathType Leaf)) {
    throw "La carpeta no tiene un registro de esta preparación; conservála y usá otra: $destinationPath"
}
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if (!$git) { throw 'Se necesita Git para obtener las fuentes fijadas.' }
if (!$exists) { New-Item -ItemType Directory -Path $destinationPath | Out-Null }
$source = Join-Path $destinationPath 'src'
$build = Join-Path $destinationPath 'build'
$sdk = Join-Path $destinationPath 'sdk'
$python = Join-Path $tool 'python/python.exe'
$cmake = Join-Path $tool 'cmake/bin/cmake.exe'
$ninja = Join-Path $tool 'ninja/ninja.exe'
$mingw = Join-Path $tool 'mingw/bin'
$shader = Join-Path $tool 'shader'
foreach ($file in @($python,$cmake,$ninja,(Join-Path $mingw 'x86_64-w64-mingw32-clang.exe'),(Join-Path $mingw 'x86_64-w64-mingw32-clang++.exe'),(Join-Path $shader 'resolve_full_32bpp_cs.h'),(Join-Path $shader 'resolve-full32-signed.dxbc'))) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Falta una herramienta o shader: $file" }
}
$sourceMap = $source.Replace('\','/')
$buildMap = $build.Replace('\','/')
$toolMap = $tool.Replace('\','/')
if ($sourceMap.Contains(' ') -or $buildMap.Contains(' ') -or $toolMap.Contains(' ')) { throw 'Para este ensayo, usá rutas de herramientas y destino sin espacios.' }
$maps = "-ffile-prefix-map=$sourceMap=rexglue-source -ffile-prefix-map=$buildMap=rexglue-build -ffile-prefix-map=$toolMap=toolset"
$savedPath = $env:Path
try { $lock = [IO.File]::Open((Join-Path $destinationPath '.sdk-build.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Ya hay una compilación de SDK en esta carpeta.' }
try {
    $state = Join-Path $PSScriptRoot 'sdk_build_state.py'
    if ($resume) {
        & $python $state verify --work $destinationPath --toolset $tool
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo validar el estado para reanudar.' }
    } else {
        $identity = [ordered]@{
            format = 1
            work = $destinationPath
            toolset = $tool
            build_script = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
            source_script = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'prepare_mingw_sdk_sources.py') -Algorithm SHA256).Hash
        } | ConvertTo-Json -Compress
        if (Test-Path -LiteralPath $owner -PathType Leaf) {
            if (([IO.File]::ReadAllText($owner)) -cne $identity) { throw 'La preparación incompleta pertenece a otra receta o carpeta; no se modificará.' }
        } else {
            $ownerTemp = Join-Path $destinationPath ('.sdk-owner-' + [guid]::NewGuid().ToString('N') + '.tmp')
            [IO.File]::WriteAllText($ownerTemp, $identity, [Text.UTF8Encoding]::new($false))
            [IO.File]::Move($ownerTemp, $owner)
        }
        if (Test-Path -LiteralPath $source) {
            $oldSource = Join-Path $destinationPath ('src-incompleto-' + [guid]::NewGuid().ToString('N'))
            Move-Item -LiteralPath $source -Destination $oldSource
            Write-Host "Las fuentes incompletas se conservaron en $oldSource"
        }
        & $python (Join-Path $PSScriptRoot 'prepare_mingw_sdk_sources.py') $source
        if ($LASTEXITCODE -ne 0) { throw 'No se pudieron preparar las fuentes.' }
        $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        & (Join-Path (Split-Path $PSScriptRoot -Parent) 'apply_exact_patch.ps1') -SourceRoot $source -Patch (Join-Path $root 'patches/shadow-integer-r16-fetch.patch') -AllowApplied
        Copy-Item -LiteralPath (Join-Path $shader 'resolve_full_32bpp_cs.h') -Destination (Join-Path $source 'src/graphics/shaders/bytecode/d3d12_5_1/resolve_full_32bpp_cs.h') -Force
        & $python $state record --work $destinationPath --toolset $tool
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo registrar el estado para reintentos.' }
    }
    $env:Path = "$mingw;$env:WINDIR\System32;$env:WINDIR"
    & $cmake -S $source -B $build -G Ninja "-DCMAKE_MAKE_PROGRAM=$ninja" `
        "-DCMAKE_C_COMPILER=$mingw/x86_64-w64-mingw32-clang.exe" `
        "-DCMAKE_CXX_COMPILER=$mingw/x86_64-w64-mingw32-clang++.exe" `
        '-DCMAKE_BUILD_TYPE=Release' "-DCMAKE_C_FLAGS=$maps" "-DCMAKE_CXX_FLAGS=-mssse3 $maps" `
        '-DREXGLUE_ENABLE_TRACY=OFF'
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo configurar ReXGlue.' }
    & (Join-Path $PSScriptRoot 'build_mingw_graphics.ps1') -BuildDirectory $build -ShaderDirectory $shader -Cmake $cmake -Jobs $Jobs
    & $cmake --build $build --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar ReXGlue.' }
    if (Test-Path -LiteralPath $sdk) {
        $oldSdk = Join-Path $destinationPath ('sdk-anterior-' + [guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $sdk -Destination $oldSdk
        Write-Host "La instalación incompleta se conservó en $oldSdk"
    }
    & $cmake --install $build --prefix $sdk
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar el SDK en la carpeta de prueba.' }
    & (Join-Path (Split-Path $PSScriptRoot -Parent) 'verify_shadow_plugin.ps1') -Plugin (Join-Path $sdk 'bin/librexgpu-xenos.dll') -Shader (Join-Path $shader 'resolve-full32-signed.dxbc')
    & $python (Join-Path $PSScriptRoot 'scan_local_paths.py') --directory $sdk
    if ($LASTEXITCODE -ne 0) { throw 'El SDK compilado contiene rutas del perfil local.' }
    Write-Host "SDK sin rutas del perfil comprobadas: $sdk"
    Write-Host "Se conservan las fuentes y objetos de prueba en: $destinationPath"
} finally { $env:Path = $savedPath; $lock.Dispose() }
