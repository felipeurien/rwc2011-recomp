param([Parameter(Mandatory)][string]$Toolset)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Toolset)
New-Item -ItemType Directory -Path $root -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Test-ComponentArchive($path, $component) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $file = Get-Item -LiteralPath $path -Force
    if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -ne $component.Size) { return $false }
    return ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $component.ArchiveHash)
}
function Test-Component($destination, $component) {
    $archivePath = Join-Path $destination '.source.zip'
    if (!(Test-Path -LiteralPath $archivePath -PathType Leaf) -or (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $component.ArchiveHash) { return $false }
    $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $prefix = if ($component.Inner) { $component.Inner + '/' } else { '' }
        $count = 0
        foreach ($entry in $zip.Entries) {
            if (!$entry.Name -or !$entry.FullName.StartsWith($prefix, [StringComparison]::Ordinal)) { continue }
            $relative = $entry.FullName.Substring($prefix.Length)
            if (!$relative -or $relative -match '(^|/)\.\.(/|$)') { return $false }
            $path = Join-Path $destination ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
            if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne $entry.Length) { return $false }
            $stream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $expected = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
            finally { $sha.Dispose(); $stream.Dispose() }
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected) { return $false }
            $count++
        }
        $actualCount = @(Get-ChildItem -LiteralPath $destination -Recurse -Force -File | Where-Object { $_.FullName -ne $archivePath }).Count
        return ($count -gt 0 -and $count -eq $actualCount)
    } finally { $zip.Dispose() }
}
$components = @(
    @{ Name='cmake'; Url='https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-windows-x86_64.zip'; Size=46473549; ArchiveHash='D163CD3AB4959B0A53FA8988F2DDBD2E6C501658201E6A154386BAD9DBE4F836'; Inner='cmake-3.31.6-windows-x86_64'; Executable='bin/cmake.exe'; ExecutableHash='3FE22EB02E1C6184EC207366ED21A6F2F9C3828C1E9F3324546BEFADFB362BE3' },
    @{ Name='ninja'; Url='https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip'; Size=275425; ArchiveHash='F550FEC705B6D6FF58F2DB3C374C2277A37691678D6ABA463ADCBB129108467A'; Inner=''; Executable='ninja.exe'; ExecutableHash='68865C3276D449D746CEA5065FDEC2BAF755D7813E161AB04205B0907B2629B8' },
    @{ Name='python'; Url='https://www.python.org/ftp/python/3.14.0/python-3.14.0-embed-amd64.zip'; Size=11994671; ArchiveHash='8D4D3590C10449D78AA4375F534E6D5F3027D67FDC362DD1A882279DB6F90FDF'; Inner=''; Executable='python.exe'; ExecutableHash='467014615A5255ACA450AE88100DD2CAF887DA87657F00E3C2171EC44A685AEC' }
)
try { $lock = [IO.File]::Open((Join-Path $root '.components.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Ya hay otra obtención de componentes en curso. Reintentá cuando termine.' }
try {
foreach ($component in $components) {
    $destination = Join-Path $root $component.Name
    $executable = Join-Path $destination $component.Executable
    $savedArchive = $null
    if (Test-Path -LiteralPath $destination) {
        if (!(Test-Component $destination $component)) {
            $quarantine = Join-Path $root ('.' + $component.Name + '-anterior-' + [guid]::NewGuid().ToString('N'))
            Move-Item -LiteralPath $destination -Destination $quarantine
            $previousArchive = Join-Path $quarantine '.source.zip'
            if (Test-ComponentArchive $previousArchive $component) { $savedArchive = $previousArchive }
            Write-Host "El componente no pasó la verificación; se conservó en $quarantine."
        } else {
            Write-Host "Se reutiliza $($component.Name)."
            continue
        }
    }
    if (!$savedArchive) {
        foreach ($item in (Get-ChildItem -LiteralPath $root -Force)) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
            $possible = $null
            if (!$item.PSIsContainer -and $item.Name -match '^\.download-[0-9a-f]{32}\.zip$') { $possible = $item.FullName }
            elseif ($item.PSIsContainer -and $item.Name -match ('^\.' + [regex]::Escape($component.Name) + '-anterior-[0-9a-f]{32}$')) {
                $possible = Join-Path $item.FullName '.source.zip'
            }
            elseif ($item.PSIsContainer -and $item.Name -match '^\.component-[0-9a-f]{32}$') {
                $payloadDirectory = if ($component.Inner) { Join-Path $item.FullName $component.Inner } else { $item.FullName }
                if ((Test-Path -LiteralPath $payloadDirectory -PathType Container) -and !((Get-Item -LiteralPath $payloadDirectory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                    $possible = Join-Path $payloadDirectory '.source.zip'
                }
            }
            if ($possible -and (Test-ComponentArchive $possible $component)) { $savedArchive = $possible; break }
        }
    }
    $id = [guid]::NewGuid().ToString('N')
    $archive = Join-Path $root ('.download-' + $id + '.zip')
    $stage = Join-Path $root ('.component-' + $id)
    # Se conserva el ZIP temporal si una extracción se interrumpe.
        if ($savedArchive) {
            Write-Host "Se reutiliza el ZIP verificado de $($component.Name): $savedArchive"
            Copy-Item -LiteralPath $savedArchive -Destination $archive
        } else {
            Write-Host ("Descargando {0}: {1:N1} MiB..." -f $component.Name, ($component.Size / 1MB))
            Invoke-WebRequest -Uri $component.Url -OutFile $archive -UseBasicParsing
        }
        if (!(Test-ComponentArchive $archive $component)) { throw "La descarga de $($component.Name) no coincide con el tamaño y hash fijados." }
        Expand-Archive -LiteralPath $archive -DestinationPath $stage
        $payload = if ($component.Inner) { Join-Path $stage $component.Inner } else { $stage }
        $candidate = Join-Path $payload $component.Executable
        if (!(Test-Path -LiteralPath $candidate -PathType Leaf) -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $component.ExecutableHash) { throw "El ejecutable de $($component.Name) no coincide con la versión fijada." }
        Move-Item -LiteralPath $archive -Destination (Join-Path $payload '.source.zip')
        if (!(Test-Component $payload $component)) { throw "La extracción de $($component.Name) no pasó la verificación. Carpeta temporal: $stage" }
        Move-Item -LiteralPath $payload -Destination $destination
        if ($component.Inner) { Remove-Item -LiteralPath $stage }
        Write-Host "$($component.Name) listo."
}
} finally { $lock.Dispose() }
