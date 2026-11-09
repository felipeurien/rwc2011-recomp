# Plan para clonar y jugar Rugby World Cup 2011

Los caminos absolutos y registros mencionados en este documento describen pruebas históricas en una PC y no forman parte del repositorio. Para reproducir el experimento con rutas propias, consultá los [scripts experimentales](scripts/experimental/README.md).

## Experiencia que queremos entregar

1. Clonar el repositorio o descargar su ZIP en Windows x64.
2. Poner una ISO propia de Xbox 360 en la carpeta del proyecto o elegirla desde **Jugar Rugby 2011**.
3. Abrir **Jugar Rugby 2011**. La primera vez, el lanzador verifica el disco, prepara lo necesario y abre el juego. Las siguientes veces reutiliza lo preparado y funciona sin conexión.

El primer objetivo es **cero instalaciones manuales** después de obtener el repositorio. Windows y el hardware gráfico compatible son requisitos de la máquina. Si la primera preparación necesita descargar componentes, el lanzador debe avisar antes y mostrar cuánto falta. El ZIP debe ofrecer el mismo flujo sin requerir Git.

## Estado actual

El port vanilla usa ReXGlue 0.10.0 para generar C++ a partir de `default.xex`. La receta actual requiere extraer el disco y compilar con Clang, CMake, Ninja y Windows SDK. Python verifica las correcciones de sincronización y prepara el autocompletado del código de extras. El complemento gráfico se construye aparte para aplicar las dos correcciones de sombras. Ya existe un lanzador, pero hoy busca un ejecutable y datos previamente preparados.

La revisión de disco comprobada tiene Title ID `464F07ED`, Media ID `49BB1EA8` y versión `0.0.0.4`. El SHA-256 esperado de `default.xex` es `8045c61254615b223591efee3bd9b34fa6a05ba1bfe1dd61719e248d454ea201`. Una ISO puede tener distinto relleno o tamaño y contener la misma revisión. La validación debe hacerse sobre los archivos extraídos.

## Ruta propuesta

Compilar y empaquetar en CI todo lo que se pueda construir sin el disco. El paquete base incluye el lanzador, el extractor, el runtime de ReXGlue y el complemento gráfico corregido, según los permisos de redistribución de cada componente. El repositorio contiene el código y las recetas para producirlos. La ISO, los archivos del juego y los resultados generados a partir de esa copia quedan en el equipo del jugador.

El punto decisivo es cómo generar y enlazar el código recompilado en la PC del jugador. Hoy ese paso usa un entorno de compilación de Windows. Hay que demostrar que se puede ejecutar con herramientas portables antes de prometer el flujo de un clic. CMake, Ninja y Python pueden seguir en CI si las comprobaciones y el enlace local se pueden ejecutar con menos componentes.

## Etapas

### 1. Medir qué necesita la build vanilla

- Inventariar las DLL que carga el ejecutable, el complemento Xenos y el lanzador, incluidas las dependencias indirectas. Probar en una instalación limpia de Windows x64, sin Visual Studio ni paquetes de desarrollo.
- Fijar una configuración de distribución. Verificar si se puede prescindir de componentes de diagnóstico como Tracy en esa configuración y documentar cualquier dependencia que siga siendo necesaria.
- Separar los insumos del port de los que salen del disco. Verificar qué ejecutables, bibliotecas y herramientas pueden distribuirse con sus avisos correspondientes.

**Cierre:** lista de componentes por fase, tamaño aproximado y requisitos de Windows y gráficos comprobados en una máquina limpia.

### 2. Probar la recompilación local sin instalar herramientas

