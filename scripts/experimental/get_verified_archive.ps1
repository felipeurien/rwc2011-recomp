param(
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string]$Sha256,
    [string]$Cached = '',
    [string[]]$RetryCache = @()
)
$ErrorActionPreference = 'Stop'
$name = Split-Path $Destination -Leaf
if ($Cached -and (Test-Path -LiteralPath $Cached -PathType Leaf)) {
    Copy-Item -LiteralPath $Cached -Destination $Destination
} else {
    $reused = $false
    foreach ($directory in $RetryCache) {
        $candidate = Join-Path $directory $name
        if (!(Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        try {
            if ((Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $Sha256) { continue }
            Copy-Item -LiteralPath $candidate -Destination $Destination
            Write-Host "Reutilizando $name de una preparacion anterior..."
            $reused = $true
            break
        } catch {
            # A different attempt may still be writing or cleaning up this file.
            continue
        }
    }
    if (!$reused) {
        Write-Host "Descargando $name..."
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    }
}
if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $Sha256) {
    throw "Descarga incorrecta: $name"
}
