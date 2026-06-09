# Desktop Truck Simulator

A desktop companion built with Godot 4.6. A small truck drives across the bottom of your screen in its own transparent window. This is a hobby experiment for learning how OS windows, subwindows, and per-pixel transparency work in Godot.

[![Itch.io](https://img.shields.io/badge/Itch.io-View%20on%20Itch-FA5C5C?style=flat&logo=itch.io)](https://hubacekjakub.itch.io/desktop-truck-simulator)
[![Latest Release](https://img.shields.io/badge/GitHub-Release-blue?logo=github)](https://github.com/hubacekjakub/Godot-DesktopTruckSimulator/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/hubacekjakub/Godot-QuickStart/blob/main/LICENSE)
[![Godot 4.6](https://img.shields.io/badge/Godot-4.6-blue)](https://godotengine.org/)

![Desktop Truck Simulator Banner](gifs/TruckBanner.gif)

## Features

- **Transparent Window Rendering**: The truck is rendered in its own borderless, transparent window that sits on top of all other windows using per-pixel transparency.
- **Edge Fading**: Shader-based transitions as the truck enters and leaves the screen edges.
- **Truck Customization**: A garage window allows changing the truck's appearance via shader-based color adjustments.
- **Configurable**: A `settings.cfg` file ships alongside the executable, allowing players to adjust basic settings like speed and timing.
- **Persistent Window Reuse**: The truck window is created once at startup and hidden/repositioned between passes, avoiding OS-level window creation lag.
- **Lightweight**: Built using the `gl_compatibility` (OpenGL) renderer for maximum compatibility and low resource usage.

## Showcase

| Truck in PowerPoint | Truck in Excel |
| :---: | :---: |
| ![Powerpoint](gifs/TruckPowerpoint.gif) | ![Excel](gifs/TruckExcel.gif) |

## Technical Details

### Architecture

- **Multi-Window System**: The main application window is hidden. A secondary `Window` node handles the truck rendering and movement.
- **Event-Driven Communication**: All cross-scene communication routes through a `SignalBus` autoload to keep systems decoupled.
- **Autoload Singletons**: Core systems (`SignalBus`, `ConfigManager`, `WindowManager`, `Global`, `Customization`) are registered as autoloads and coordinate through signals.
- **Transparency Workaround**: Implements a workaround for [Godot bug #71642](https://github.com/godotengine/godot/issues/71642) — windows start off-screen with transparency disabled, wait 2 frames, then toggle transparency flags before moving on-screen.
- **Shader-Based Fading**: A custom `CanvasItem` shader calculates global screen positions for pixel-perfect fading at monitor edges.

### Configuration

A `settings.cfg` file is placed next to the executable. Players can edit it to adjust basic settings. If the file is deleted, the application recreates it from defaults on the next launch.

### Requirements

- **OS**: Windows 10/11, Linux (x86_64)
- **Renderer**: OpenGL (GL Compatibility mode) is required for per-pixel transparency.

## Development

### Setup
1. Clone the repository (requires [Git LFS](https://git-lfs.github.com/) for binary assets).
2. Open in Godot 4.6+.
3. Ensure the project is set to `GL Compatibility` renderer.

### Project Structure
- `levels/` — Root scene (`main.tscn` / `main.gd`).
- `autoloads/` — Singletons: `SignalBus`, `ConfigManager`, `WindowManager`, `Global`, `Customization`, `DebugManager`.
- `scenes/truck/` — Truck window and entity (movement, animation, particles).
- `scenes/garage/` — Garage customization window.
- `shaders/` — Edge-fade shader (`truck_fade.gdshader`).
- `assets/` — Textures, fonts, and other resources.

### Troubleshooting

#### Missing Resources / "Failed Loading" Errors
If you see errors about missing `.ctex` files or failed loading of textures:
1.  **Git LFS**: This project uses Git LFS for binary assets (images, GIFs). Ensure you have [Git LFS](https://git-lfs.github.com/) installed and run:
    ```bash
    git lfs pull
    ```
2.  **Re-import**: Delete the `.godot` folder in the project root and reopen the project in Godot. This forces a clean re-import of all assets.

#### UID Warnings
If you see "invalid UID" warnings in the console, they can be safely ignored as Godot falls back to file paths.

## License

This project is licensed under the [MIT License](LICENSE).

