# Generalized Window Flash Mitigation Design

## Goal
Eliminate the visual "flash" that occurs when Godot windows (Launcher, Truck, Debug Panels) are initially created by the OS before their scripts can hide or reposition them. The solution must apply globally to all windows in the project.

## Architecture & Approach
We will use a hybrid approach that intercepts dynamic window creation programmatically while configuring the engine-spawned launcher window statically.

### 1. Static Configuration (Launcher Window)
The engine creates the primary window before any user scripts execute. To prevent it from flashing:
*   Update `project.godot`:
    *   Set `display/window/size/initial_position_type` to Absolute (0).
    *   Set `display/window/size/initial_position` to `(-10000, -10000)`.
    *   Set `display/window/mode` to Minimized.

### 2. Dynamic Interception (`WindowManager`)
All dynamically spawned windows (Truck, Garage, Debug) must be routed through `WindowManager.spawn_window()`.
*   Update `WindowManager.spawn_window()` in `autoloads/window_manager.gd`.
*   Before calling `get_tree().root.add_child.call_deferred(win_node)`, explicitly override the window's starting state:
    *   Force `win_node.position = Vector2i(-10000, -10000)`.
    *   Force `win_node.visible = false` (or `win_node.hide()`).
*   This ensures that the moment the OS draws the window (triggered by `add_child`), it is already off-screen and invisible, overriding any defaults set in the `.tscn` files.

### 3. Cleanup of Existing Scenes
While `WindowManager` will intercept the spawn, it is best practice to clean up existing scenes to avoid conflicting configurations.
*   Update `scenes/truck/truck_window.tscn`: Change `initial_position` from `Center of Primary Screen` (1) to `Absolute` (0).
*   Ensure any hardcoded `show()` calls in the `_ready()` functions of windows (like `truck_window.gd` or `debug_panel.gd`) are removed or delayed until after transparency logic is complete, relying instead on the window logic to show itself when ready.

## Testing Strategy
1.  Run the application from a cold start. Verify the screen remains completely clear until the truck actively drives across.
2.  Open the debug panel (if in a debug build). Verify it appears without flashing a default gray/white OS frame first.
3.  Open the garage. Verify it transitions smoothly without flashing.