- Hacer un prototipo que use la revisión compatible del disco, ejecute ReXGlue y compile y enlace con herramientas portables fijadas por versión. Medir tamaño de descarga, espacio temporal y tiempo hasta el primer arranque.
- Sacar del flujo del jugador el compilador de shaders y la construcción del complemento gráfico. Esos pasos quedan en CI, donde se aplican los dos parches y se valida el shader.
- Si el enlace local exige archivos del SDK o bibliotecas de Windows que el paquete no puede incluir, documentar el requisito exacto y evaluar una versión del paquete que reduzca esa dependencia. Mantener la compilación manual como salida mientras se resuelve el bloqueo.

**Cierre:** el prototipo genera un ejecutable jugable en Windows limpio sin instalar Visual Studio, Python ni el SDK de Windows.

### 3. Automatizar la preparación de la ISO

- Detectar una ISO en la carpeta del proyecto. Si hay varias o está en otro lugar, mostrar un selector. Aceptar también una carpeta ya extraída.
- Extraer a una carpeta temporal con una herramienta de Xbox 360 verificada. Comprobar la revisión y los archivos necesarios antes de usar la extracción. Informar por separado si la imagen está dañada, falta espacio o la revisión es incompatible.
- Preparar los datos vanilla y el autocompletado de **Enter Code** en el área de trabajo. El jugador sigue confirmando con Enter. Mantener el disco original intacto.
- Guardar la preparación por revisión y versión del port. Publicar el resultado local solo al terminar y permitir reintentar si se corta la preparación. Mantener los perfiles y las partidas fuera de la caché.

**Cierre:** una ISO válida se prepara desde el lanzador y un segundo arranque reutiliza los archivos. Una extracción interrumpida se puede reintentar sin perder guardados.

### 4. Entregar el lanzador desde un clon limpio

- Elegir una entrada de doble clic que esté presente después de clonar o descomprimir el repositorio. Probar un iniciador pequeño que obtenga una versión fijada del paquete desde GitHub Releases, valide su SHA-256 y la guarde localmente. Incluir un ZIP de Release con el paquete base para quien prefiera evitar esa descarga al iniciar.
- Mostrar las etapas de descarga, validación, extracción y compilación. Si falla alguna, mostrar el paso y dónde quedó el registro.
- Hacer que el lanzador cargue siempre la build vanilla y el complemento con sombras corregidas. Separar binarios, caché y partidas para que actualizar o reinstalar el port no borre el progreso.

**Cierre:** desde un clon nuevo, el usuario coloca su ISO, hace doble clic y llega al juego. Después de preparar el port, puede abrirlo sin conexión.

### 5. Probar antes de publicar

- En Windows limpio, probar tanto el clon como el ZIP, con rutas que contengan espacios y sin permisos de administrador.
- Con la ISO compatible, llegar al menú, verificar el campo de extras, completar un partido, volver al menú, guardar un torneo, cerrar y recargarlo. Comprobar césped, líneas, sombras, audio y mando.
- Repetir con la red desconectada después de la preparación. Probar también una ISO incompatible, una descarga interrumpida y falta de espacio.
- Revisar el repositorio y los archivos de Release para confirmar que solo incluyen los componentes previstos. Mantener la ISO, el XEX, los assets, el código generado y los guardados fuera del paquete publicado.

## Prueba inicial en la PC de desarrollo

La validación en Windows limpio queda para el final. Podemos desarrollar y medir el paquete en esta PC y reducir el acceso de cada prueba a las herramientas instaladas.

- Revisé las importaciones de la build vanilla. Además del runtime de ReXGlue y el complemento gráfico, esta configuración carga Tracy y las bibliotecas de Visual C++ `MSVCP140.dll`, `MSVCP140_ATOMIC_WAIT.dll`, `VCRUNTIME140.dll` y `VCRUNTIME140_1.dll`. Falta comprobar las bibliotecas que se cargan al ejecutar y decidir cuáles puede llevar el paquete.
- Compilé `port/src/main.cpp` con un `PATH` reducido a Windows, sin las variables del entorno de Visual Studio y con la búsqueda automática de cabeceras desactivada. Con solo Clang y ReXGlue faltó `cstring`. Al indicar las rutas locales de las cabeceras de C++ y Windows, el mismo archivo compiló. Se comprobó un archivo del port, todavía queda hacer la generación y el enlace completos en el entorno reducido.
- El siguiente paso en esta PC es preparar un directorio de prueba con el generador y el compilador, declarar explícitamente las cabeceras y bibliotecas que consume, y generar y enlazar el port desde cero. Con esa lista podremos evaluar qué se descarga, qué se puede empaquetar y cuánto pesa. La prueba final en otro Windows comprobará que el paquete no depende de archivos o configuraciones de esta máquina.

