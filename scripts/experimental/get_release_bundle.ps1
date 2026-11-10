param(
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$Sha256,
    [Parameter(Mandatory)][ValidateRange(1,9223372036854775807)][long]$Size,
    [string]$Url = '',
    [string]$Archive = ''
)
$ErrorActionPreference = 'Stop'
if ((!$Url -and !$Archive) -or ($Url -and $Archive)) { throw 'Indicá exactamente una URL HTTPS o un archivo local de prueba.' }
if ($Url -and (([uri]$Url).Scheme -ne 'https' -or ([uri]$Url).UserInfo)) { throw 'La descarga debe usar HTTPS sin credenciales en la dirección.' }
$destinationPath = [IO.Path]::GetFullPath($Destination)
$parent = Split-Path $destinationPath -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$prefixes = @('tools/rugby-dependencies/mingw-toolset/', 'tools/extract-xiso-portable/')
$required = @(
    'tools/rugby-dependencies/mingw-toolset/cmake/bin/cmake.exe',
    'tools/rugby-dependencies/mingw-toolset/ninja/ninja.exe',
    'tools/rugby-dependencies/mingw-toolset/python/python.exe',
    'tools/rugby-dependencies/mingw-toolset/mingw/bin/x86_64-w64-mingw32-clang++.exe',
    'tools/rugby-dependencies/mingw-toolset/rexglue/bin/rexglue.exe',
    'tools/rugby-dependencies/mingw-toolset/rexglue/bin/librexruntime.dll',
    'tools/rugby-dependencies/mingw-toolset/rexglue/bin/librexgpu-xenos.dll',
    'tools/rugby-dependencies/mingw-toolset/shader/resolve-full32-signed.dxbc',
    'tools/extract-xiso-portable/artifacts/extract-xiso.exe',
    'tools/extract-xiso-portable/artifacts/LICENSE.TXT'
)
function Test-RequiredEntries($entries) {
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $entries) { [void]$names.Add($entry.FullName) }
    foreach ($name in $required) { if (!$names.Contains($name)) { return $false } }
    return $true
}
function Get-UrlHash([string]$address) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($address))).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Get-RemoteArchive([string]$address, [string]$target) {
    $request = [Net.HttpWebRequest]::Create($address)
    $request.UserAgent = 'Rugby2011-Release-Prototype/1.0'
    $request.Timeout = 120000
    [long]$offset = 0
    if (Test-Path -LiteralPath $target -PathType Leaf) { $offset = (Get-Item -LiteralPath $target).Length }
    if ($offset -gt 0) { $request.AddRange($offset) }
    $response = $request.GetResponse()
    try {
        if ($response.ResponseUri.Scheme -ne 'https') { throw 'La descarga redirigió a una dirección sin HTTPS.' }
        if ($offset -gt 0 -and [int]$response.StatusCode -eq 206) {
            $range = [string]$response.Headers['Content-Range']
            if ($range -notmatch '^bytes ([0-9]+)-([0-9]+)/([0-9]+)$' -or [long]$Matches[1] -ne $offset -or [long]$Matches[2] -ne ($Size - 1) -or [long]$Matches[3] -ne $Size) { throw 'El servidor devolvió un rango incompatible.' }
            if ($response.ContentLength -ge 0 -and $response.ContentLength -ne ($Size - $offset)) { throw 'El tamaño del rango no coincide con el paquete fijado.' }
            Write-Host "Reanudando la descarga desde $offset bytes..."
        } elseif ([int]$response.StatusCode -eq 200) {
            if ($offset -gt 0) { Write-Host 'El servidor no admite reanudar; se descargará el archivo completo.' }
            $offset = 0
            if ($response.ContentLength -ge 0 -and $response.ContentLength -ne $Size) { throw 'El tamaño anunciado no coincide con el paquete fijado.' }
        } else { throw "Respuesta HTTP inesperada: $([int]$response.StatusCode)." }
        $inputStream = $response.GetResponseStream()
        $outputStream = [IO.File]::Open($target, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            if ($offset -eq 0) { $outputStream.SetLength(0) }
            [void]$outputStream.Seek($offset, [IO.SeekOrigin]::Begin)
            $buffer = New-Object byte[] (1024 * 1024)
            [long]$total = $offset
            $lastStep = -1
            while (($count = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $total += $count
                if ($total -gt $Size) { throw 'La descarga supera el tamaño fijado.' }
                $outputStream.Write($buffer, 0, $count)
                $step = [int][Math]::Floor(($total * 10.0) / $Size)
                if ($step -gt $lastStep) { Write-Host "Descarga: $([Math]::Min($step * 10, 100))%"; $lastStep = $step }
            }
        } finally { $outputStream.Dispose(); $inputStream.Dispose() }
    } finally { $response.Dispose() }
}
function Get-SelectedEntries($zip) {
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $zip.Entries) {
        $name = $entry.FullName
        if (!$seen.Add($name)) { throw "Ruta duplicada en el paquete: $name" }
        if (!$entry.Name) { continue }
        $selected = $false
        foreach ($prefix in $prefixes) { if ($name.StartsWith($prefix, [StringComparison]::Ordinal)) { $selected = $true; break } }
        if (!$selected) { continue }
        foreach ($part in $name.Split('/')) {
            if (!$part -or $part -in @('.','..') -or $part.Contains('\') -or $part.Contains(':') -or $part.EndsWith('.') -or $part.EndsWith(' ')) { throw "Ruta inválida en el paquete: $name" }
        }
        $type = ($entry.ExternalAttributes -shr 16) -band 0xF000
        if ($type -ne 0 -and $type -ne 0x8000) { throw "Archivo no regular en el paquete: $name" }
        $entry
    }
}
function Test-Archive([string]$path) {
    try {
        $file = Get-Item -LiteralPath $path -Force
        return (!$file.PSIsContainer -and !($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $file.Length -eq $Size -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $Sha256)
    } catch { return $false }
}
function Test-Bundle([string]$directory) {
    try {
        $rootItem = Get-Item -LiteralPath $directory -Force
        if (!$rootItem.PSIsContainer -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        $archivePath = Join-Path $directory '.source.zip'
        if (!(Test-Archive $archivePath)) { return $false }
        $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
        try {
            $entries = @(Get-SelectedEntries $zip)
            if (!(Test-RequiredEntries $entries)) { return $false }
            $all = @(Get-ChildItem -LiteralPath $directory -Recurse -Force)
            if (@($all | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count -gt 0) { return $false }
            $files = @($all | Where-Object { !$_.PSIsContainer -and $_.FullName -ne $archivePath })
            if ($files.Count -ne $entries.Count) { return $false }
            foreach ($entry in $entries) {
                $path = Join-Path $directory ($entry.FullName.Replace('/', [IO.Path]::DirectorySeparatorChar))
                $actual = Get-Item -LiteralPath $path -Force
                if ($actual.PSIsContainer -or ($actual.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $actual.Length -ne $entry.Length) { return $false }
                $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
                try { $expected = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
                finally { $sha.Dispose(); $stream.Dispose() }
                if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected) { return $false }
            }
            return $true
        } finally { $zip.Dispose() }
    } catch { return $false }
}
$lockName = '.bundle-prepare.lock'
try { $lock = [IO.File]::Open((Join-Path $parent $lockName), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Ya hay una preparación de este paquete en curso.' }
try {
    if ((Test-Path -LiteralPath $destinationPath) -and (Test-Bundle $destinationPath)) { Write-Host 'Se reutiliza el paquete verificado.'; return }
    $stage = $null
    $cachedArchive = $null
    $partialArchive = $null
    $partialMeta = $null
    [long]$partialLength = 0
    $urlHash = if ($Url) { Get-UrlHash $Url } else { '' }
    if (Test-Path -LiteralPath $destinationPath -PathType Container) {
        $existingItem = Get-Item -LiteralPath $destinationPath -Force
        $existingArchive = Join-Path $destinationPath '.source.zip'
        if (!($existingItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (Test-Archive $existingArchive)) { $cachedArchive = $existingArchive }
    }
    foreach ($item in @(Get-ChildItem -LiteralPath $parent -Directory -Force -Filter '.bundle-*')) {
        if ($item.Name -cnotmatch '^\.bundle-[0-9a-f]{32}$' -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
        if (Test-Bundle $item.FullName) { $stage = $item.FullName; Write-Host "Se recuperó un paquete completo: $stage"; break }
        $candidateArchive = Join-Path $item.FullName '.source.zip'
        if (!$cachedArchive -and (Test-Archive $candidateArchive)) { $cachedArchive = $candidateArchive }
        $metaPath = $item.FullName + '.download.json'
        if ($Url -and (Test-Path -LiteralPath $metaPath -PathType Leaf) -and (Test-Path -LiteralPath $candidateArchive -PathType Leaf)) {
            try {
                $metaItem = Get-Item -LiteralPath $metaPath -Force
                $partialItem = Get-Item -LiteralPath $candidateArchive -Force
                $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
                if (!($metaItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -and !($partialItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $meta.format -eq 1 -and $meta.sha256 -eq $Sha256 -and [long]$meta.size -eq $Size -and $meta.url_sha256 -eq $urlHash -and $partialItem.Length -gt $partialLength -and $partialItem.Length -lt $Size) {
                    $partialArchive = $candidateArchive; $partialMeta = $metaPath; $partialLength = $partialItem.Length
                }
            } catch { }
        }
    }
    if (!$stage) {
        $stage = Join-Path $parent ('.bundle-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stage | Out-Null
        $package = Join-Path $stage '.source.zip'
        if ($cachedArchive) {
            Write-Host "Se reutiliza la descarga verificada: $cachedArchive"
            Copy-Item -LiteralPath $cachedArchive -Destination $package
        } else {
            Write-Host ("Obteniendo el paquete: {0:N1} MiB..." -f ($Size / 1MB))
            if ($Archive) { Copy-Item -LiteralPath ([IO.Path]::GetFullPath($Archive)) -Destination $package }
            else {
                $metaPath = $stage + '.download.json'
                $metadata = [ordered]@{ format=1; sha256=$Sha256; size=$Size; url_sha256=$urlHash } | ConvertTo-Json -Compress
                [IO.File]::WriteAllText($metaPath, $metadata, [Text.UTF8Encoding]::new($false))
                if ($partialArchive) { Copy-Item -LiteralPath $partialArchive -Destination $package }
                Get-RemoteArchive $Url $package
            }
        }
        $downloadedSize = (Get-Item -LiteralPath $package).Length
        if (!$Archive -and $downloadedSize -lt $Size) { throw "La descarga quedó incompleta y se conserva en $stage para reintentar." }
        if ($downloadedSize -ne $Size -or (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash -ne $Sha256) {
            if ($partialMeta -and (Test-Path -LiteralPath $partialMeta -PathType Leaf)) {
                $rejected = $partialMeta + '.rechazado-' + [guid]::NewGuid().ToString('N')
                Move-Item -LiteralPath $partialMeta -Destination $rejected
            }
            throw "La descarga no coincide con el paquete fijado. Se conserva en $stage; el próximo intento obtendrá otra copia."
        }
        $zip = [IO.Compression.ZipFile]::OpenRead($package)
        try {
            $entries = @(Get-SelectedEntries $zip)
            if (!(Test-RequiredEntries $entries)) { throw 'El paquete no contiene las herramientas esperadas.' }
            $index = 0
            foreach ($entry in $entries) {
                $target = Join-Path $stage ($entry.FullName.Replace('/', [IO.Path]::DirectorySeparatorChar))
                New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
                $inputStream = $entry.Open(); $outputStream = [IO.File]::Open($target, [IO.FileMode]::CreateNew)
                try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $inputStream.Dispose() }
                $index++
                if (($index % 2000) -eq 0) { Write-Host "Extraídos $index / $($entries.Count) archivos..." }
            }
        } finally { $zip.Dispose() }
        Write-Host 'Verificando los archivos extraídos...'
        if (!(Test-Bundle $stage)) { throw "El paquete extraído no pasó la verificación. Se conserva en $stage" }
    }
    $previous = $null
    if (Test-Path -LiteralPath $destinationPath) {
        $previous = Join-Path $parent ('.bundle-anterior-' + [guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $destinationPath -Destination $previous
    }
    try { [IO.Directory]::Move($stage, $destinationPath) }
    catch {
        if ($previous -and !(Test-Path -LiteralPath $destinationPath)) { Move-Item -LiteralPath $previous -Destination $destinationPath }
        throw
    }
    if ($previous) { Write-Host "El paquete anterior se conservó en $previous" }
    Write-Host "Paquete verificado: $destinationPath"
} finally { $lock.Dispose() }
