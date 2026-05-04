# Desktop Truck Simulator - Workspace Setup

## Requirements
1. **Truck Animation**: A transparent, borderless truck drives across the bottom of the screen, alternating direction with a random 5–15 second pause between passes.
2. **Window Component**: The truck is rendered inside a Godot `Window` node configured as a separate OS window (`embed_subwindows = false`).
3. **Non-Interactive**: The truck window is unfocusable and the main app window has `mouse_passthrough` enabled.
4. **Future Extensibility**: The architecture can support adding more animated windows.

## Architecture
- **`Main.tscn`** — Contains an invisible `Node2D` manager and a child `Window` node with a `Sprite2D` truck.
- **`main.gd`** — Hides the main Godot window off-screen, applies the Godot #71642 transparency workaround to the sub-window, and runs the movement/direction logic in `_process()`.
- **Renderer**: `gl_compatibility` (OpenGL). Required because Vulkan (`forward_plus`) fails to negotiate per-pixel transparency with Windows DWM on certain hardware.

## Key Workarounds
- **Godot Bug #71642**: Windows ignores transparency flags set before the native window handle (HWND) is fully created. Fix: set `transparent = false` initially, wait 2 frames, then toggle to `true`.
- **Renderer**: Must use `gl_compatibility` — `forward_plus` (Vulkan) produces a black background on Windows.

## Status
- [x] Initialize `gemini.md`
- [x] Configure `project.godot` (OpenGL, transparency, borderless, non-embedded sub-windows)
- [x] Create `Main.tscn` with transparent `Window` and `Sprite2D` truck
- [x] Implement `main.gd` with transparency workaround and movement logic
- [x] Direction-switching with random 5–15s delay between passes
