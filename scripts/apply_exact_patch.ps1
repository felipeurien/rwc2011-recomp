param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$Patch
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\','/')
$lines = [IO.File]::ReadAllText([IO.Path]::GetFullPath($Patch)).Replace("`r`n", "`n").Split("`n")
if ($lines.Count -lt 4 -or $lines[0] -notmatch '^--- a/(.+)$') { throw 'Parche no admitido.' }
$relative = $matches[1]
if ($lines[1] -ne "+++ b/$relative" -or $lines[2] -notmatch '^@@ -\d+(,\d+)? \+\d+(,\d+)? @@') { throw 'Parche no admitido.' }
$target = [IO.Path]::GetFullPath((Join-Path $root $relative))
if (!$target.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Ruta de parche fuera de la carpeta de fuentes.' }
$old = [Collections.Generic.List[string]]::new()
$new = [Collections.Generic.List[string]]::new()
for ($i = 3; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($i -eq $lines.Count - 1 -and $line -eq '') { continue }
    if ($line.Length -eq 0) { throw 'Línea de parche inválida.' }
    switch ($line[0]) {
        ' ' { $old.Add($line.Substring(1)); $new.Add($line.Substring(1)) }
        '-' { $old.Add($line.Substring(1)) }
        '+' { $new.Add($line.Substring(1)) }
        default { throw 'El parche debe tener un único bloque válido.' }
    }
}
$before = ($old -join "`n") + "`n"
$after = ($new -join "`n") + "`n"
$contents = [IO.File]::ReadAllText($target).Replace("`r`n", "`n")
$index = $contents.IndexOf($before, [StringComparison]::Ordinal)
if ($index -lt 0 -or $contents.LastIndexOf($before, [StringComparison]::Ordinal) -ne $index) { throw 'El contenido no coincide exactamente con el parche.' }
$result = $contents.Substring(0, $index) + $after + $contents.Substring($index + $before.Length)
[IO.File]::WriteAllText($target, $result, [Text.UTF8Encoding]::new($false))
