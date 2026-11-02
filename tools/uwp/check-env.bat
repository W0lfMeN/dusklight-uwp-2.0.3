@echo off
rem Comprueba que la consola es la de Visual Studio x64 y que estan cl, cmake y ninja.
rem La usan fase1.bat y fase2.bat; tambien se puede ejecutar sola.
setlocal
set "FAIL="

echo === Entorno de compilacion ===
if /i "%VSCMD_ARG_TGT_ARCH%"=="x64" (
    echo Visual Studio %VisualStudioVersion% - destino x64: OK
) else (
    echo [ERROR] Esta no es una consola de Visual Studio x64 ^(VSCMD_ARG_TGT_ARCH="%VSCMD_ARG_TGT_ARCH%"^).
    echo         Abre "x64 Native Tools Command Prompt for VS 2026" desde el menu Inicio.
    set "FAIL=1"
)

for %%T in (cl cmake ninja) do (
    where %%T >nul 2>&1 && (
        for /f "delims=" %%P in ('where %%T') do echo %%T: %%P
    ) || (
        echo [ERROR] %%T no esta en el PATH.
        set "FAIL=1"
    )
)
where ninja >nul 2>&1 || echo         ninja se instala con el componente "C++ CMake tools for Windows" de Visual Studio Installer.

rem Un zip descargado deja la "marca de la Web" en lo que se extrae y MSBuild no empaqueta esos
rem ficheros (error MSB3821). Se comprueba con una DLL de uwp-dep.
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI"
dir /r "%ROOT%\extern\uwp-dep\x64\bin\z.dll" 2>nul | findstr /c:"Zone.Identifier" >nul && (
    echo [ERROR] Los ficheros tienen la "marca de la Web" ^(vienen de un zip descargado^) y MSBuild no los empaqueta.
    echo         Quitala una vez con:
    echo         powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%ROOT%' -Recurse -File | Unblock-File"
    echo         Para evitarlo: zip ^> clic derecho ^> Propiedades ^> Desbloquear, antes de extraerlo.
    set "FAIL=1"
)

where cmake >nul 2>&1 && cmake --version | findstr /b /c:"cmake version"
where ninja >nul 2>&1 && (for /f "delims=" %%V in ('ninja --version') do echo ninja version %%V)
echo.

if defined FAIL exit /b 1
exit /b 0
