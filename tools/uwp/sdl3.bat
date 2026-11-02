@echo off
rem Dusklight UWP: compila SDL3 para UWP desde extern\SDL3-uwp (SDL3-uwp ddd5d4f99 con la correccion
rem platforms\uwp\patches\sdl3-uwp-threadid.patch). La SDL3.dll de uwp-dep se cuelga al abrir el audio.
rem Ejecutar desde "x64 Native Tools Command Prompt for VS 2026". Basta una vez; despues, fase2.bat
rem empaqueta build\sdl3-uwp\RelWithDebInfo\SDL3.dll en lugar de la de uwp-dep.
rem Deja sdl3-configure.log y sdl3-build.log en la raiz.
setlocal
cd /d "%~dp0..\.."

call "%~dp0check-env.bat" > entorno.log 2>&1
set "ENV_RC=%errorlevel%"
type entorno.log
if not "%ENV_RC%"=="0" (
    echo [ERROR] Corrige el entorno y vuelve a ejecutar. Detalles en entorno.log
    exit /b 1
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

echo Configurando SDL3 con "%GEN%"... (sdl3-configure.log)
cmake -S extern\SDL3-uwp -B build\sdl3-uwp -G "%GEN%" -A x64 -DCMAKE_SYSTEM_NAME=WindowsStore -DCMAKE_SYSTEM_VERSION=10.0 -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_INSTALL=OFF "-DSDL_REVISION=SDL-3.4.16-uwp-ddd5d4f99-dusklight-threadid" %* > sdl3-configure.log 2>&1
if errorlevel 1 (
    echo [ERROR] La configuracion de SDL3 ha fallado. Envia sdl3-configure.log
    exit /b 1
)

echo Compilando SDL3... (sdl3-build.log)
cmake --build build\sdl3-uwp --config RelWithDebInfo > sdl3-build.log 2>&1
if errorlevel 1 (
    echo [ERROR] La compilacion de SDL3 ha fallado. Envia sdl3-build.log
    exit /b 1
)

if not exist "build\sdl3-uwp\RelWithDebInfo\SDL3.dll" (
    echo [ERROR] No se encuentra build\sdl3-uwp\RelWithDebInfo\SDL3.dll. Envia sdl3-build.log
    exit /b 1
)

echo.
echo SDL3 corregida: build\sdl3-uwp\RelWithDebInfo\SDL3.dll
echo Ahora ejecuta tools\uwp\fase2.bat
exit /b 0
