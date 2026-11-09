param([Parameter(Mandatory)][string]$GameDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$manifest = Get-Content -LiteralPath (Join-Path $root 'analysis/baseline/game-manifest.json') -Raw | ConvertFrom-Json
$files = @(Get-ChildItem -LiteralPath $GameDirectory -Recurse -File)
if ($files.Count -ne $manifest.file_count) { throw "Cantidad de archivos incorrecta en $GameDirectory : $($files.Count), esperados $($manifest.file_count)." }
foreach ($entry in $manifest.files) {
    $path = Join-Path $GameDirectory ($entry.path.Replace('/', [IO.Path]::DirectorySeparatorChar))
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Falta un archivo del juego: $($entry.path)" }
    if ((Get-Item -LiteralPath $path).Length -ne $entry.size) { throw "Tamaño incorrecto: $($entry.path)" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Contenido incorrecto: $($entry.path)" }
}
Write-Output "Verificados $($files.Count) archivos en $GameDirectory"
