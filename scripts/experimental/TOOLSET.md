# Conjunto de compilación experimental

`get_build_utilities.ps1 -Destination <carpeta nueva>` obtiene CMake 3.31.6, Ninja 1.12.1 y Python 3.14.0 embebible de sus fuentes oficiales, comprueba los SHA-256 fijados y extrae las herramientas sin instalarlas. `-PackageCache` admite archivos descargados previamente y vuelve a verificarlos. El hash de CMake coincide con el archivo de sumas publicado por Kitware; los de Ninja y Python se fijaron a partir de las descargas observadas.

`assemble_toolset.ps1 -Destination <carpeta nueva> -ComponentsRoot <carpeta>` reúne los componentes ya extraídos. Deben estar bajo `ComponentsRoot/msvc`, `windows-sdk`, `llvm`, `utilities` y `rexglue`, respectivamente como los generan `get_msvc.ps1`, `get_windows_sdk.ps1`, `get_llvm.ps1`, `get_build_utilities.ps1` y `get_rexglue_sdk.ps1`. El script comprueba que existan antes de copiar; aún no ejecuta las descargas por sí mismo. Su salida ocupa 1.184.681.965 bytes en la prueba, sin optimizar.

Se ejecutaron la extracción de utilidades y el ensamblado con PowerShell 5.1, y desde una exportación limpia se generó y compiló el juego con el conjunto resultante. Los componentes provenían de descargas verificadas de Microsoft, LLVM, Kitware, Ninja, Python y ReXGlue, con los archivos del juego ya extraídos. El proceso usó rutas y cabeceras explícitas y un PATH reducido en esta PC; no es una auditoría completa de archivos ni una prueba en Windows limpio. No se abrió el ejecutable ni se comprobó una partida con esta build.

Sigue pendiente coordinar las descargas desde el lanzador, reducir tamaño, resolver las condiciones aplicables a los componentes Microsoft, proporcionar la DLL gráfica corregida y verificar la primera preparación y el segundo arranque sin conexión en otra máquina.
