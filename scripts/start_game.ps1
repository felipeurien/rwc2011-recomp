param([switch]$PrepareOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$launcher = Join-Path $root 'Jugar Rugby 2011.exe'
try {
    if (!(Test-Path -LiteralPath $launcher -PathType Leaf)) {
        $toolset = Join-Path $root 'tools/rugby-dependencies/toolset'
        $gpu = Join-Path $root 'tools/rugby-dependencies/graphics/rexgpu-xenosrd.dll'
        $mingw = Join-Path $root 'tools/rugby-dependencies/mingw-toolset'
        $mingwReady = Test-Path -LiteralPath $mingw -PathType Container
        $legacyReady = (Test-Path -LiteralPath $toolset -PathType Container) -and (Test-Path -LiteralPath $gpu -PathType Leaf)
        $useMingw = $mingwReady -or !$legacyReady
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
        if ($useMingw) {
            & (Join-Path $PSScriptRoot 'prepare_mingw_playable.ps1') -Iso $iso -Toolset $mingw
        } else {
            & (Join-Path $PSScriptRoot 'prepare_playable.ps1') -Iso $iso -Toolset $toolset -CorrectedGpuPlugin $gpu
        }
    }
    if (!$PrepareOnly) { Start-Process -FilePath $launcher -WorkingDirectory $root }
} catch {
    Write-Host "No se pudo iniciar Rugby 2011: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
