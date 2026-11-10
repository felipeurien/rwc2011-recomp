param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath($Root)
$overlay = Join-Path $rootPath 'work/updates/data/scripts/gamesystems/Unlocker.lua'
$backup = Join-Path $rootPath 'work/cache-local/extras/Unlocker.lua'
$verify = Join-Path $PSScriptRoot 'verify_unlock_prefill.ps1'
$overlayExists = Test-Path -LiteralPath $overlay
$backupValid = & $verify -Path $backup
if ($overlayExists) {
    if (!(& $verify -Path $overlay)) { throw "La capa de extras está modificada o dañada y no se reemplazó: $overlay" }
    if ($backupValid) { return }
    $parent = Split-Path $backup -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $stage = Join-Path $parent ('.extras-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::Copy($overlay, $stage)
    if (!(& $verify -Path $stage)) { throw "No se pudo verificar la copia de seguridad: $stage" }
    $previous = $null
    if (Test-Path -LiteralPath $backup) {
        $previous = Join-Path $parent ('.extras-anterior-' + [guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $backup -Destination $previous
    }
    try { [IO.File]::Move($stage, $backup) }
    catch {
        if ($previous -and !(Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $previous -Destination $backup }
        throw
    }
    if ($previous) { Write-Host "La copia de extras anterior se conservó en $previous" }
    return
}
if ($backupValid) {
    $parent = Split-Path $overlay -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $stage = Join-Path $parent ('.extras-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::Copy($backup, $stage)
    if (!(& $verify -Path $stage)) { throw "No se pudo verificar la recuperación de extras: $stage" }
    try { [IO.File]::Move($stage, $overlay) }
    catch {
        if (!(& $verify -Path $overlay)) { throw }
    }
    Write-Host 'Se recuperó la capa de extras desde su copia local verificada.'
}
