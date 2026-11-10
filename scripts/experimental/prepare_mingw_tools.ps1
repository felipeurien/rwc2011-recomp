param(
    [Parameter(Mandatory)][string]$Toolset,
    [string]$MingwArchive = '',
    [string]$Fxc = '',
    [string]$SdkWorkDirectory = '',
    [ValidateRange(1,64)][int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$tool = [IO.Path]::GetFullPath($Toolset)
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'get_build_components.ps1') -Toolset $tool
$python = Join-Path $tool 'python/python.exe'
$arguments = @((Join-Path $PSScriptRoot 'get_llvm_mingw.py'), '--toolset', $tool)
if ($MingwArchive) { $arguments += @('--archive', [IO.Path]::GetFullPath($MingwArchive)) }
& $python @arguments
if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar LLVM/MinGW verificado.' }
if ($SdkWorkDirectory -and !$Fxc) { throw 'Para compilar el SDK, indicá el compilador de shaders con -Fxc.' }
if ($Fxc) {
    & (Join-Path $PSScriptRoot 'prepare_mingw_shader.ps1') -Toolset $tool -Fxc $Fxc
    if ($SdkWorkDirectory) {
        $sdk = Join-Path $tool 'rexglue'
        $work = [IO.Path]::GetFullPath($SdkWorkDirectory)
        $candidate = Join-Path $work 'sdk'
        $outputState = Join-Path $PSScriptRoot 'sdk_output_state.py'
        $inputState = Join-Path $PSScriptRoot 'sdk_build_state.py'
        try { $sdkLock = [IO.File]::Open((Join-Path $tool '.sdk-publish.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
        catch { throw 'Ya hay una preparación del SDK en curso.' }
        try {
            $inputsValid = $false
            if (Test-Path -LiteralPath (Join-Path $work 'sdk-build-inputs.json') -PathType Leaf) {
                & $python $inputState verify --work $work --toolset $tool
                $inputsValid = ($LASTEXITCODE -eq 0)
                if (!$inputsValid) { throw 'Las fuentes o los insumos no coinciden con la construcción anterior.' }
            }
            $publishedValid = $false
            if ($inputsValid -and (Test-Path -LiteralPath $sdk -PathType Container) -and (Test-Path -LiteralPath (Join-Path $work 'sdk-build-output.json') -PathType Leaf)) {
                & $python $outputState verify --work $work --sdk $sdk
                $publishedValid = ($LASTEXITCODE -eq 0)
            }
            if ($publishedValid) {
                Write-Host "Se reutiliza el SDK verificado: $sdk"
            } else {
                $candidateValid = $false
                if ($inputsValid -and (Test-Path -LiteralPath $candidate -PathType Container) -and (Test-Path -LiteralPath (Join-Path $work 'sdk-build-output.json') -PathType Leaf)) {
                    & $python $outputState verify --work $work --sdk $candidate
                    $candidateValid = ($LASTEXITCODE -eq 0)
                    if ($candidateValid) { Write-Host 'Se recuperó un SDK terminado de la preparación anterior.' }
                }
                if (!$candidateValid) {
                    & (Join-Path $PSScriptRoot 'build_mingw_sdk.ps1') -Destination $work -Toolset $tool -Jobs $Jobs
                    & $python $outputState record --work $work --sdk $candidate
                    if ($LASTEXITCODE -ne 0) { throw 'No se pudo registrar el SDK compilado.' }
                    & $python $outputState verify --work $work --sdk $candidate
                    if ($LASTEXITCODE -ne 0) { throw 'El SDK compilado no pasó la verificación.' }
                }
                $previous = $null
                if (Test-Path -LiteralPath $sdk) {
                    $previous = Join-Path $tool ('.rexglue-anterior-' + [guid]::NewGuid().ToString('N'))
                    Move-Item -LiteralPath $sdk -Destination $previous
                }
                try { [IO.Directory]::Move($candidate, $sdk) }
                catch {
                    if ($previous -and !(Test-Path -LiteralPath $sdk)) { Move-Item -LiteralPath $previous -Destination $sdk }
                    throw
                }
                if ($previous) { Write-Host "El SDK anterior se conservó en $previous" }
                Write-Host "SDK ReXGlue preparado: $sdk. Fuentes y objetos conservados en $work"
            }
        } finally { $sdkLock.Dispose() }
    } else {
        Write-Host 'Herramientas base y shader listos. El SDK ReXGlue se prepara por separado.'
    }
} else {
    Write-Host 'Herramientas base listas. El SDK ReXGlue y el shader se preparan por separado.'
}
