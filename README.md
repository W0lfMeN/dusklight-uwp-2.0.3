# Dusklight UWP: Xbox Dev Mode port (unofficial)

An unofficial UWP port of [Dusklight](https://github.com/TwilitRealm/dusklight) **2.0.3** that can be
packaged as an `.msixbundle` and sideloaded on an Xbox in Developer Mode (it also runs on a Windows PC
as a UWP app).

> [!IMPORTANT]
> This project is **not affiliated with or endorsed by** TwilitRealm, XboxEmulationHub, Microsoft or
> Nintendo. Dusklight's official website is https://twilitrealm.dev/. Please report problems with this
> port **here**, not to the Dusklight or XboxEmulationHub issue trackers.

> [!IMPORTANT]
> No copyrighted assets are included. You must provide your own dump of the original game.

## Overview

Dusklight is a reverse-engineered reimplementation of Twilight Princess, based on the
[Twilight Princess decompilation](https://github.com/zeldaret/tp) and running on
[Aurora](https://github.com/encounter/aurora). This repository is the Dusklight 2.0.3 source tree with
a UWP target added on top: the game is built as a static library and linked into a UWP app that uses
Direct3D 12 (Dawn), SDL3 for UWP and the CoreWindow bridge from
[uwp-dep](https://github.com/XboxEmulationHub/uwp-dep).

This work builds on the earlier UWP port of Dusklight 1.1.1 by
[worleydl](https://github.com/worleydl/dusklight-uwp) and
[XboxEmulationHub](https://github.com/XboxEmulationHub/dusklight-uwp) (the latter archived on
2026-10-20, development discontinued). See [Credits and licenses](#credits-and-licenses).

## Status

| | |
|---|---|
| Tested on | Xbox Series X in Dev Mode (app type **Game**), and a Windows PC (F5 from Visual Studio) |
| Game disc | European GameCube release (`GZ2P01`) |
| Works | Boot, menus, internal file browser, disc verification, gameplay with sound |
| Known issue | Stutter the first time each effect is seen while its shaders compile (see [Limitations](#known-limitations)) |
| Untested | Xbox Series S, Xbox One, other discs |

## Installing a release (Xbox)

1. Download the `.msixbundle` and the dependency packages (`Microsoft.VCLibs…x64….appx`) from the
   [Releases](../../releases) page.
2. On the Xbox, open **Dev Home**, enable remote access / **Device Portal** and note its address
   (`https://<xbox-ip>:11443`).
3. From a browser on your PC, open Device Portal > **Add**, select the `.msixbundle`, add **all** the
   dependency packages in the next step and install.
4. In **Dev Home**, select *Dusklight* > **View details** and set the app type to **Game**. This is
   required: in *App* mode the console gives very few resources and there is no D3D12.
5. Copy your disc image (`.iso`, `.rvz`, `.gcz`, `.wbfs`, `.ciso`, `.wia`, `.nfs`, `.tgc`): Device
   Portal > **File explorer** > `LocalAppData` > `DusklightUWP.v2_…` > **`LocalState`** > upload. An
   `.rvz` is much smaller and faster to upload. A USB drive also works (**Drives** button in the
   game's file browser).
6. Launch Dusklight and press **Play**: the internal file browser opens in `LocalState`; pick your
   image and the game verifies it.

**Updating:** install the new package **over** the installed one. Do **not** uninstall first:
uninstalling deletes `LocalState` (disc image, saves, settings and shader cache). An update only
installs over a package signed with the same certificate, so switching between release builds and
your own builds requires uninstalling (back up `LocalState` from Device Portal first).

The package identity is `DusklightUWP.v2`, so it installs alongside the older 1.1.1 UWP port.

## Building from source

Requirements (Windows):

- **Visual Studio 2026** (tested; VS 2022 may work) with *Desktop development with C++* including
  **C++ CMake tools for Windows** (provides CMake and Ninja), *Universal Windows Platform development*
  with the C++ UWP tools, and the **Windows 11 SDK** (10.0.26100).
- Internet access the first time (CMake fetches some dependencies).
- A short path without spaces (build paths are long and Windows limits them to 260 characters). If
  you use *Code > Download ZIP*, **unblock the zip before extracting** (right click > Properties >
  Unblock), or packaging fails with `MSB3821`.

From the **"x64 Native Tools Command Prompt for VS"** (not a plain PowerShell):

```bat
cd /d C:\dl\dusklight-uwp
set DUSK_UWP_CERTIFICATE=C:\certs\dusklight.pfx
tools\uwp\compilar.bat
```

Replace `C:\dl\dusklight-uwp` with your folder (the one containing `tools\` and `src\`). The `set`
line is optional (it signs the project with your `.pfx`; keep that certificate **outside** the
repository). `compilar.bat` runs three steps and stops at the first error, leaving a log for each
one in the repository root:

1. `tools\uwp\fase1.bat`: the game as a static library (`windows-uwp-lib` preset, Ninja + MSVC,
   RelWithDebInfo). Takes a while the first time.
2. `tools\uwp\sdl3.bat`: SDL3 for UWP from `extern/SDL3-uwp`, with a fix for an audio hang (see below).
3. `tools\uwp\fase2.bat`: the UWP app project from `platforms/uwp`; it links the game, deploys the
   DLLs and resources, and writes `imports-report.txt` (DLL imports that may not exist on Xbox).

Then open `build\uwp\dusklight-uwp.slnx`:

- **Test on the PC:** configuration *RelWithDebInfo*, platform *x64*, **Local Machine**, F5. If the
  button says "Attach…", set `dusklight-uwp` as the startup project.
- **Package:** right click `dusklight-uwp` > *Publish* > *Create App Packages* > *Sideloading*,
  certificate with publisher `CN=DusklightUWP` (must match the manifest), version from the manifest
  with auto-increment off, generate bundle *Always*, x64 only, *RelWithDebInfo*.

The script messages and the detailed guide are in Spanish: see [GUIA_UWP.md](GUIA_UWP.md) for every
step, the options and the logs to check when something fails.

### Versions and release tags

- The **package version** is in `platforms/uwp/Package.appxmanifest`. Increase its last number for
  every release so it installs as an update.
- Name **Git tags** like `v2.0.3-uwp.1`. The game's version detection
  (`extern/borealis/cmake/DetectVersion.cmake`) only understands `vX.Y.Z` with an optional `-suffix`:
  a tag such as `v2.0.3.1` makes the game report `UNKNOWN-VERSION`. Without tags it uses `v2.0.3`.
- Every release must include [THIRD-PARTY-LICENSES.txt](THIRD-PARTY-LICENSES.txt) (attach it to the
  release page and ship it inside the package). See [Third-party licenses](#third-party-licenses).

## Changes from upstream Dusklight 2.0.3

- **Disabled on UWP:** native code mods, Discord, update checker, Sentry, process restart (close and
  reopen instead). Networking (WinHTTP) is kept; build with `-DDUSK_UWP_NETWORK=OFF` to drop it.
- **UI:** an internal file browser replaces the system file dialogs; settings that do not apply on
  UWP (graphics backend, window mode, portable mode, open folder…) are hidden. Graphics backend fixed
  to D3D12.
- **New:** `platforms/uwp/` (UWP app project, manifest, assets), `tools/uwp/` (build scripts),
  `cmake/UwpLinkManifest.cmake`, `windows-uwp-lib` CMake preset, line-by-line log flushing on UWP.
- **Vendored dependencies** (no Git submodules; everything needed for the UWP build is in the repo):
  - `extern/aurora` and `extern/borealis`, pinned and patched for UWP.
  - `extern/uwp-dep`: prebuilt UWP binaries (Dawn, SDL3, DXC, nod, libpng, zlib, libuwp), unmodified.
  - `extern/SDL3-uwp`: SDL3 for UWP with one fix. Its C++ thread backend did not record the thread
    ID, so opening a WASAPI audio device deadlocked (black screen right after "Powered by aurora").
- **Not included:** the `mods/randomizer` and `mods/cosmetics` submodules (only used by code mods).
- Reference diffs against the upstream sources: [`platforms/uwp/patches/`](platforms/uwp/patches).
- Design notes and status (Spanish): [PLAN_PORT_UWP.md](PLAN_PORT_UWP.md).

| Component | Source | Commit |
|---|---|---|
| Dusklight | [TwilitRealm/dusklight](https://github.com/TwilitRealm/dusklight) tag `v2.0.3` | `40457c6adb` |
| aurora | [encounter/aurora](https://github.com/encounter/aurora) | `3227d76c60` |
| borealis | [encounter/borealis](https://github.com/encounter/borealis) | `4ac5e7052a` |
| aurora UWP patch | [XboxEmulationHub/aurora](https://github.com/XboxEmulationHub/aurora), branch `uwp-dusk` | `efa2593` |
| uwp-dep | [XboxEmulationHub/uwp-dep](https://github.com/XboxEmulationHub/uwp-dep), branch `dusklight` (fork of [worleydl/uwp-dep](https://github.com/worleydl/uwp-dep)) | `810cdcb672` |
| SDL3-uwp | [XboxEmulationHub/SDL3-uwp](https://github.com/XboxEmulationHub/SDL3-uwp), branch `uwp-3.4.16` | `ddd5d4f99a` |

## Known limitations

- No native code mods; content mods may work.
- No Discord, update check, portable mode or "open folder".
- Importing/exporting saves uses the system file picker, which is not available on UWP: the option
  shows an error.
- Settings that "require a restart": close the game and open it again.
- **Shader compilation stutter:** pipelines are compiled the first time each effect is seen. They are
  cached in `LocalState\TwilitRealm\Dusklight\pipeline_cache.db` and preloaded at startup, so the
  stutter decreases as you play (the cache is kept when updating, lost when uninstalling). No initial
  cache is bundled yet.
- Logs: `LocalState\TwilitRealm\Dusklight\logs\`

## Third-party licenses

This repository and its binary releases combine code under several licenses. Each component keeps its
own license; none of them covers the original game, which belongs to Nintendo.

| Component | License | License file |
|---|---|---|
| Dusklight | CC0 1.0 | [LICENSE.md](LICENSE.md) |
| Twilight Princess decompilation (zeldaret/tp) | CC0 1.0 | upstream repository |
| Aurora | MIT (© Luke Street) | [extern/aurora/LICENSE](extern/aurora/LICENSE) |
| borealis | MIT (© Luke Street) | [extern/borealis/LICENSE](extern/borealis/LICENSE) |
| SDL3 (modified copy) | zlib | [extern/SDL3-uwp/LICENSE.txt](extern/SDL3-uwp/LICENSE.txt) |
| Prebuilt UWP binaries (Dawn, SDL3, DXC, nod, libpng, zlib, libuwp) | each under its own license | [extern/uwp-dep/lic](extern/uwp-dep/lic) |

Because the `.msixbundle` redistributes compiled copies of these components, the notices of all
bundled third-party code are collected in [THIRD-PARTY-LICENSES.txt](THIRD-PARTY-LICENSES.txt), which
is shipped with every release. The modified SDL3 copy is marked as altered in
[DUSKLIGHT-PATCH.txt](extern/SDL3-uwp/DUSKLIGHT-PATCH.txt), as the zlib license requires.

## Credits and licenses

- **Dusklight** by [TwilitRealm](https://github.com/TwilitRealm/dusklight) and contributors, released
  under CC0 1.0 ([LICENSE.md](LICENSE.md)). The original README is kept as
  [README.dusklight.md](README.dusklight.md).
- The [TP decompilation](https://github.com/zeldaret/tp) team and the GC/Wii decompilation community
  (CC0 1.0).
- **Aurora** and **borealis** by Luke Street ([encounter](https://github.com/encounter)), MIT
  ([extern/aurora/LICENSE](extern/aurora/LICENSE), [extern/borealis/LICENSE](extern/borealis/LICENSE)).
- **worleydl** for the original [dusklight-uwp](https://github.com/worleydl/dusklight-uwp) and
  [uwp-dep](https://github.com/worleydl/uwp-dep), from which the XboxEmulationHub versions were forked.
- **XboxEmulationHub** for the [Dusklight UWP port](https://github.com/XboxEmulationHub/dusklight-uwp)
  (1.1.1, archived 2026-10-20), the aurora UWP patch,
  [uwp-dep](https://github.com/XboxEmulationHub/uwp-dep) (licenses in
  [extern/uwp-dep/lic](extern/uwp-dep/lic)) and [SDL3-uwp](https://github.com/XboxEmulationHub/SDL3-uwp).
- **SDL3** (zlib license, [extern/SDL3-uwp/LICENSE.txt](extern/SDL3-uwp/LICENSE.txt)). The copy in
  `extern/SDL3-uwp` is modified; see [DUSKLIGHT-PATCH.txt](extern/SDL3-uwp/DUSKLIGHT-PATCH.txt) and
  [sdl3-uwp-threadid.patch](platforms/uwp/patches/sdl3-uwp-threadid.patch).

### Trademarks

*The Legend of Zelda* and *Twilight Princess* are trademarks of Nintendo. Xbox is a trademark of
Microsoft. Windows and UWP are trademarks of Microsoft. All other names belong to their respective
owners. They are used here for identification only and imply no affiliation or endorsement.

<br/>
<div align="center">
    <a href="https://github.com/encounter/aurora">
        <img src="assets/aurora-powered.png" alt="Powered by Aurora" width="600">
    </a>
</div>
