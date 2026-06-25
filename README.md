# Desktop Truck Simulator

A small truck that drives across the bottom of your screen. Built with Godot 4.6 as a playground for figuring out how transparent OS windows, multi-monitor traversal, and per-pixel transparency actually work in Godot.

[![Itch.io](https://img.shields.io/badge/Itch.io-View%20on%20Itch-FA5C5C?style=flat&logo=itch.io)](https://hubacekjakub.itch.io/desktop-truck-simulator)
[![Latest Release](https://img.shields.io/badge/GitHub-Release-blue?logo=github)](https://github.com/hubacekjakub/Godot-DesktopTruckSimulator/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/hubacekjakub/Godot-QuickStart/blob/main/LICENSE)
[![Godot 4.6](https://img.shields.io/badge/Godot-4.6-blue)](https://godotengine.org/)

![Desktop Truck Simulator Banner](gifs/TruckBanner.gif)

## What it does

- Truck drives across your desktop in a transparent borderless window, on top of everything else
- Shader-based edge fading as it enters and leaves screen edges
- Traverses multiple monitors in sequence
- System tray icon to toggle visibility, open the garage, or quit
- Garage window to pick truck color and cabin style — saved between sessions
- `settings.cfg` next to the exe for tweaking speed, timing, scale, etc.

## Visuals

| Truck in PowerPoint | Truck in Excel |
| :---: | :---: |
| ![Powerpoint](gifs/TruckPowerpoint.gif) | ![Excel](gifs/TruckExcel.gif) |

| System Tray | Garage |
| :---: | :---: |
| *(coming soon)* | *(coming soon)* |

## Architecture

Everything talks through `SignalBus` — no direct autoload-to-autoload calls. The main window is hidden; the truck lives in its own secondary `Window` node that gets reused across passes rather than destroyed and recreated.

Autoload boot order matters here:

```
SignalBus → ConfigManager → WindowManager → Player → Global → DebugManager → Customization → SystemTray → SaveManager
```

**Autoloads at a glance:**
- `SignalBus` — all cross-system signals live here, nothing else
- `ConfigManager` — reads `settings.cfg`, copies it next to the exe on first run
- `WindowManager` — owns the truck window and manages usable screen rect
- `Player` — movement logic, pass timing, multi-monitor traversal
- `Global` — thin relay; fires the initial stop timer, delegates `get_truck_rect()`
- `DebugManager` — spawns the debug panel and portal (debug builds only)
- `Customization` — color/cabin catalogs, garage window lifecycle, save/load integration
- `SystemTray` — tray icon and popup menu, communicates only through SignalBus
- `SaveManager` — loads `user://savegame.json` on boot, saves on confirm

## Interesting bits

**Transparent window timing** — there's a workaround for [Godot bug #71642](https://github.com/godotengine/godot/issues/71642): windows spawn off-screen with transparency disabled, wait 2 frames, then enable transparency before moving on-screen. Without this the window flickers opaque on first appearance.

**Edge fade shader** — a `CanvasItem` shader calculates the truck's global screen position and fades pixels near the monitor edges. Works across monitors because it operates in screen space.

**Garage timing** — the truck stops for customization by emitting `truck_movement_stop_triggered`. The garage opens on `truck_movement_stop_finished` (after the stop animation completes). This keeps the stop animation and the garage open/close fully decoupled.

**Save format** — `user://savegame.json` resolves to `%APPDATA%/Godot/app_userdata/DesktopTruckSimulator/savegame.json`. The `unlocked_colors` array accepts any hex string, so players can hand-edit it to add custom colors.

## Project structure

```
autoloads/          # Singletons (see boot order above)
levels/             # Root scene — minimizes the launcher window; real app lives in autoloads
scenes/             # Reusable components (truck/, garage/, debug/)
shaders/            # Edge-fade shader (truck_fade.gdshader)
resources/          # TruckBody resources, fonts
assets/             # Textures and other binary assets (Git LFS)
settings.cfg        # Shipped next to the exe; recreated from defaults if deleted
```

## Setup

1. Clone (requires [Git LFS](https://git-lfs.github.com/) for binary assets — run `git lfs pull` after cloning)
2. Open in Godot 4.6+
3. Renderer must be `GL Compatibility` — per-pixel transparency doesn't work on Vulkan

### Troubleshooting

**Missing `.ctex` files / failed loading** — you're probably missing LFS files. Run `git lfs pull`.

**"Invalid UID" warnings** — safe to ignore, Godot falls back to file paths automatically.

## License

[MIT](LICENSE)
