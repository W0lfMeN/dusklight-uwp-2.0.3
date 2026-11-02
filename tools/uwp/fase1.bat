@echo off
rem Dusklight UWP, fase 1: compila el juego como libreria estatica (preset windows-uwp-lib).
rem Ejecutar desde "x64 Native Tools Command Prompt for VS 2026".
rem Deja entorno.log, fase1-configure.log y fase1-build.log en la raiz.
rem Admite opciones extra de CMake, por ejemplo: tools\uwp\fase1.bat -DDUSK_UWP_NETWORK=OFF
setlocal
cd /d "%~dp0..\.."

call "%~dp0check-env.bat" > entorno.log 2>&1
set "ENV_RC=%errorlevel%"
type entorno.log
if not "%ENV_RC%"=="0" (
    echo [ERROR] Corrige el entorno y vuelve a ejecutar. Detalles en entorno.log
    exit /b 1
)

rem Una configuracion fallida anterior deja una cache incompleta: se rehace desde cero.
set "FRESH="
if exist "build\uwp-lib\CMakeCache.txt" if not exist "build\uwp-lib\build.ninja" set "FRESH=--fresh"

echo Configurando... (fase1-configure.log)
cmake --preset windows-uwp-lib %FRESH% %* > fase1-configure.log 2>&1
if errorlevel 1 (
    echo [ERROR] La configuracion ha fallado. Envia fase1-configure.log y entorno.log
    exit /b 1
)

echo Compilando... (fase1-build.log) La primera vez tarda bastante.
cmake --build --preset windows-uwp-lib > fase1-build.log 2>&1
if errorlevel 1 (
    echo [ERROR] La compilacion ha fallado. Envia fase1-build.log
    exit /b 1
)

echo.
echo Fase 1 completada: build\uwp-lib\dusklight.lib y build\uwp-lib\uwp_link.cmake
exit /b 0
