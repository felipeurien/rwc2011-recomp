param(
    [Parameter(Mandatory)][string]$WorkDirectory,
    [Parameter(Mandatory)][string]$Fxc,
    [ValidateRange(1,64)][int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$base = [IO.Path]::GetFullPath($WorkDirectory)
if ($base.Contains(' ')) { throw 'La carpeta de trabajo no debe contener espacios.' }
if (!(Test-Path -LiteralPath $Fxc -PathType Leaf)) { throw "Falta el compilador de shaders: $Fxc" }
if (!(Test-Path -LiteralPath $base)) {
    New-Item -ItemType Directory -Path $base | Out-Null
    $owner = @{ format = 1; work = $base; project = $root } | ConvertTo-Json -Compress
    [IO.File]::WriteAllText((Join-Path $base '.candidate-owner.json'), $owner, [Text.UTF8Encoding]::new($false))
}
$baseItem = Get-Item -LiteralPath $base -Force
if (!$baseItem.PSIsContainer -or ($baseItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'La carpeta de trabajo no puede ser un enlace.' }
$marker = Join-Path $base '.candidate-owner.json'
if (!(Test-Path -LiteralPath $marker -PathType Leaf)) { throw "La carpeta no pertenece a esta preparación; conservála y usá una nueva: $base" }
$owner = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
if ($owner.format -ne 1 -or $owner.work -ne $base -or $owner.project -ne $root) { throw 'La carpeta de trabajo pertenece a otra preparación o proyecto.' }
try { $lock = [IO.File]::Open((Join-Path $base '.candidate.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { throw 'Ya hay una preparación de candidato en esta carpeta.' }
try {
$tool = Join-Path $base 'toolset'
$work = Join-Path $base 'sdk-work'
$extractor = Join-Path $base 'extractor'
$output = Join-Path $base ('output/run-' + [guid]::NewGuid().ToString('N'))
$cache = Join-Path $output 'source-cache'
$review = Join-Path $base 'review'
& (Join-Path $PSScriptRoot 'prepare_mingw_tools.ps1') -Toolset $tool -Fxc $Fxc -SdkWorkDirectory $work -Jobs $Jobs
& (Join-Path $root 'scripts/get_extractor.ps1') -Destination $extractor | Out-Host
$python = Join-Path $tool 'python/python.exe'
$scriptDirectory = $PSScriptRoot
function Invoke-PortableScript([string]$Script, [string[]]$ScriptArguments) {
    # El Python embebido usa aislamiento y no agrega el directorio del script.
    $bootstrap = "import runpy,sys; sys.path.insert(0,sys.argv.pop(1)); script=sys.argv.pop(1); sys.argv[0]=script; runpy.run_path(script,run_name='__main__')"
    & $python -c $bootstrap $scriptDirectory (Join-Path $scriptDirectory $Script) @ScriptArguments
    if ($LASTEXITCODE -ne 0) { throw "Falló $Script (código $LASTEXITCODE)." }
}
New-Item -ItemType Directory -Path $cache,$review -Force | Out-Null
foreach ($pair in @(@('cmake','cmake.zip'), @('ninja','ninja.zip'), @('python','python.zip'), @('mingw','llvm-mingw-20251021.zip'))) {
    Copy-Item -LiteralPath (Join-Path $tool ($pair[0] + '/.source.zip')) -Destination (Join-Path $cache $pair[1])
}
$candidate = Join-Path $output 'candidato-local.zip'
$kit = Join-Path $output 'fuentes-local.zip'
Invoke-PortableScript 'create_candidate.py' @('--toolset',$tool,'--extractor',$extractor,'--output',$candidate)
Invoke-PortableScript 'audit_candidate.py' @('--zip',$candidate,'--source-cache',$cache)
Invoke-PortableScript 'create_relink_kit.py' @('--work',$work,'--toolset',$tool,'--output',$kit)
$reviewSource = Join-Path $review 'src'
if (!(Test-Path -LiteralPath $reviewSource)) { Invoke-PortableScript 'prepare_mingw_sdk_sources.py' @($reviewSource) }
& (Join-Path $root 'scripts/apply_exact_patch.ps1') -SourceRoot $reviewSource -Patch (Join-Path $root 'patches/shadow-integer-r16-fetch.patch') -AllowApplied
Copy-Item -LiteralPath (Join-Path $tool 'shader/resolve_full_32bpp_cs.h') -Destination (Join-Path $reviewSource 'src/graphics/shaders/bytecode/d3d12_5_1/resolve_full_32bpp_cs.h') -Force
Invoke-PortableScript 'audit_relink_kit.py' @('--zip',$kit,'--source',$reviewSource,'--toolset',$tool)
Write-Host "Paquetes locales verificados: $output"
Write-Host 'Esta prueba no publica archivos y no sustituye la revisión de licencias ni la prueba en Windows limpio.'
} finally { $lock.Dispose() }
