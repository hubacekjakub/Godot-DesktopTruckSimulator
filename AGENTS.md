# Desktop Truck Simulator - AI Assistant Guidelines

## Build & Test Commands
*   **Headless syntax verify**: `godot.exe --headless --path . -e -q`
*   **Run Game project**: `godot_console.exe --path .`

## Code Style & Conventions
*   **Naming Conventions**:
    *   Use `snake_case` for variables, functions, and file/folder names.
    *   Use `PascalCase` for classes and enums.
    *   Use `SCREAMING_SNAKE_CASE` for constants.
*   **GDScript Best Practices**:
    *   Use `@onready` for node references accessed in `_ready()`.
    *   Prefer explicit typing when beneficial (e.g., `var player: Player`).
    *   **Autoload Types Warning**: Avoid using custom `class_name` types inside Autoloads statically (it causes Godot class registry parser issues on boot). Use base types (e.g. `Window`, `Node2D`) and dynamic checks (`has_method()`, `is_instance_valid()`).
*   **Event-Driven Communication**:
    *   All cross-scene or cross-autoload communications MUST route through `SignalBus` (`autoloads/signal_bus.gd`) to keep scripts decoupled. Do not couple systems directly.

## Project Structure
*   **Autoloads (Singletons)**:
    *   `SignalBus` (`autoloads/signal_bus.gd`): Core global Event Bus.
    *   `ConfigManager` (`autoloads/config_manager.gd`): Loads settings from `settings.cfg` next to the EXE.
    *   `WindowManager` (`autoloads/window_manager.gd`): Spawns OS Windows born hidden + off-screen (see Window Spawn Pattern) and is the single source of screen bounds (`get_usable_rect()`).
    *   `Global` (`autoloads/global.gd`): Coordinates wait timers, driving passes, and direction toggles.
    *   `DebugManager` (`autoloads/debug_manager.gd`): Spawns debug control panels and tracking portals.
*   **Scenes (`levels/` and `scenes/`)**:
    *   Levels and root scenes go in `levels/` (e.g., `levels/main.tscn` / `levels/main.gd`).
    *   Reusable components go in `scenes/` (e.g., `scenes/truck/` for truck nodes, `scenes/debug/` for debug nodes).
*   **Assets**: Keep raw art/audio under `assets/` and commit import sidecars (`*.import`).
*   **Deprecated**: Move unused content to `deprecated/` instead of deleting immediately.

## Key Design Decisions & Workarounds
*   **Renderer**: MUST use `gl_compatibility` (OpenGL). Vulkan (`forward_plus`) fails to negotiate transparency with Windows DWM on certain systems.
*   **Window Spawn Pattern (anti-flash)**: Every window except the engine launcher is created via `WindowManager.spawn_window()`, which makes it born hidden + off-screen + `WINDOW_INITIAL_POSITION_ABSOLUTE` (at `WindowManager.OFFSCREEN`) so the OS never draws it at a default spot. There is **no central reveal** — each window positions and `show()`s itself at the end of its own `_ready()`. The launcher (root window) is instead kept off-screen via `project.godot` `initial_position`. When adding a window, route it through `spawn_window` and finish its `_ready()` with position + `show()`.
*   **Persistent Window Reuse**: `TruckWindow` is created once and hidden/repositioned on each pass, avoiding OS-level creation lag.
*   **Godot Bug #71642 Workaround**: Windows ignores transparency flags set before native window handles are fully created.
    *   *Workaround*: Start window off-screen at `WindowManager.OFFSCREEN` with `transparent = false`. Wait 2 frames via `await get_tree().process_frame`, toggle to `true`, and set `DisplayServer` transparency flags before moving on-screen using `_is_initialized` guard.

## Repo Hygiene & Constraints
*   **No Git Commits**: The AI must NOT perform git commits. Let the user run git commits manually.
*   **Machine-Specific Paths**: Never hardcode absolute paths. Always use repo-relative paths (`res://...`).
*   Ignore the `.godot/` folder and other generated artifacts.
