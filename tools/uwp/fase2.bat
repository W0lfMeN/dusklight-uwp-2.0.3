@echo off
rem Dusklight UWP, fase 2: genera y compila el proyecto UWP de platforms\uwp.
rem Ejecutar desde "x64 Native Tools Command Prompt for VS 2026", despues de fase1.bat y sdl3.bat.
rem Deja fase2-configure.log, fase2-build.log e imports-report.txt en la raiz.
rem Admite opciones extra de CMake, por ejemplo: tools\uwp\fase2.bat -DDUSK_UWP_CERTIFICATE=C:\certs\dusklight.pfx
rem o el certificado en una variable: set DUSK_UWP_CERTIFICATE=C:\certs\dusklight.pfx
setlocal
cd /d "%~dp0..\.."

call "%~dp0check-env.bat" > entorno.log 2>&1
set "ENV_RC=%errorlevel%"
type entorno.log
if not "%ENV_RC%"=="0" (
    echo [ERROR] Corrige el entorno y vuelve a ejecutar. Detalles en entorno.log
    exit /b 1
)

if not exist "build\uwp-lib\uwp_link.cmake" (
    echo [ERROR] Falta la fase 1 ^(build\uwp-lib\uwp_link.cmake^). Ejecuta antes tools\uwp\fase1.bat
    exit /b 1
)

if not exist "build\sdl3-uwp\RelWithDebInfo\SDL3.dll" (
    echo [AVISO] Falta la SDL3 corregida ^(build\sdl3-uwp\RelWithDebInfo\SDL3.dll^). Ejecuta antes tools\uwp\sdl3.bat
)

rem Mismo Visual Studio que la consola actual. Se puede forzar con DUSK_VS_GENERATOR.
set "GEN=%DUSK_VS_GENERATOR%"
if not defined GEN if "%VisualStudioVersion%"=="18.0" set "GEN=Visual Studio 18 2026"
if not defined GEN if "%VisualStudioVersion%"=="17.0" set "GEN=Visual Studio 17 2022"
if not defined GEN (
    echo [ERROR] Version de Visual Studio no reconocida: "%VisualStudioVersion%".
    echo         Indica el generador, por ejemplo: set DUSK_VS_GENERATOR=Visual Studio 18 2026
    exit /b 1
)

echo Configurando con "%GEN%"... (fase2-configure.log)
set "CERT_ARG="
if defined DUSK_UWP_CERTIFICATE set CERT_ARG="-DDUSK_UWP_CERTIFICATE=%DUSK_UWP_CERTIFICATE%"
cmake -S platforms\uwp -B build\uwp -G "%GEN%" -A x64 %CERT_ARG% %* > fase2-configure.log 2>&1
if errorlevel 1 (
    echo [ERROR] La configuracion ha fallado. Envia fase2-configure.log
    exit /b 1
)

echo Compilando... (fase2-build.log)
cmake --build build\uwp --config RelWithDebInfo > fase2-build.log 2>&1
if errorlevel 1 (
    echo [ERROR] La compilacion ha fallado. Envia fase2-build.log
    exit /b 1
)

echo Comprobando importaciones... (imports-report.txt)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-imports.ps1"
if errorlevel 1 echo [AVISO] No se han podido comprobar las importaciones. Envia lo que haya salido arriba.

echo.
echo Fase 2 completada. Envia imports-report.txt. Para empaquetar abre build\uwp\dusklight-uwp.slnx (.sln con VS 2022; GUIA_UWP.md, paso 4).
exit /b 0
