# Obtención experimental de bibliotecas de C++

`get_msvc.ps1 -Destination <carpeta nueva>` descarga de Microsoft y verifica por SHA-256 los dos paquetes fijados en `msvc_packages.json`, y los extrae sin instalar Visual Studio. `-PackageCache <carpeta>` acepta copias locales y también verifica su hash. Los dos archivos descargados en esta prueba ocuparon 29.713.131 bytes; el campo `size` de los metadatos oficiales no coincidió con los tamaños recibidos, aunque los SHA-256 sí coincidieron, por lo que se usa el hash para comprobarlos.

Se compararon los 141 archivos de C++ del conjunto reducido anterior: todos los encabezados y bibliotecas coincidieron byte por byte con los extraídos. En una exportación limpia se generó y compiló el port con esos archivos y con los del SDK de Windows procedentes de los paquetes oficiales; el enlace terminó correctamente. Las demás herramientas seguían viniendo del conjunto local. El script se probó con PowerShell 5.1 a partir de paquetes descargados y verificados previamente.

El experimento aún no está integrado en el lanzador. Hay que revisar los términos aplicables a descargar, extraer y usar los paquetes, verificar el procedimiento en otro Windows y comprobar una partida con el ejecutable resultante. No se ha demostrado que los paquetes sean mínimos.
