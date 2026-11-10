param([Parameter(Mandatory)][string]$Destination, [string]$Archive = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$manifest = Get-Content -Raw -LiteralPath (Join-Path $root 'analysis/rexglue/rexglue-0.10.0-files.json') | ConvertFrom-Json
$dest = [IO.Path]::GetFullPath($Destination).TrimEnd('\','/')
$parent = Split-Path $dest -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
function Test-Sdk($directory) {
    if (!(Test-Path -LiteralPath $directory -PathType Container)) { return $false }
    foreach ($entry in $manifest.files) {
        $path = Join-Path $directory ($entry.path.Replace('/', [IO.Path]::DirectorySeparatorChar))
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne $entry.size -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.sha256) { return $false }
    }
    return (@(Get-ChildItem -LiteralPath $directory -Recurse -Force -File).Count -eq @($manifest.files).Count)
}
$lockPath = Join-Path $parent ('.' + (Split-Path $dest -Leaf) + '.rexglue.lock')
try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Ya hay otra obtención de ReXGlue en curso. Reintentá cuando termine.' }
try {
    if (Test-Path -LiteralPath $dest) {
        if (Test-Sdk $dest) { Write-Host "Se reutiliza ReXGlue 0.10.0 verificado: $dest"; return }
        $previous = Join-Path $parent ('.rexglue-anterior-' + [guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $dest -Destination $previous
        Write-Host "La copia de ReXGlue no pasó la verificación; se conservó en $previous."
    }
    $id = [guid]::NewGuid().ToString('N')
    $download = Join-Path $parent ('.rexglue-download-' + $id + '.zip')
    $stage = Join-Path $parent ('.rexglue-stage-' + $id)
    try {
        if ($Archive) { $source = [IO.Path]::GetFullPath($Archive) }
        else {
            $source = $download
            Write-Host 'Descargando ReXGlue 0.10.0: 42,7 MiB...'
            Invoke-WebRequest -Uri 'https://github.com/rexglue/rexglue-sdk/releases/download/v0.10.0/rexglue-sdk-0.10.0-win-amd64.zip' -OutFile $source -UseBasicParsing
        }
        if (!(Test-Path -LiteralPath $source -PathType Leaf) -or (Get-Item -LiteralPath $source).Length -ne 44751910 -or (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $manifest.archive_sha256) { throw 'La descarga de ReXGlue no coincide con la versión fijada.' }
        Expand-Archive -LiteralPath $source -DestinationPath $stage
        $sdkRoot = Join-Path $stage 'win-amd64'
        if (!(Test-Sdk $sdkRoot)) { throw "El contenido de ReXGlue no pasó la verificación. Carpeta temporal: $stage" }
        Move-Item -LiteralPath $sdkRoot -Destination $dest
        Remove-Item -LiteralPath $stage
        Write-Host "ReXGlue preparado y verificado: $dest"
    } finally {
        if (Test-Path -LiteralPath $download -PathType Leaf) { Remove-Item -LiteralPath $download -Force }
    }
} finally { $lock.Dispose() }
