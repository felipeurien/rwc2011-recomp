param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
try {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
    # Generated from the supported disc revision by the pinned Python 3.14.0.
    return ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq '32CC50AEA36043D2E20F74DEF3362D322D2B61437FC6C351D6163A3A9384F5FE')
} catch { return $false }
