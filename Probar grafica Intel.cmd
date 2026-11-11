@echo off
setlocal
cd /d "%~dp0"
set "GAME=%~dp0build\mingw-playable\rugby2011.exe"
if not exist "%GAME%" (
    echo No se encontro el juego preparado. Copia este archivo junto a Jugar Rugby 2011.cmd.
    pause
    exit /b 1
)
tasklist /FI "IMAGENAME eq rugby2011.exe" /NH | find /I "rugby2011.exe" >nul
if not errorlevel 1 (
    echo Cerra el juego antes de iniciar esta prueba.
    pause
    exit /b 1
)
for %%D in (saves updates metadata logs cache-intel-rtv-test) do if not exist "%~dp0work\%%D" mkdir "%~dp0work\%%D"
echo Prueba grafica Intel: ruta RTV y cache separada.
echo El primer partido puede tardar mientras se preparan los efectos.
"%GAME%" --gpu_plugin=xenos --no-async_shader_compilation --no-fullscreen --render_target_path_d3d12=rtv --log_level=info --log_flush_interval=1 "--game_data_root=%~dp0work\game" "--user_data_root=%~dp0work\saves" "--cache_root=%~dp0work\cache-intel-rtv-test" "--update_data_root=%~dp0work\updates" "--metadata_root=%~dp0work\metadata" "--log_file=%~dp0work\logs\rugby2011-intel-rtv-test.log"
if errorlevel 1 (
    echo No se pudo iniciar la prueba. Revisa work\logs\rugby2011-intel-rtv-test.log.
    pause
    exit /b 1
)
