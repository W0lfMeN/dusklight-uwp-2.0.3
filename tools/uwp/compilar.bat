@echo off
rem Dusklight UWP: compila todo en orden (fase 1, SDL3 corregida y fase 2) y se para en el primer
rem error. Ejecutar desde "x64 Native Tools Command Prompt for VS 2026". Cada paso deja sus logs en
rem la raiz (ver GUIA_UWP.md). Las opciones extra de CMake van a la fase 1, por ejemplo:
rem   tools\uwp\compilar.bat -DDUSK_UWP_NETWORK=OFF
rem Para firmar en la fase 2: set DUSK_UWP_CERTIFICATE=C:\certs\dusklight.pfx antes de ejecutarlo.
setlocal
call "%~dp0fase1.bat" %* || exit /b 1
call "%~dp0sdl3.bat" || exit /b 1
call "%~dp0fase2.bat" || exit /b 1
echo.
echo Todo compilado. Siguiente: GUIA_UWP.md, paso 4 (empaquetar).
exit /b 0
