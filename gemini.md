# Desktop Truck Simulator - Workspace Setup

## Requirements
1. **Truck Animation**: A transparent, borderless truck drives across the bottom of the screen, alternating direction with a random 5–15 second pause between passes.
2. **Main Window = Truck**: The truck is rendered directly in the main Godot window, which is sized to the sprite (384×384), borderless, transparent, and always-on-top. No subwindow needed.
3. **Non-Interactive**: The main window is unfocusable with `mouse_passthrough` enabled.
4. **Future Extensibility**: Additional animated windows can be spawned as child `Window` nodes (following the Geegaz/Multiple-Windows-tutorial pattern).

## Architecture
- **`levels/main.tscn`** — Root `Node2D` with a child `Truck` node (Sprite2D body, Sprite2D wheels, GPUParticles2D dust emitters) and a `WaitTimer`.
- **`scripts/main.gd`** — Configures the main window as the truck overlay, applies the Godot #71642 transparency workaround, queries `screen_get_usable_rect()` using `current_screen` for multi-monitor support, and runs the movement/direction logic in `_process()`.
- **`shaders/truck_fade.gdshader`** — Per-pixel alpha fade at screen edges using absolute screen coordinates.
- **Renderer**: `gl_compatibility` (OpenGL). Required because Vulkan (`forward_plus`) fails to negotiate per-pixel transparency with Windows DWM on certain hardware.

## Key Design Decisions
- **Main window IS the truck** (not a subwindow). This follows the Geegaz/Multiple-Windows-tutorial pattern. Benefits: one fewer viewport (performance), absolute screen coordinates (multi-monitor), no hidden-window hack.
- **Reference project**: https://github.com/geegaz/Multiple-Windows-tutorial.git (cloned at `D:\Projects\Godot-MutliWindowTutorial`)

## Key Workarounds
- **Godot Bug #71642**: Windows ignores transparency flags set before the native window handle (HWND) is fully created. Fix: set `transparent = false` initially, wait 2 frames, then toggle to `true`.
- **Renderer**: Must use `gl_compatibility` — `forward_plus` (Vulkan) produces a black background on Windows.

## Status
- [x] Initialize `gemini.md`
- [x] Configure `project.godot` (OpenGL, transparency, borderless, non-embedded sub-windows)
- [x] Create `main.tscn` with truck sprites and particles directly in main viewport
- [x] Implement `main.gd` with main-window-as-truck pattern
- [x] Direction-switching with random 5–15s delay between passes
- [x] Refactor from subwindow to main-window architecture (feature/main-window-truck)
