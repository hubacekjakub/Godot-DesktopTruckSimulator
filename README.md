# Desktop Truck Simulator

A cozy, minimalist desktop companion built with Godot 4.6. A small truck drives across the bottom of your screen, turning your workspace into a living environment.

[![Itch.io](https://img.shields.io/badge/Itch.io-View%20on%20Itch-FA5C5C?style=flat&logo=itch.io)](https://hubacekjakub.itch.io/desktop-truck-simulator)
[![Latest Release](https://img.shields.io/badge/GitHub-Release-blue?logo=github)](https://github.com/hubacekjakub/Godot-DesktopTruckSimulator/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/hubacekjakub/Godot-QuickStart/blob/main/LICENSE)
[![Godot 4.6](https://img.shields.io/badge/Godot-4.6-blue)](https://godotengine.org/)


![Desktop Truck Simulator Banner](gifs/TruckBanner.gif)

## Features

- **Cozy Desktop Presence**: A non-intrusive truck passes by your work at random intervals.
- **Per-Pixel Transparency**: The truck is rendered in its own borderless, transparent window that sits on top of all other windows.
- **Global Edge Fading**: Smooth shader-based transitions as the truck enters and leaves the screen edges.
- **Lightweight**: Built using the `gl_compatibility` renderer for maximum compatibility and low resource usage.

## Showcase

| Truck in PowerPoint | Truck in Excel |
| :---: | :---: |
| ![Powerpoint](gifs/TruckPowerpoint.gif) | ![Excel](gifs/TruckExcel.gif) |

## Technical Details

### Architecture
- **Multi-Window System**: The main application window is hidden, while a secondary `Window` node handles the truck animation.
- **Transparency Workaround**: Implements a specific workaround for Godot bug #71642 to ensure OS-level transparency is correctly negotiated with the Windows DWM.
- **Shader-Based Fading**: Uses a custom `CanvasItem` shader to calculate global screen positions for pixel-perfect fading at monitor edges.
- **Sprite Animation**: High-quality pixel art with separate body and wheels, featuring procedural "bobbing" and dust particle effects.

### Requirements
- **OS**: Windows (tested on Windows 10/11)
- **Godot Version**: 4.6+
- **Renderer**: OpenGL (GL Compatibility mode) is required for per-pixel transparency.

## Development

### Setup
1. Clone the repository.
2. Open in Godot 4.6+.
3. Ensure the project is set to `GL Compatibility` mode in the renderer settings.

### Project Structure
- `levels/main.tscn`: The primary scene containing the window manager.
- `scripts/main.gd`: Logic for movement, window management, and transparency.
- `shaders/truck_fade.gdshader`: The global edge-fade implementation.
- `assets/`: Textures, fonts, and other resources.

### Troubleshooting

#### Missing Resources / "Failed Loading" Errors
If you see errors about missing `.ctex` files or failed loading of textures:
1.  **Git LFS**: This project uses Git LFS for binary assets (images, GIFs). Ensure you have [Git LFS](https://git-lfs.github.com/) installed and run:
    ```bash
    git lfs pull
    ```
2.  **Re-import**: Delete the `.godot` folder in the project root and reopen the project in Godot. This forces a clean re-import of all assets.

#### UID Warnings
If you see "invalid UID" warnings in the console, they can be safely ignored as Godot falls back to file paths. We've removed UIDs from main scenes to minimize these, but Godot may regenerate them locally.

## 📝 License

This project is licensed under the [MIT License](LICENSE).
You are free to use, modify, and distribute this template in your own projects.
