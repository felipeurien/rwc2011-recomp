# Obtención experimental de LLVM

`get_llvm.ps1 -Destination <carpeta nueva>` obtiene LLVM 19.1.5 y 7-Zip 24.09 de las versiones oficiales fijadas. Descarga `7zr.exe` y el instalador oficial de 7-Zip, extrae el programa de consola sin instalarlo, y con este extrae las herramientas LLVM y sus cabeceras, incluido `llvm-mt.exe` para compilar el complemento gráfico. Verifica los SHA-256 fijados antes de ejecutar o extraer las descargas. `-PackageCache <carpeta>` permite utilizar archivos ya descargados, verificándolos de nuevo. El hash de LLVM se fijó a partir de la descarga oficial observada; aún no se ha comprobado su firma publicada.

Se probó la extracción con Windows PowerShell 5.1 desde una copia local de las descargas. Una exportación limpia del port se generó y compiló con las herramientas LLVM oficiales extraídas, las bibliotecas de C++ y los archivos del SDK de Windows obtenidos de Microsoft; el enlace terminó correctamente. CMake, Ninja, Python y ReXGlue procedían del conjunto local. La descarga completa de LLVM ocupa 352.110.889 bytes; las herramientas y cabeceras extraídas ocupan 167.457.145 bytes. No se comprobó un partido ni se probó en otro Windows.

Todavía falta conectar estas descargas al ensamblado automático del conjunto completo y revisar las condiciones de los componentes de Microsoft. La descarga de LLVM es grande y no se ha optimizado.
