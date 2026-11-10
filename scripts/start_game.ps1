param([switch]$UseMingw, [switch]$PrepareOnly, [string]$BundleDirectory = '', [string]$BundleArchive = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$launcher = Join-Path $root 'Jugar Rugby 2011.exe'
$mingwToolset = Join-Path $root 'tools/rugby-dependencies/mingw-toolset'
$bundleExtractor = ''
if ($BundleDirectory) {
    $bundle = [IO.Path]::GetFullPath($BundleDirectory)
    $mingwToolset = Join-Path $bundle 'tools/rugby-dependencies/mingw-toolset'
    $bundleExtractor = Join-Path $bundle 'tools/extract-xiso-portable'
    $UseMingw = $true
}
$mingwMarker = Join-Path $root 'build/mingw-playable/preparado.json'
$legacyExe = Join-Path $root 'build/port-shadow-integer-fetch/rugby2011.exe'
$bundleConfig = Join-Path $root 'analysis/release/bundle.json'
if (!$UseMingw -and ((Test-Path -LiteralPath $mingwMarker -PathType Leaf) -or
    (((Test-Path -LiteralPath $mingwToolset -PathType Container) -or (Test-Path -LiteralPath $bundleConfig -PathType Leaf)) -and !(Test-Path -LiteralPath $legacyExe -PathType Leaf)))) { $UseMingw = $true }
try {
    if ($UseMingw) {
        $overlay = Join-Path $root 'work/updates/data/scripts/gamesystems/Unlocker.lua'
        if ((Test-Path -LiteralPath $overlay) -and !(& (Join-Path $PSScriptRoot 'verify_unlock_prefill.ps1') -Path $overlay)) {
            throw "La capa de extras está modificada o dañada y no se reemplazó: $overlay"
        }
        & (Join-Path $PSScriptRoot 'sync_unlock_backup.ps1') -Root $root
        $ready = & (Join-Path $PSScriptRoot 'test_mingw_ready.ps1') -Root $root
        if (!$ready) {
            $toolset = $mingwToolset
            $iso = ''
            $originalReady = & (Join-Path $PSScriptRoot 'prepare_original_game.ps1') -CheckOnly
            if (!$originalReady) {
                $isoFiles = @(Get-ChildItem -LiteralPath $root -Filter '*.iso' -File)
                if ($isoFiles.Count -eq 1) { $iso = $isoFiles[0].FullName }
                else {
                    Add-Type -AssemblyName System.Windows.Forms
                    $dialog = New-Object System.Windows.Forms.OpenFileDialog
                    $dialog.Title = 'Elegí tu copia de Rugby World Cup 2011'
                    $dialog.Filter = 'Imagen de disco (*.iso)|*.iso'
                    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
                    $iso = $dialog.FileName
                }
            }
            $logDir = Join-Path $root 'work/logs'
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            $log = Join-Path $logDir ('preparacion-mingw-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
            Start-Transcript -LiteralPath $log | Out-Null
            try {
                Write-Host "Registro de preparación: $log"
                if (!(Test-Path -LiteralPath $toolset -PathType Container) -and !$BundleDirectory -and (Test-Path -LiteralPath $bundleConfig -PathType Leaf)) {
                    $config = Get-Content -LiteralPath $bundleConfig -Raw | ConvertFrom-Json
                    if ($config.format -ne 1 -or $config.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or [long]$config.size -le 0) { throw 'La configuración del paquete de release es inválida.' }
                    $uri = $null
                    if (![Uri]::TryCreate([string]$config.url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.UserInfo) { throw 'La dirección del paquete de release debe ser HTTPS.' }
                    $bundle = Join-Path $root 'tools/rugby-release-bundle'
                    $installerArgs = @{ Destination=$bundle; Sha256=[string]$config.sha256; Size=[long]$config.size }
                    if ($BundleArchive) { $installerArgs.Archive = $BundleArchive } else { $installerArgs.Url = [string]$config.url }
                    & (Join-Path $PSScriptRoot 'experimental/get_release_bundle.ps1') @installerArgs
                    $toolset = Join-Path $bundle 'tools/rugby-dependencies/mingw-toolset'
                    $bundleExtractor = Join-Path $bundle 'tools/extract-xiso-portable'
                }
                if (!(Test-Path -LiteralPath $toolset -PathType Container)) { throw "Falta el conjunto MinGW preparado: $toolset" }
                $extractor = ''
                if ($bundleExtractor -and $iso) { $extractor = & (Join-Path $PSScriptRoot 'get_extractor.ps1') -Destination $bundleExtractor }
                & (Join-Path $PSScriptRoot 'prepare_mingw_playable.ps1') -Iso $iso -Toolset $toolset -Extractor $extractor
            } catch {
                Write-Host "Falló la preparación: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "Registro: $log"
                throw
            } finally { Stop-Transcript | Out-Null }
        }
        & (Join-Path $PSScriptRoot 'update_mingw_launcher.ps1') -Root $root
        if (!$PrepareOnly) { Start-Process -FilePath $launcher -WorkingDirectory $root }
        return
    }
    if (!(Test-Path -LiteralPath $launcher -PathType Leaf)) {
        $toolset = Join-Path $root 'tools/rugby-dependencies/toolset'
        $gpu = Join-Path $root 'tools/rugby-dependencies/graphics/rexgpu-xenosrd.dll'
        $runtime = Join-Path $root 'tools/rugby-dependencies/runtime'
        if (!(Test-Path -LiteralPath $toolset -PathType Container) -or !(Test-Path -LiteralPath $gpu -PathType Leaf) -or !(Test-Path -LiteralPath $runtime -PathType Container)) {
            throw 'Falta el paquete de preparación. Todavía no hay una descarga pública disponible; consultá PLAN_CLONAR_Y_JUGAR.md.'
        }
        $iso = ''
        if (!(Test-Path -LiteralPath (Join-Path $root 'original/game') -PathType Container)) {
        $isoFiles = @(Get-ChildItem -LiteralPath $root -Filter '*.iso' -File)
        if ($isoFiles.Count -eq 1) { $iso = $isoFiles[0].FullName }
        else {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Title = 'Elegí tu copia de Rugby World Cup 2011'
            $dialog.Filter = 'Imagen de disco (*.iso)|*.iso'
            if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
            $iso = $dialog.FileName
        }
        }
        $logDir = Join-Path $root 'work/logs'
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        $log = Join-Path $logDir ('preparacion-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
        Start-Transcript -LiteralPath $log | Out-Null
        try {
            Write-Host "Registro de preparación: $log"
            & (Join-Path $PSScriptRoot 'prepare_playable.ps1') -Iso $iso -Toolset $toolset -CorrectedGpuPlugin $gpu -RuntimeDirectory $runtime
        } catch {
            Write-Host "Falló la preparación: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Registro: $log"
            throw
        } finally {
            Stop-Transcript | Out-Null
        }
    }
    if (!$PrepareOnly) { Start-Process -FilePath $launcher -WorkingDirectory $root }
} catch {
    Write-Host "No se pudo iniciar Rugby 2011: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
