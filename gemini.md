# Desktop Truck Simulator - Workspace Setup

## Requirements
1. **Simple Truck Animation**: A truck appears every 10 seconds and moves across the bottom of the screen from left to right.
2. **Window Component**: The truck will be implemented using a Godot `Window` component. This allows it to act as an independent OS window on the desktop.
3. **Future Extensibility**: The architecture should support adding more windows in the future.
4. **Non-Interactive**: The truck must not be clickable or draggable by the user.

## Implementation Plan
1. **Project Settings Configuration**:
   - Ensure the main Godot window is completely invisible (transparent, borderless, mouse-passthrough).
   - Ensure `display/window/subwindows/embed_subwindows` is set to `false` so `Window` nodes spawn as separate OS windows instead of being contained in the main window.
   - Enable per-pixel transparency and transparent background.

2. **Main Scene (`Main.tscn`) & Script (`main.gd`)**:
   - The main scene will act as an invisible manager.
   - It will contain a `Timer` set to 10 seconds.
   - When the timer times out, it will instantiate a new truck window and add it to the scene tree.

3. **Truck Window Scene (`TruckWindow.tscn`) & Script (`truck_window.gd`)**:
   - The root node will be a `Window`.
   - The `Window` will be configured as borderless, transparent, always on top, and unresizable.
   - We will enable `mouse_passthrough` so clicks go right through it to the desktop behind it.
   - It will have a `Sprite2D` or `TextureRect` with the truck texture.
   - The script will get the current screen size, position the window at the bottom-left off-screen, and move it to the right every frame (`_process`).
   - Once it goes completely off-screen on the right, the window will `queue_free()` itself.

## Status
- [x] Initialize `gemini.md`
- [x] Update `project.godot` settings
- [x] Create `TruckWindow.tscn` and `truck_window.gd`
- [x] Update `Main.tscn` and `main.gd` to act as the manager
