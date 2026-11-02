// Entry point of the UWP package. The game is SDL_main, compiled into dusklight.lib from
// src/dusk/main.cpp (stage 1, DUSK_UWP); SDL3-UWP runs it inside a CoreApplication.
#include <Windows.h>

// The WinRT SDL_main implementation would define its own WinMain (and requires /ZW).
#define SDL_MAIN_HANDLED
#include "SDL3/SDL.h"
#include "SDL3/SDL_main.h"

static int SDLCALL bootstrap(int argc, char** argv)
{
  // todo: Force these in SDL-UWP? (at least wgi)
  SDL_SetHint(SDL_HINT_ENABLE_SCREEN_KEYBOARD, "true");
  SDL_SetHint(SDL_HINT_JOYSTICK_WGI, "true");
  // Keep the B button from navigating back to the Xbox home screen.
  SDL_SetHint(SDL_HINT_WINRT_HANDLE_BACK_BUTTON, "1");

  return SDL_main(argc, argv);
}

int CALLBACK WinMain(HINSTANCE, HINSTANCE, LPSTR, int)
{
  return SDL_RunApp(0, nullptr, bootstrap, nullptr);
}