## Generación y enlace aislados en esta PC (8 de noviembre de 2026)

Se clonó `main` en `C:\Users\pipeta\Documents\rwc2011-vanilla-lab`, commit `ed60d95b0136f1847f2be3ef25afc317d63059a1`. Una copia de sus archivos mediante `git archive`, sin carpeta `.git`, está en `C:\Users\pipeta\Documents\rwc2011-vanilla-run`: allí quedaron el código generado, los objetos, el ejecutable y la capa local. `original/game` en esa copia es una unión a la copia original de este workspace; no se escribieron archivos en ella. El SHA-256 de `default.xex` coincidió antes y después con `8045c61254615b223591efee3bd9b34fa6a05ba1bfe1dd61719e248d454ea201`. No se incorporó contenido del disco ni código generado al clon.

La generación con ReXGlue 0.10.0 terminó en 7,7 segundos y escribió 237 archivos. `check_task_sync.py` confirmó las dos barreras, y `prepare_unlock_prefill.py` creó la capa local: el jugador sigue confirmando el código. Se compilaron y enlazaron todas las unidades con `RelWithDebInfo`; la salida fue `build/rugby2011.exe`. Los 240 archivos generados ocupan aproximadamente 125 MB y el árbol de build medido, incluidos duplicados para el lanzador, 285 MB. No se midió una descarga mínima ni el tiempo total de primera preparación.

### Reproducción en esta máquina

1. Desde el clon aislado, exportar el commit a una carpeta de trabajo externa con `git archive HEAD | tar -xf - -C <carpeta>`, crear `original/game` como unión a una extracción propia y comprobar el hash del XEX. La unión solo se usa para lectura; nunca ejecutar herramientas que modifiquen ese destino.
2. Con `PATH` limitado a `C:\Windows\System32;C:\Windows` y sin `INCLUDE`, `LIB`, `LIBPATH`, `WindowsSdkDir` ni `VCToolsInstallDir`, ejecutar desde `port` la ruta absoluta `C:\Users\pipeta\Documents\Rugby\tools\rexglue-0.10.0\win-amd64\bin\rexglue.exe codegen rugby2011_manifest.toml`.
3. Ejecutar con `C:\Users\pipeta\AppData\Local\Python\pythoncore-3.14-64\python.exe` los scripts `scripts/check_task_sync.py` y `scripts/prepare_unlock_prefill.py` desde la raíz de trabajo.
4. Ejecutar `build-explicit.ps1` en `C:\Users\pipeta\Documents\rwc2011-vanilla-run`. El script conserva las rutas exactas, las opciones y el entorno de la compilación, junto a `configure.log` y `build.log`. La búsqueda automática de cabeceras está desactivada; las cabeceras intrínsecas de Clang deben preceder a las de MSVC. El script es un experimento específico de esta PC, no un instalador portable. CMake y Ninja se usan en esta prueba; no se ha demostrado que sean indispensables para el enlace final.
5. Para reproducir el arranque de esta sesión, copiar el ejecutable, `rexruntimerd.dll` y `TracyClientrd.dll` de `build/` a `build/port-shadow-integer-fetch/`; copiar allí el complemento corregido indicado abajo, ejecutar `scripts/build_launcher.ps1` y abrir `Jugar Rugby 2011.exe`. La capa de extras y las partidas se guardan en `work/` de la copia aislada.

