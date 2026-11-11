# Prueba del candidato en Intel Iris Xe

El 10 de noviembre de 2026 se probó el ZIP para Windows x64 del borrador
`v0.1.0-test`, generado desde `076dd2b`. SHA-256 del ZIP:
`1730480ef31f6fe784e0203027be8a817d4e26ed04b0e956658d7115d8c494df`.

La extracción del ZIP tardó aproximadamente diez minutos según el usuario.
El primer intento de abrir el lanzador cerró la consola antes de poder leer
el error. El usuario consiguió arrancar después y comprobó que el guardado
funciona. No quedó identificado el error inicial ni se registró una prueba
específica de recarga de torneo o de arranque sin conexión.

| Configuración | Resultado observado |
| --- | --- |
| Lanzador normal, ruta automática | Tirones y rectángulo oscuro sobre la cancha. |
| RTV forzado | Mejor fluidez, con bloques y siluetas negras intermitentes. |
| RTV con la copia directa desactivada | El parpadeo empeoró. La captura muestra bloques negros y ruido sobre el campo. |

Las capturas corresponden a partidos distintos. La comparación de fluidez
y de artefactos es cualitativa, sin mediciones de tiempo por cuadro.

Los dos registros identifican **Intel Iris Xe Graphics** (vendor `0x8086`,
device `0x9A49`) y muestran soporte para rasterizer-ordered views y referencia
de stencil desde el pixel shader. En ambas variantes RTV, D3D12 arrancó y el
juego cerró normalmente. Los errores de búsqueda de archivos y audio
aparecen en ambas pruebas y no explican los bloques. La versión del
controlador no quedó registrada.

Los lanzadores `Probar grafica Intel.cmd` y
`Probar Intel sin copia directa.cmd` se colocan junto a
`Jugar Rugby 2011.cmd` en una instalación ya preparada. Usan cachés
separadas y la carpeta de guardados de esa instalación. Escriben
`work/logs/rugby2011-intel-rtv-test.log` y
`work/logs/rugby2011-intel-rtv-sin-resolve-directo.log`, respectivamente.

Para retomar el diagnóstico, anotar la versión del controlador y reproducir
el artefacto en el mismo estadio con RTV y la copia directa activada.
Capturar un cuadro afectado en esa Iris Xe y comparar las operaciones que
escriben y leen los recursos del campo. La ruta automática sigue siendo la
referencia del lanzador. Las pruebas RTV quedan como herramientas de diagnóstico.
