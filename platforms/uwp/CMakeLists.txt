cmake_minimum_required(VERSION 3.25)

# UWP (Xbox) build, stage 2: packages the static game library built by the windows-uwp-lib
# preset (stage 1). Configure with the Visual Studio generator, for example:
#   cmake -S platforms/uwp -B build/uwp -G "Visual Studio 18 2026" -A x64
# See GUIA_UWP.md at the repository root.

set(CMAKE_SYSTEM_NAME WindowsStore)
set(CMAKE_SYSTEM_VERSION 10.0)
# Stage 1 is RelWithDebInfo with the release DLL CRT; Debug would mix CRTs.
set(CMAKE_CONFIGURATION_TYPES "RelWithDebInfo;Release" CACHE STRING "" FORCE)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL" CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
include(AssetDeploy)

project(dusklight-uwp LANGUAGES CXX)
set_directory_properties(PROPERTIES VS_STARTUP_PROJECT ${PROJECT_NAME})

get_filename_component(_dusk_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(DUSK_DIR "${_dusk_root}/build/uwp-lib" CACHE PATH "Stage 1 build directory (windows-uwp-lib preset)")
set(DUSK_UWP_CERTIFICATE "" CACHE FILEPATH "Optional .pfx used to sign the package (its subject must match the manifest Publisher)")
set(DUSK_UWP_MIN_VERSION "10.0.17763.0" CACHE STRING "Minimum Windows/Xbox OS version of the package")

if (NOT EXISTS "${DUSK_DIR}/uwp_link.cmake")
	message(FATAL_ERROR
		"dusklight-uwp: ${DUSK_DIR}/uwp_link.cmake not found. Build stage 1 first:\n"
		"  cmake --preset windows-uwp-lib\n"
		"  cmake --build --preset windows-uwp-lib\n"
		"or point DUSK_DIR at the stage 1 build directory.")
endif ()
include("${DUSK_DIR}/uwp_link.cmake")

if (NOT DUSK_UWP_MSVC_RUNTIME_LIBRARY STREQUAL "MultiThreadedDLL")
	message(FATAL_ERROR "dusklight-uwp: stage 1 must use the MultiThreadedDLL (/MD) CRT; "
		"found '${DUSK_UWP_MSVC_RUNTIME_LIBRARY}'. Use the windows-uwp-lib preset.")
endif ()
if (MSVC_VERSION AND DUSK_UWP_MSVC_VERSION AND MSVC_VERSION LESS DUSK_UWP_MSVC_VERSION)
	message(FATAL_ERROR "dusklight-uwp: stage 1 was built with a newer MSVC (${DUSK_UWP_MSVC_VERSION}) "
		"than this project uses (${MSVC_VERSION}). Use the same Visual Studio for both stages.")
endif ()
message(STATUS "dusklight-uwp: stage 1 (${DUSK_UWP_CONFIG}) from ${DUSK_DIR}")

# Libraries from the stage 1 link manifest; check they were all built.
set(_dusk_link_libs "")
set(_dusk_missing "")
foreach (_lib IN LISTS DUSK_UWP_GAME_LIB DUSK_UWP_LINK_LIBS)
	if (_lib STREQUAL "")
		continue()
	endif ()
	if (IS_ABSOLUTE "${_lib}" AND NOT EXISTS "${_lib}")
		list(APPEND _dusk_missing "${_lib}")
	endif ()
	list(APPEND _dusk_link_libs "${_lib}")
endforeach ()
if (_dusk_missing)
	list(JOIN _dusk_missing "\n  " _dusk_missing_text)
	message(FATAL_ERROR "dusklight-uwp: stage 1 libraries are missing, run "
		"'cmake --build --preset windows-uwp-lib' first:\n  ${_dusk_missing_text}")
endif ()

set(_dusk_uwp_dep "${DUSK_UWP_SOURCE_DIR}/extern/uwp-dep/x64")

add_executable(${PROJECT_NAME} WIN32
	main.cpp
	Package.appxmanifest
)
set_target_properties(${PROJECT_NAME} PROPERTIES
	VS_WINDOWS_TARGET_PLATFORM_MIN_VERSION "${DUSK_UWP_MIN_VERSION}"
)
target_include_directories(${PROJECT_NAME} PRIVATE "${_dusk_uwp_dep}/include")

if (DUSK_UWP_CERTIFICATE)
	if (NOT EXISTS "${DUSK_UWP_CERTIFICATE}")
		message(FATAL_ERROR "dusklight-uwp: DUSK_UWP_CERTIFICATE not found: ${DUSK_UWP_CERTIFICATE}")
	endif ()
	target_sources(${PROJECT_NAME} PRIVATE "${DUSK_UWP_CERTIFICATE}")
endif ()

# Runtime DLLs: everything shipped by uwp-dep (SDL3, Dawn, DXC, nod, libpng, zlib, libuwp) plus
# any shared library found in the stage 1 link manifest. UWP loads DLLs from the package root.
file(GLOB _dusk_dlls "${_dusk_uwp_dep}/bin/*.dll")

# The uwp-dep SDL3.dll hangs when opening an audio device (patches/sdl3-uwp-threadid.patch);
# tools\uwp\sdl3.bat builds a fixed one from extern/SDL3-uwp, which is packaged instead.
set(DUSK_UWP_SDL3_DLL "${_dusk_root}/build/sdl3-uwp/RelWithDebInfo/SDL3.dll" CACHE FILEPATH
	"SDL3.dll to package instead of the uwp-dep one (empty: package the uwp-dep SDL3.dll)")
if (DUSK_UWP_SDL3_DLL)
	if (NOT EXISTS "${DUSK_UWP_SDL3_DLL}")
		message(FATAL_ERROR "dusklight-uwp: ${DUSK_UWP_SDL3_DLL} not found. Build it with tools\\uwp\\sdl3.bat, "
			"or configure with -DDUSK_UWP_SDL3_DLL= to package the uwp-dep SDL3.dll (it hangs when opening audio).")
	endif ()
	list(FILTER _dusk_dlls EXCLUDE REGEX "/SDL3\\.dll$")
	list(APPEND _dusk_dlls "${DUSK_UWP_SDL3_DLL}")
	message(STATUS "dusklight-uwp: SDL3.dll from ${DUSK_UWP_SDL3_DLL}")
endif ()

set(_dusk_dll_names "")
foreach (_dll IN LISTS _dusk_dlls)
	get_filename_component(_name "${_dll}" NAME)
	list(APPEND _dusk_dll_names "${_name}")
endforeach ()
foreach (_dll IN LISTS DUSK_UWP_RUNTIME_DLLS)
	get_filename_component(_name "${_dll}" NAME)
	if (_dll STREQUAL "" OR _name IN_LIST _dusk_dll_names)
		continue()
	endif ()
	if (NOT EXISTS "${_dll}")
		message(FATAL_ERROR "dusklight-uwp: runtime DLL from stage 1 not found: ${_dll}")
	endif ()
	list(APPEND _dusk_dlls "${_dll}")
	list(APPEND _dusk_dll_names "${_name}")
endforeach ()
source_group("BinDeps" FILES ${_dusk_dlls})
set_source_files_properties(${_dusk_dlls} PROPERTIES
	VS_COPY_TO_OUT_DIR Always
	VS_DEPLOYMENT_CONTENT TRUE
	VS_DEPLOYMENT_LOCATION "."
)
target_sources(${PROJECT_NAME} PRIVATE ${_dusk_dlls})
list(JOIN _dusk_dll_names ", " _dusk_dll_text)
message(STATUS "dusklight-uwp: packaged DLLs: ${_dusk_dll_text}")

set(PkgAssets
	Assets/LockScreenLogo.scale-200.png
	Assets/Square44x44Logo.targetsize-24_altform-unplated.png
	Assets/Square44x44Logo.scale-200.png
	Assets/Square150x150Logo.scale-200.png
	Assets/Wide310x150Logo.scale-200.png
	Assets/StoreLogo.png
	Assets/SplashScreen.scale-200.png
)
source_group("PkgAssets" FILES ${PkgAssets})
set_source_files_properties(${PkgAssets} PROPERTIES
	VS_DEPLOYMENT_CONTENT TRUE
	VS_DEPLOYMENT_LOCATION "Assets"
)
target_sources(${PROJECT_NAME} PRIVATE ${PkgAssets})

# The game library is linked whole, exactly like the objects of the desktop executable.
target_link_libraries(${PROJECT_NAME} PRIVATE
	${_dusk_link_libs}
	WindowsApp.lib
	OneCore.lib
	ntdll.lib
)
target_link_options(${PROJECT_NAME} PRIVATE
	"/WHOLEARCHIVE:${DUSK_UWP_GAME_LIB}"
	/NODEFAULTLIB:libcmt
	/NODEFAULTLIB:libcmtd
	${DUSK_UWP_LINK_OPTIONS}
)
target_compile_definitions(${PROJECT_NAME} PRIVATE AURORA_WINDOWS_STORE)

# Game resources (fonts, UI, etc.) are read from res/ next to the executable.
uwp_pkg(${PROJECT_NAME} "${DUSK_UWP_SOURCE_DIR}/res" "res")