Se usaron Clang 19.1.5 y `lld-link` del LLVM de Visual Studio Build Tools; cabeceras y bibliotecas MSVC `14.44.35207`; cabeceras y bibliotecas UCRT y UM del Windows SDK `10.0.26100.0`; CMake `3.31.6-msvc6`, Ninja `1.12.1`, Python `3.14.0` y ReXGlue SDK `0.10.0`. El script declara `LIB` para MSVC, UCRT y UM y `-nostdinc` con cada carpeta de cabeceras, además de las rutas a las herramientas. Se reutilizaron instalaciones de esta PC, por lo que no se ha demostrado aún un paquete portable ni descartado dependencias implícitas del sistema. La compilación del lanzador empleó el compilador C# de .NET Framework incluido en Windows según `scripts/build_launcher.ps1`.

Para las sombras se reutilizó `Rugby/build/gpu-integer-fetch/graphics/rexgpu-xenosrd.dll`, SHA-256 `2A3F9AA56FBC3454928BE7DD735F7095BD682B94B1C6470C9BD04209513A767F`, idéntico al de la build corregida anterior. El complemento no se reconstruyó en esta sesión; los parches y la receta de reconstrucción están en `main`. La implementación de guardado de `main` se compiló sin modificar, pero no se volvió a probar una partida guardada en esta build.

El lanzador abrió el ejecutable generado, el proceso respondió y se vio la pantalla gráfica de HB Studios. El registro también llegó a cargar recursos de interfaz; los avisos de búsqueda en `update:` no demuestran por sí solos un fallo, pues la capa local solo contiene el archivo de extras. No se completó un partido ni se verificó visualmente Enter Code, sombras o guardado en esta ejecución; tampoco se probó sin red ni en otro Windows. El arranque en esta máquina no demuestra ausencia de dependencias instaladas.

Las importaciones estáticas de esta configuración incluyen `rexruntimerd.dll`, `rexgpu-xenosrd.dll`, `TracyClientrd.dll`, `MSVCP140.dll`, `MSVCP140_ATOMIC_WAIT.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`, UCRT y bibliotecas de Windows. Es un inventario parcial: faltan cargas dinámicas y una prueba limpia. El ejecutable generado mide 38.982.144 bytes; runtime, complemento corregido y Tracy suman 14.622.720 bytes. No se probó eliminar Tracy ni cambiar a Release.

### Siguiente trabajo

En CI, sin el disco, se pueden construir y verificar el lanzador y el complemento gráfico con sus dos parches, y preparar herramientas, runtime y avisos de licencia. No se puede generar ni distribuir el ejecutable específico del juego ni el código derivado del XEX. Hay que comprobar expresamente los derechos de redistribución de compilador, bibliotecas, SDK y extractor antes de empaquetarlos.

El lanzador final todavía debe detectar/extraer y validar la ISO, preparar la capa de extras, obtener y verificar los componentes necesarios, ejecutar generación y enlace, presentar progreso y errores, y reutilizar el resultado sin red. El lanzador actual solo abre una build y datos ya preparados. El próximo paso concreto es convertir `build-explicit.ps1` en una prueba con un conjunto de archivos copiado a un directorio aislado, midiendo tamaños y resolviendo las DLL cargadas y licencias; luego automatizar ISO y enlace, y finalmente repetir el flujo completo en Windows limpio sin herramientas instaladas, incluyendo partida, sombras, guardado, extras y segundo arranque sin conexión.

## Prueba con herramientas copiadas y rutas explícitas (8 de noviembre de 2026)

Se exportó otra copia limpia del commit `ed60d95b0136f1847f2be3ef25afc317d63059a1` a `C:\Users\pipeta\Documents\rwc2011-copied-test`, fuera del clon y sin `.git`. `original/game` es una unión a la copia local, usada como entrada; el hash del XEX siguió siendo `8045c61254615b223591efee3bd9b34fa6a05ba1bfe1dd61719e248d454ea201`. El clon `rwc2011-vanilla-lab` terminó limpio y no se publicó ningún paquete.

