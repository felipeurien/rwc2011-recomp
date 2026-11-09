# Prueba de compilación con un entorno reducido

Estos scripts registran un experimento de desarrollo para Windows x64. No son todavía el lanzador de un clic ni un paquete redistribuible. El conjunto probado contiene archivos de desarrollo de Microsoft cuyos derechos de distribución siguen pendientes de revisión. No subir ni publicar esos archivos, el disco, el XEX, los datos del juego, el código generado ni los ejecutables derivados.

La selección corresponde a ReXGlue 0.10.0, LLVM 19.1.5, MSVC 14.44.35207, Windows SDK 10.0.26100.0 y la configuración RelWithDebInfo. Los dos listados contienen exclusivamente rutas relativas de cabeceras y bibliotecas observadas en esa build; no garantizan que alcancen para otras configuraciones. Se mantuvieron completos CMake, Ninja y el SDK ReXGlue de la prueba.

## Reproducir

1. Con las herramientas instaladas y una copia propia extraída, crear un directorio de herramientas amplio usando `copy_toolset.ps1`, pasando `-Destination`, `-ReXGlue` (raíz `win-amd64`) y `-Python` (raíz del intérprete). Las rutas predeterminadas de Visual Studio Build Tools y Windows SDK se pueden cambiar con `-VisualStudio` y `-WindowsKit`. Las versiones de sus subdirectorios están fijadas en el script. El destino debe ser nuevo y quedar fuera de las fuentes que se copian.
2. Ejecutar `make_reduced_toolset.ps1 -Source <carpeta-amplia> -Destination <carpeta-nueva> -PythonEmbed <carpeta-python>` para seleccionar los archivos observados. El último parámetro es opcional; se probó Python 3.14.0 embebible x64 oficial. El script no descarga ni verifica herramientas.
3. Exportar una copia de los archivos del proyecto fuera de cualquier repositorio, por ejemplo con `git archive HEAD` y una herramienta de extracción. Crear `original/game` allí como copia o unión de lectura a la extracción propia. No modificar la fuente de la unión. Las salidas generadas y la build deben permanecer en esa copia externa.
4. Ejecutar `build_with_toolset.ps1 -Root <copia-de-trabajo> -Toolset <carpeta-reducida>`. Verifica el hash de la revisión admitida, genera código, comprueba las barreras de sincronización, prepara la capa de autocompletado y compila. Los registros quedan en la copia de trabajo. No elimina resultados previos: usar una copia nueva para una prueba desde cero.

El script no prepara el complemento de sombras ni construye o ejecuta el lanzador. Las instrucciones para el complemento están en el README principal. La prueba anterior reutilizó un complemento corregido existente y abrió el juego, pero no verificó en esa ejecución un partido, guardado, Enter Code ni funcionamiento sin red o en Windows limpio. Los resultados y pendientes están en [PLAN_CLONAR_Y_JUGAR.md](../../PLAN_CLONAR_Y_JUGAR.md).
