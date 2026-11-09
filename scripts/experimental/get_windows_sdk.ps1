param(
    [Parameter(Mandatory)][string]$Destination,
    [string]$PackageCache = ''
)
$ErrorActionPreference = 'Stop'
$destinationPath = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) { throw "El destino ya existe: $destinationPath" }
New-Item -ItemType Directory -Path $destinationPath | Out-Null
$downloads = Join-Path $destinationPath 'packages'
$extracted = Join-Path $destinationPath 'extracted'
New-Item -ItemType Directory -Path $downloads,$extracted | Out-Null
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'windows_sdk_packages.json') -Raw | ConvertFrom-Json
foreach ($file in $manifest.files) {
    if ([IO.Path]::GetFileName($file.name) -ne $file.name) { throw 'Nombre de paquete inválido.' }
    $url = [Uri]$file.url
    if ($url.Scheme -ne 'https' -or $url.Host -ne 'download.visualstudio.microsoft.com') { throw 'Origen de paquete inválido.' }
    $target = Join-Path $downloads $file.name
    $cached = if ($PackageCache) { Join-Path $PackageCache $file.name } else { '' }
    if ($cached -and (Test-Path -LiteralPath $cached -PathType Leaf)) { Copy-Item -LiteralPath $cached -Destination $target }
    else { Write-Host "Descargando $($file.name)..."; Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing }
    if ((Get-Item -LiteralPath $target).Length -ne $file.size -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $file.sha256) { throw "Paquete incorrecto: $($file.name)" }
}
foreach ($name in $manifest.msi) {
    $msi = Join-Path $downloads $name
    $arguments = @('/a', ('"' + $msi + '"'), '/qn', ('TARGETDIR="' + $extracted + '"'))
    $process = Start-Process -FilePath (Join-Path $env:WINDIR 'System32/msiexec.exe') -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "No se pudo extraer $name (código $($process.ExitCode))." }
}
Write-Output "SDK extraído: $(Join-Path $extracted 'Windows Kits/10')"