Las herramientas y bibliotecas se copiaron a `C:\Users\pipeta\Documents\rwc2011-toolset-test`. El inventario y las rutas de origen están en `rwc2011-vanilla-run/copy-toolset.ps1`. En la segunda copia, `run-copied.ps1` limpia las variables conocidas del entorno de desarrollo, establece un `PATH` reducido, fija `LIB` y las carpetas de cabeceras copiadas, verifica el XEX, ejecuta el generador, valida las barreras y prepara el autocompletado, configura y compila. Para repetir desde cero: exportar el commit a una carpeta nueva sin `.git`, crear la unión `original/game`, copiar allí `run-copied.ps1` y ejecutarlo con `-Toolset <ruta de la copia>`. El script no limpia una build anterior automáticamente.

En el primer intento CMake no encontró `CMAKE_RC_COMPILER`: la prueba anterior había dejado que lo detectara en la instalación. Se agregó `llvm-rc.exe` copiado y su ruta explícita, así como `llvm-lib.exe`. La generación, verificación de sincronización, preparación del texto de extras y compilación/enlace completos terminaron correctamente con las herramientas copiadas. El código generado y los datos permanecen en la carpeta de prueba externa, no en el repositorio.

El conjunto copiado no está optimizado: 1.449.973.349 bytes (1,35 GiB), sin comprimir: CMake 43,3 MiB, LLVM 159,7 MiB, MSVC 309,5 MiB, Ninja 2,5 MiB, Python 132,3 MiB, ReXGlue 199,1 MiB y Windows SDK 536,2 MiB. Los tamaños completos por carpeta están en `toolset-sizes.json`; incluyen archivos no usados y no representan un mínimo ni una descarga medida. Se copiaron directorios completos salvo las herramientas LLVM y Ninja seleccionadas. La generación tomó 8,5 segundos en la primera ejecución; no se midió el tiempo completo de compilación.

El registro de dependencias de Ninja (`observed-files.txt`, derivado de `observed-deps.txt`) identificó 128 cabeceras/archivos de LLVM, 137 de MSVC, 215 de ReXGlue, 160 del SDK de Windows y 247 del proyecto/generación. Son archivos registrados por compilaciones concretas, no una garantía de que basten para otros casos. No se observaron rutas de las instalaciones originales en esas dependencias; en la configuración solo aparece `C:/Program Files (x86)/rugby2011` como prefijo de instalación predeterminado, que no se utilizó. Una reinspección del enlace con `lld-link /verbose` quedó en `relink.log` y `link-libraries.txt`: leyó cuatro bibliotecas MSVC, cinco de ReXGlue, UCRT y bibliotecas de importación de Windows, todas desde el conjunto copiado. La compilación usa `-nostdinc` y rutas explícitas; esto no es una auditoría completa de accesos a archivos ni descarta búsquedas por registro o DLL de sistema.

Para probar arranque se copiaron el EXE resultante, `rexruntimerd.dll` y `TracyClientrd.dll` junto al complemento corregido ya construido cuyo hash figura arriba, y se usó el lanzador de `main`. El proceso abrió y respondió. Las capturas de módulos `loaded-modules.csv` y `loaded-modules-later.csv` corresponden a instantes del arranque, no a una sesión completa. Además de las tres DLL locales, se cargaron desde `C:\Windows\System32` `MSVCP140.dll`, `MSVCP140_ATOMIC_WAIT.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`, UCRT y componentes de Direct3D. Por tanto la máquina actual aporta el runtime de Visual C++; queda pendiente probar qué ocurre sin él y elegir un mecanismo de distribución permitido. No se probó desconectar la red, entrar en un partido ni guardar y recargar. No se reconstruyó el complemento gráfico en esta etapa.

