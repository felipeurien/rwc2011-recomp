param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidateRange(1,9223372036854775807)][long]$RequiredBytes,
    [Parameter(Mandatory)][string]$Step
)
$ErrorActionPreference = 'Stop'
$folder = [IO.Path]::GetFullPath($Path)
if (!(Test-Path -LiteralPath $folder -PathType Container)) { throw "No se encontró la carpeta de destino: $folder" }
if (!('Rugby.ReleaseDiskSpace' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Rugby {
    public static class ReleaseDiskSpace {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool GetDiskFreeSpaceEx(string path, out ulong available, out ulong total, out ulong free);
    }
}
'@
}
[UInt64]$available = 0
[UInt64]$total = 0
[UInt64]$free = 0
if (![Rugby.ReleaseDiskSpace]::GetDiskFreeSpaceEx($folder, [ref]$available, [ref]$total, [ref]$free)) {
    $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "No se pudo comprobar el espacio disponible para $Step (Windows: $errorCode)."
}
if ($available -lt [UInt64]$RequiredBytes) {
    $neededMiB = [Math]::Ceiling($RequiredBytes / 1MB)
    $freeMiB = [Math]::Floor($available / 1MB)
    throw "No hay espacio suficiente para $Step. Se necesitan al menos $neededMiB MiB y hay $freeMiB MiB disponibles en $folder."
}
