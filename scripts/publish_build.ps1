param(
    [Parameter(Mandatory)][string]$Build,
    [Parameter(Mandatory)][string]$Gpu,
    [Parameter(Mandatory)][string]$RuntimeDirectory,
    [Parameter(Mandatory)][string]$Target
)
$ErrorActionPreference = 'Stop'
$parent = Split-Path $Target -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$lockPath = Join-Path $parent '.portable-publish.lock'
try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Otra preparación está publicando la compilación. Volvé a intentarlo cuando termine.' }
try {
    $backup = Join-Path $parent '.portable-previous'
    # Recover a previous interruption between the two directory moves.
    if ((Test-Path -LiteralPath $backup) -and !(Test-Path -LiteralPath $Target)) {
        Move-Item -LiteralPath $backup -Destination $Target
        Write-Host 'Se recuperó la compilación anterior interrumpida.'
    }
    & (Join-Path $PSScriptRoot 'verify_runtime.ps1') -RuntimeDirectory $RuntimeDirectory
    $runtimeFiles = @('msvcp140.dll','msvcp140_atomic_wait.dll','vcruntime140.dll','vcruntime140_1.dll')
    $files = @('rugby2011.exe','rexruntimerd.dll','TracyClientrd.dll','rexgpu-xenosrd.dll') + $runtimeFiles
    $sources = @{}
    foreach ($file in $files) {
        $source = if ($file -in $runtimeFiles) { Join-Path $RuntimeDirectory $file } elseif ($file -eq 'rexgpu-xenosrd.dll') { $Gpu } else { Join-Path $Build $file }
        if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Falta el archivo preparado: $source" }
        $sources[$file] = $source
    }
    $same = Test-Path -LiteralPath $Target -PathType Container
    if ($same) {
        foreach ($file in $files) {
            $actual = Join-Path $Target $file
            if (!(Test-Path -LiteralPath $actual -PathType Leaf) -or (Get-FileHash -LiteralPath $actual -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $sources[$file] -Algorithm SHA256).Hash) { $same = $false; break }
        }
    }
    if ($same) { Write-Host 'Se reutilizó la compilación publicada.'; return }
    $stage = Join-Path $parent ('.port-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    foreach ($file in $files) {
        Copy-Item -LiteralPath $sources[$file] -Destination (Join-Path $stage $file)
        if ((Get-FileHash -LiteralPath (Join-Path $stage $file) -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $sources[$file] -Algorithm SHA256).Hash) { throw "No se pudo verificar la copia de $file. Carpeta temporal: $stage" }
    }
    if (Test-Path -LiteralPath $backup) {
        $archive = Join-Path $parent ('.portable-anterior-' + [guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $backup -Destination $archive
        Write-Host "Se conservó una compilación anterior en $archive"
    }
    if (Test-Path -LiteralPath $Target) { Move-Item -LiteralPath $Target -Destination $backup }
    try { Move-Item -LiteralPath $stage -Destination $Target }
    catch {
        if ((Test-Path -LiteralPath $backup) -and !(Test-Path -LiteralPath $Target)) { Move-Item -LiteralPath $backup -Destination $Target }
        throw
    }
    Write-Host 'Compilación publicada; se conservó la versión anterior para recuperación.'
} finally { $lock.Dispose() }