### Distribución y licencias: revisión inicial

- [ReXGlue 0.10.0](https://raw.githubusercontent.com/rexglue/rexglue-sdk/v0.10.0/LICENSE) permite redistribución bajo sus condiciones de aviso; hay que incluir su licencia y revisar por separado las de sus dependencias. El SDK copiado contiene un aviso de SDL3, pero no se ha hecho todavía un inventario completo de terceros.
- [LLVM](https://llvm.org/LICENSE.txt) usa Apache 2.0 con excepciones LLVM; [CMake](https://cmake.org/licensing/) usa BSD de tres cláusulas y también incorpora terceros; [Ninja](https://github.com/ninja-build/ninja/blob/master/COPYING) usa Apache 2.0; [Python](https://docs.python.org/3/license.html) tiene sus propios avisos. Deben incluirse los textos y avisos aplicables a los binarios efectivamente distribuidos y revisar las variantes suministradas con Visual Studio.
- [Microsoft distingue los archivos redistribuibles de Visual Studio 2022](https://learn.microsoft.com/en-us/visualstudio/releases/2022/redistribution) y condiciona los runtimes a los términos correspondientes. Esa lista no establece por sí sola que se puedan redistribuir las carpetas de cabeceras y bibliotecas de desarrollo copiadas en esta prueba; tampoco se ha confirmado el derecho aplicable a los archivos del Windows SDK. No publicar ni ofrecer este conjunto como paquete hasta resolver las licencias exactas de su procedencia. La copia local es un experimento técnico, no una autorización de redistribución.

### Próximo paso concreto

Reducir el conjunto de manera verificable: construir una nueva carpeta con los archivos observados y las herramientas imprescindibles, repetir generación y enlace desde una exportación vacía, y comparar el resultado. Investigar una alternativa distribuible a las cabeceras y bibliotecas de Microsoft o una descarga oficial cuyo uso cumpla sus términos, sin exigir instalación manual. Después integrar una preparación reproducible en el lanzador y probarla en Windows limpio, incluyendo dependencias de ejecución, sombras, guardado, extras y arranque posterior sin red. El tamaño mínimo, las licencias finales y el flujo de un clic siguen abiertos.

## Reducción del entorno de compilación (8 de noviembre de 2026)

A partir del registro de cabeceras de Ninja y del registro de bibliotecas de `lld-link` de la prueba anterior se construyó un conjunto reducido en carpetas externas al repositorio. `C:\Users\pipeta\Documents\rwc2011-copied-test\make-reduced.ps1` reproduce la selección: copia los archivos observados de cabeceras y bibliotecas de MSVC y Windows SDK, las herramientas LLVM elegidas y, todavía completos, CMake, Ninja y ReXGlue. Acepta `-PythonEmbed` para usar el paquete embebible de Python. Se mantuvieron las rutas relativas y las carpetas de búsqueda vacías que necesita la configuración. Es una selección empírica para esta revisión y configuración, no un mínimo demostrado ni un paquete publicable.

La primera exportación nueva, en `C:\Users\pipeta\Documents\rwc2011-reduced-test`, generó, compiló y enlazó con un conjunto de 590.491.908 bytes. Su primer intento de configuración falló porque CMake probó el compilador usando `msvcrtd.lib` de depuración, que no forma parte del enlace de `RelWithDebInfo`. Se fijó `CMAKE_TRY_COMPILE_CONFIGURATION=RelWithDebInfo` en `run-copied.ps1`; el segundo intento terminó correctamente sin añadir esa biblioteca. El script resultante quedó en la carpeta de prueba y también se copió a la siguiente.

Se probó además [Python 3.14.0 embebible x64 oficial](https://www.python.org/downloads/release/python-3140/), sin instalación manual. El ZIP descargado de python.org coincidió con el MD5 publicado (`7c5d8d8e3213a11bd0e36f8b8eb03431`); el SHA-256 observado localmente fue `8d4d3590c10449d78aa4375f534e6d5f3027d67fdc362dd1a882279db6f90fdf`. Esta comparación de MD5 identifica la descarga frente a la página consultada, pero no sustituye un mecanismo de verificación fuerte para el lanzador final. El paquete descomprimido ocupa 22.814.689 bytes. Con él pasaron `check_task_sync.py` y `prepare_unlock_prefill.py`.

La repetición integrada partió de otra exportación vacía del mismo commit y está en `C:\Users\pipeta\Documents\rwc2011-embed-test`. El conjunto `C:\Users\pipeta\Documents\rwc2011-reduced-embed-toolset` ocupa **474.549.877 bytes (452,6 MiB) descomprimidos**, frente a 1.449.973.349 bytes de la copia amplia: una reducción aproximada del 67,3 %. CMake ocupa 45.453.157 bytes; LLVM, 156.048.523; MSVC, 17.895.910; Ninja, 2.649.032; Python, 22.814.689; ReXGlue, 208.778.790; Windows SDK, 20.909.776. El detalle de archivos está en `rwc2011-copied-test/reduced-embed-sizes.json`. No se midió un archivo comprimido ni una descarga completa.

Desde la raíz de la exportación nueva se ejecutó `run-copied.ps1 -Toolset C:\Users\pipeta\Documents\rwc2011-reduced-embed-toolset`. La generación escribió 237 archivos; pasaron las dos comprobaciones de sincronización y se preparó la capa local de extras; se compilaron las 127 etapas y se enlazó `build/rugby2011.exe`. El proceso completo cronometrado tardó 122,8 segundos en esta PC, con cuatro trabajos y datos ya extraídos; no incluye descarga ni extracción de la ISO. Los 235 archivos `.cpp` y `.h` generados coinciden byte por byte con los de la prueba amplia (`source-comparison.txt`). No se afirma que los ejecutables sean reproducibles byte por byte.

El lanzador compilado desde `main` abrió esta build y el proceso respondió. Para arrancar se reutilizó el mismo complemento de sombras corregido documentado arriba; no se reconstruyó en esta etapa. Las DLL MSVC siguieron cargándose desde `C:\Windows\System32`, según `loaded-modules.csv`. El guardado se compiló sin cambios y el autocompletado se preparó; no se verificaron jugando en esta ejecución. Tampoco se probó sin red, en Windows limpio, ni con una ISO desde el lanzador. El SHA-256 del XEX original siguió coincidiendo y el clon separado de `main` quedó limpio.

Para reproducir el experimento, con las dos carpetas de la prueba anterior y la extracción embebible de Python disponibles: ejecutar `make-reduced.ps1 -Destination <carpeta nueva> -PythonEmbed <carpeta Python embebible>` desde `rwc2011-copied-test`; exportar el commit a otra carpeta nueva sin `.git`, crear la unión de lectura `original/game`, copiar `rwc2011-embed-test/run-copied.ps1` y ejecutarlo con `-Toolset <carpeta nueva>`. El generador requiere la revisión exacta del XEX. La preparación de la unión, el lanzador y el complemento corregido todavía no están automatizados por este script.

### Próximo paso concreto

Revisar y reducir el SDK ReXGlue completo y el uso de CMake sin perder la compilación reproducible; en paralelo, resolver una fuente y condiciones de distribución para las cabeceras y bibliotecas de MSVC/Windows SDK y para el runtime cargado. La selección de archivos y el éxito en esta PC no otorgan derechos de redistribución ni demuestran independencia de componentes instalados. Después integrar la preparación en el lanzador, verificar descargas con una fuente de hashes confiable y realizar la prueba completa en Windows limpio, incluida la segunda apertura sin conexión. La ISO, el XEX, los datos, el código generado y los ejecutables derivados permanecen fuera de los repositorios y paquetes públicos.
