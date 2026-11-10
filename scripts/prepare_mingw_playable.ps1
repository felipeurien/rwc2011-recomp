param(
    [string]$Iso,
    [Parameter(Mandatory)][string]$Toolset,
    [string]$Extractor = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tool = [IO.Path]::GetFullPath($Toolset)
$game = Join-Path $root 'original/game'
$workGame = Join-Path $root 'work/game'
$target = Join-Path $root 'build/mingw-playable'
$files = @('rugby2011.exe','librexruntime.dll','rexgpu-xenos.dll','libc++.dll','libunwind.dll')
$portHash = & (Join-Path $PSScriptRoot 'get_port_fingerprint.ps1') -Root $root
function Test-PreparedDirectory([string]$directory) {
    try {
        $item = Get-Item -LiteralPath $directory -Force
        if (!$item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        $manifest = Get-Content -LiteralPath (Join-Path $directory 'preparado.json') -Raw | ConvertFrom-Json
        if ($manifest.port_sha256 -ne $portHash -or $manifest.revision -ne '8045C61254615B223591EFEE3BD9B34FA6A05BA1BFE1DD61719E248D454EA201') { return $false }
        foreach ($file in $files) {
            $path = Join-Path $directory $file
            if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $manifest.files.$file) { return $false }
        }
        return $true
    } catch { return $false }
}
New-Item -ItemType Directory -Path (Join-Path $root 'build') -Force | Out-Null
$lockPath = Join-Path $root 'build/.mingw-prepare.lock'
try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Ya hay una preparación en curso. Reintentá cuando termine.' }
try {
    $ready = $null
    Write-Host '[1/4] Verificando los datos del juego...'
    & (Join-Path $PSScriptRoot 'prepare_original_game.ps1') -Iso $Iso -Extractor $Extractor

    $valid = Test-PreparedDirectory $target
    if ($valid) {
        Write-Host '[2/4] Se reutiliza la compilación verificada.'
    } else {
        if (!(Test-Path -LiteralPath $tool -PathType Container)) { throw "Falta el conjunto MinGW preparado: $tool" }
        $shader = Join-Path $tool 'shader/resolve-full32-signed.dxbc'
        $sdk = Join-Path $tool 'rexglue'
        & (Join-Path $PSScriptRoot 'verify_shadow_plugin.ps1') -Plugin (Join-Path $sdk 'bin/librexgpu-xenos.dll') -Shader $shader
        foreach ($candidate in @(Get-ChildItem -LiteralPath (Join-Path $root 'build') -Directory -Force -Filter '.mingw-*' | Sort-Object LastWriteTime -Descending)) {
            if ($candidate.Name -notmatch '^\.mingw-[0-9a-f]{32}$' -or ($candidate.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
            $candidateReady = Join-Path $candidate.FullName 'playable'
            if (Test-PreparedDirectory $candidateReady) {
                try { & (Join-Path $PSScriptRoot 'verify_shadow_plugin.ps1') -Plugin (Join-Path $candidateReady 'rexgpu-xenos.dll') -Shader $shader }
                catch { continue }
                $ready = $candidateReady
                Write-Host "[2/4] Se recuperó una compilación terminada: $candidateReady"
                break
            }
        }
        if (!$ready) {
        $stage = Join-Path $root ('build/.mingw-' + [guid]::NewGuid().ToString('N'))
        foreach ($folder in @('original','scripts','analysis/rexglue','port/generated')) { New-Item -ItemType Directory -Path (Join-Path $stage $folder) -Force | Out-Null }
        Write-Host "[2/4] Compilando el juego. Carpeta de trabajo: $stage"
        & robocopy (Join-Path $root 'port') (Join-Path $stage 'port') /E /XD generated build out .cache /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "No se pudo copiar el port ($LASTEXITCODE)." }
        Copy-Item -LiteralPath (Join-Path $root 'port/generated/rexglue.cmake') -Destination (Join-Path $stage 'port/generated')
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'check_task_sync.py') -Destination (Join-Path $stage 'scripts')
        New-Item -ItemType Junction -Path (Join-Path $stage 'original/game') -Target $game | Out-Null
        & (Join-Path $PSScriptRoot 'experimental/build_mingw_port.ps1') -Project $stage -Sdk $sdk -Mingw (Join-Path $tool 'mingw') -Cmake (Join-Path $tool 'cmake/bin/cmake.exe') -Ninja (Join-Path $tool 'ninja/ninja.exe') -Python (Join-Path $tool 'python/python.exe') -Shader $shader
        $ready = Join-Path $stage 'playable'
        New-Item -ItemType Directory -Path $ready | Out-Null
        foreach ($file in $files) {
            $source = Join-Path $stage "build/mingw/$file"
            if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Falta el archivo compilado: $source" }
            Copy-Item -LiteralPath $source -Destination (Join-Path $ready $file)
            if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath (Join-Path $ready $file)).Hash) { throw "No se pudo verificar la copia de $file." }
        }
        $hashes = [ordered]@{}
        foreach ($file in $files) { $hashes[$file] = (Get-FileHash -LiteralPath (Join-Path $ready $file)).Hash }
        $manifest = [ordered]@{ revision='8045C61254615B223591EFEE3BD9B34FA6A05BA1BFE1DD61719E248D454EA201'; port_sha256=$portHash; files=$hashes }
        $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $ready 'preparado.json') -Encoding UTF8
        Write-Host "La carpeta de trabajo queda para diagnóstico: $stage"
        }
    }
    Write-Host '[3/4] Verificando los datos para jugar...'
    & (Join-Path $PSScriptRoot 'repair_game_copy.ps1') -Source $game -Destination $workGame -Verifier (Join-Path $PSScriptRoot 'verify_game.ps1')
    Write-Host '[4/4] Preparando extras y lanzador...'
    $python = Join-Path $tool 'python/python.exe'
    if (!(Test-Path -LiteralPath $python -PathType Leaf)) { throw "Falta Python portable para preparar extras: $python" }
    & $python (Join-Path $PSScriptRoot 'prepare_unlock_prefill.py')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el campo de extras.' }
    $overlay = Join-Path $root 'work/updates/data/scripts/gamesystems/Unlocker.lua'
    if (!(& (Join-Path $PSScriptRoot 'verify_unlock_prefill.ps1') -Path $overlay)) { throw 'La capa de extras generada no coincide con la versión esperada.' }
    & (Join-Path $PSScriptRoot 'sync_unlock_backup.ps1') -Root $root
    if ($ready) {
        $previous = $null
        if (Test-Path -LiteralPath $target) {
            $previous = Join-Path (Split-Path $target -Parent) ('.mingw-anterior-' + [guid]::NewGuid().ToString('N'))
            Move-Item -LiteralPath $target -Destination $previous
        }
        try { [IO.Directory]::Move($ready, $target) }
        catch {
            if ($previous -and !(Test-Path -LiteralPath $target)) { Move-Item -LiteralPath $previous -Destination $target }
            throw
        }
        if ($previous) { Write-Host "La versión anterior se conservó en $previous" }
    }
    & (Join-Path $PSScriptRoot 'update_mingw_launcher.ps1') -Root $root
    Write-Host 'Preparación MinGW terminada.'
} finally { $lock.Dispose() }
