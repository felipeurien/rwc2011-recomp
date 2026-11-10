param(
    [Parameter(Mandatory)][string]$Plugin,
    [Parameter(Mandatory)][string]$Shader
)
$ErrorActionPreference = 'Stop'
$expected = '3BE64E932AC65FB2A41E3D379B053A530B1593158CE0FDD7A81185821C0A61C5'
if ((Get-FileHash -LiteralPath $Shader -Algorithm SHA256).Hash -ne $expected) {
    throw 'El shader no coincide con la version corregida.'
}

# Latin-1 maps every byte to a distinct character for the ordinal search.
$encoding = [Text.Encoding]::GetEncoding(28591)
$shaderBytes = $encoding.GetString([IO.File]::ReadAllBytes($Shader))
$pluginBytes = $encoding.GetString([IO.File]::ReadAllBytes($Plugin))
if ($pluginBytes.IndexOf($shaderBytes, [StringComparison]::Ordinal) -lt 0) {
    throw "El complemento no incluye el shader corregido: $Plugin"
}
