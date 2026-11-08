# Rugby World Cup 2011 Recomp

Port experimental para Windows x64 de Rugby World Cup 2011 (Xbox 360), basado en la recompilación estática con [ReXGlue 0.10.0](https://github.com/rexglue/rexglue-sdk/releases/tag/v0.10.0). Usa las selecciones, camisetas y escudos originales. La versión probada llegó al campo, completó un partido y volvió al menú. También se verificó el guardado y la carga de un torneo.

## Requisitos

- Visual Studio 2022 Build Tools con las herramientas de C++ para x64, Clang, CMake 3.25 o posterior y Ninja.
- Windows SDK 10.0.26100.0, Python 3 y Git.
- ReXGlue SDK 0.10.0 para Windows x64, extraído en una carpeta local.
- Una copia propia del disco de Xbox 360, extraída en `original/game/`. La revisión probada tiene Title ID `464F07ED`, Media ID `49BB1EA8` y versión `0.0.0.4`. El archivo `original/game/default.xex` debe tener este SHA-256:

  `8045c61254615b223591efee3bd9b34fa6a05ba1bfe1dd61719e248d454ea201`

## Compilar

Desde **Developer PowerShell para Visual Studio**, con el entorno x64 activo y en la raíz del repositorio, ajustá la ruta de `REXSDK` y ejecutá:

```powershell
$env:REXSDK = 'C:/ruta/al/sdk/win-amd64'
.\scripts\build_port.ps1
```

El script genera el código localmente a partir del ejecutable de Xbox 360, comprueba las barreras de sincronización y compila el port. La salida queda en `build/port-shadow-integer-fetch/`.

Para reproducir la corrección gráfica de la build probada, compilá también el complemento Xenos con los dos parches de sombras incluidos. Usá una extracción limpia de las fuentes del SDK para este paso.

```powershell
New-Item -ItemType Directory -Path work/sdk-source -Force | Out-Null
Invoke-WebRequest https://codeload.github.com/rexglue/rexglue-sdk/tar.gz/refs/tags/v0.10.0 -OutFile work/rexglue.tar.gz
tar -xf work/rexglue.tar.gz -C work/sdk-source
$sdkSource = (Resolve-Path work/sdk-source/rexglue-sdk-0.10.0).Path
$fxc = Join-Path $env:WindowsSdkDir 'bin/10.0.26100.0/x64/fxc.exe'
python scripts/prepare_shadows.py $sdkSource $fxc
cmake -S scripts/gpu/plugin -B build/gpu -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_COMPILER=clang-cl "-DCMAKE_PREFIX_PATH=$env:REXSDK" "-DRUGBY_SDK_SOURCE=$sdkSource"
cmake --build build/gpu
Copy-Item build/gpu/graphics/rexgpu-xenosrd.dll build/port-shadow-integer-fetch/
```

## Jugar

Ejecutá `.\scripts\build_launcher.ps1` una vez y abrí **Jugar Rugby 2011.exe** desde la carpeta del proyecto. El lanzador usa los datos originales y activa la compilación síncrona de shaders. Las partidas, la caché y los registros se guardan en `work/`.

El repositorio contiene el código del port y los parches. La imagen del disco, los archivos extraídos y las compilaciones quedan en tu equipo.

### Autocompletar el código de extras

La compilación prepara automáticamente el código de extras incluido en el repositorio. Al abrir **Enter Code** en el juego, el campo aparece prellenado y vos confirmás con Enter. Si ya tenés el port compilado, podés activar el autocompletado con `python scripts/prepare_unlock_prefill.py`. Para quitarlo, cerrá el juego y ejecutá `python scripts/prepare_unlock_prefill.py --clear`. El archivo generado queda en `work/updates/`.
