# Desktop Truck Simulator — AI Agent Guidelines

A Godot 4.6 (GDScript, `gl_compatibility`/OpenGL renderer) desktop companion: a truck drives across the bottom of the screen inside its own borderless, per-pixel-transparent OS window.

## Build & Test Commands

```powershell
# Verify all scripts parse (headless, exits after import) — run after every edit
godot.exe --headless --path . -e -q

# Run the game (console build keeps stdout/stderr attached)
godot_console.exe --path .

# Export a release build
godot_console.exe --path . --export-release "Windows Desktop" .
```

There is **no automated test suite**. `-e -q` headless import is the only syntax/parse check. Verifying runtime behavior (window flashes, transparency, movement) requires running the GUI build — ask the user to run it; an agent can't reliably observe a GUI window.

---

## Hard Constraints

- **Renderer must stay `gl_compatibility`.** Vulkan (`forward_plus`) fails to negotiate per-pixel transparency with the Windows DWM. Set in `project.godot` and `rendering/viewport/transparent_background=true`.
- **Do not use `class_name` types statically inside autoloads.** It breaks Godot's class registry on boot. In autoloads, hold windows as base `Window`/`Node` and use `has_method()` / `is_instance_valid()` dynamic checks (see how `player.gd` holds truck windows as `Window` and calls methods via `has_method()`).
- **Do not `git commit`** — the user commits manually.

---

## Code Style & Conventions

- `snake_case` for variables, functions, and file/folder names.
- `PascalCase` for classes and enums.
- `SCREAMING_SNAKE_CASE` for constants.
- Use `@onready` for node references accessed in `_ready()`.
- Prefer explicit typing where beneficial (`var rect: Rect2i`).
- All cross-scene / cross-autoload communication routes through `SignalBus` — never direct calls between autoloads or scenes.

---

## Project Structure

```
autoloads/          # Singletons (boot order: SignalBus → ConfigManager → WindowManager → Player → Global → DebugManager → Customization)
levels/             # Root scene (levels/main.tscn / main.gd — minimizes the launcher window; real app lives in autoloads)
scenes/             # Reusable components (truck/, garage/, debug/)
shaders/            # GLSL shaders
assets/             # Raw art/audio (binary assets in Git LFS)
docs/superpowers/   # specs/ and plans/ for design docs and implementation plans
settings.cfg        # Config file (copied next to EXE on first run by ConfigManager)
```

**Autoloads:**
- `SignalBus` — signal-only event bus; all cross-system communication goes here.
- `ConfigManager` — loads `settings.cfg`; use `get_setting(section, key, default)` everywhere.
- `WindowManager` — spawns OS windows born hidden+off-screen; single source of screen bounds.
- `Player` — owns all truck movement state and the pass lifecycle.
- `Global` — thin relay: fires initial stop timer, re-emits resume on customization finish, delegates `get_truck_rect()` to Player.
- `DebugManager` — spawns debug panel and portal (debug builds only).
- `Customization` — spawns and manages the garage window.

---

## Architecture

### Window Spawning & the Startup-Flash Pattern

Every OS window except the engine's launcher is created through `WindowManager.spawn_window(path)`. To stop the OS from drawing a window at a default location for a frame, `spawn_window` makes each window **born hidden + off-screen + absolute** before a deferred `add_child`: sets `initial_position = WINDOW_INITIAL_POSITION_ABSOLUTE`, `visible = false`, `position = WindowManager.OFFSCREEN`. `ABSOLUTE` is required — without it the OS ignores the position and centers the window.

**No central reveal, by design.** Each window positions and `show()`s itself at the end of its own `_ready()`. `WindowManager` owns only the mechanism; placement policy lives in each window. A window that forgets to `show()` stays silently invisible — there is no safety net.

The launcher (root) window can't go through `spawn_window`, so it's kept off-screen via `project.godot` (`initial_position=Vector2i(-10000,-10000)`); `main.gd` then minimizes it.

### The Pass Lifecycle (Player is the State Machine)

One `TruckWindow` per monitor is spawned **once** at startup and reused — never recreated per pass.

1. `Player._ready()` → `_setup_windows()` spawns one `TruckWindow` per monitor, then starts the first pass after a 1 s delay.
2. `start_next_pass()` picks a random speed, sets `_logical_x` just off the leading screen edge, calls `initialize_truck(dir)` on each window.
3. `Player._process()` advances `_logical_x`; each `TruckWindow._process()` reads it and emits `border_reached` when the truck fully exits that monitor.
4. `_check_pass_completion()` waits until all windows emitted `border_reached`, hides all windows, flips `_direction`, starts the wait timer, emits `SignalBus.truck_pass_completed`.

### Coordinate Model

`Player` owns `_logical_x`: the truck's absolute screen-space X, which can be negative or beyond screen edges. Each `TruckWindow._process()` converts it for its own monitor:
- Window X is **clamped** to `_monitor_rect` (`set_monitor_rect()` stores this).
- Overflow (`offset_x = roundi(logical_x) - clamped_x`) goes into the entity's local X, so the truck visually slides past the edge while the window stays clamped.
- All positions use `roundi()`; only assign `position` when it actually changes — avoids sub-pixel jitter and DWM compositor thrash. Preserve both when editing movement code.

`WindowManager` is the single source of screen bounds:
- `get_usable_rect()` — primary screen's rect.
- `get_ordered_screen_rects(multimonitor)` — all screens sorted left-to-right (or just the primary).
- `get_ordered_screen_data(multimonitor)` — same sort, but returns `Array` of `[Rect2i, int]` pairs preserving the DisplayServer screen index alongside each rect. **Prefer this over `get_ordered_screen_rects` when the caller needs the screen index** (e.g. Player's `_setup_windows`), so no secondary DisplayServer loop is needed.

`Player` uses `_window_monitors: Dictionary` (Window → Rect2i) to track which rect belongs to which window.

### Transparency Workaround (Godot Bug #71642)

Windows ignores transparency flags set before the native window handle exists. `truck_window.gd._ready()` is the canonical sequence and **must be preserved**:
1. Set `position = WindowManager.OFFSCREEN`, `transparent = false`.
2. `show()`.
3. `await get_tree().process_frame` × 2.
4. `DisplayServer.window_set_flag(WINDOW_FLAG_TRANSPARENT, true, get_window_id())`.
5. `transparent = true`, `transparent_bg = true`.

After init, emit `SignalBus.truck_spawned` and call `hide_window()`. The `_revealed` guard prevents `_process` from running before setup finishes.

### Two-Phase Movement Handshake

Stop/resume is a tween owned by `Player` with begin/end signal pairs:
- `truck_movement_stop_triggered` → Player tweens `_speed_multiplier` to 0 → emits `truck_movement_stop_finished` (Customization opens the garage here).
- `truck_movement_resume_triggered` → tweens back to 1.0 → `truck_movement_resume_finished`.
- `customization_finished` → Global re-emits resume.
- Edge case: if the pass completes during the 2.5 s stop tween, Player cancels the wait timer and starts a fresh pass on resume to avoid deadlock.

Match each `_triggered` to its `_finished` when reading movement code.

### Multi-Monitor Traversal

Enabled by `multimonitor = true` in `settings.cfg` (`ConfigManager.is_multimonitor()`). `Player._setup_windows()` calls `WindowManager.get_ordered_screen_data(true)` to get `[Rect2i, screen_index]` pairs sorted left-to-right, spawns one `TruckWindow` per monitor, and calls `set_monitor_rect(rect, screen_index)` on each. All windows share the same `_logical_x`; each clamps to its own monitor, so the truck splits across adjacent screens during boundary crossings. The pass completes only when **every** window has emitted `border_reached` (tracked via `_crossed_windows`). `Player.get_truck_rect()` returns the rect of the window whose monitor actually contains `_logical_x`.

### Display Scale Support

Each `TruckWindow` detects the OS display scale of its assigned monitor and resizes itself proportionally so the truck appears at the same physical size on all monitors (including high-DPI screens).

**How it works:**
- `WindowManager.get_ordered_screen_data()` preserves the DisplayServer screen index alongside each rect. Player passes this index to `set_monitor_rect(rect, screen_index)`, which stores both as `_monitor_rect` and `_screen_index` — no secondary DisplayServer loop in the window.
- After the two-frame transparency wait in `_ready()`, `_detect_monitor_scale()` reads `DisplayServer.screen_get_scale(_screen_index)` and multiplies by `truck_scale_multiplier` from config (default 1.0, manual override knob for monitors that report unexpected values).
- If `_scale_factor != 1.0`, `_apply_display_scale()` resizes the window and calls `_entity.apply_display_scale(s)` on the entity (scales sprites and re-centers).
- `_get_target_y()` multiplies `vertical_offset` by `_scale_factor` so the parking position stays proportional.
- **Multi-monitor boundary crossing:** two windows at different scales will show different-sized truck halves during the crossing. This is accepted — seamless cross-boundary scaling would require per-frame window resizing (compositor thrash).

Config key: `[TruckSettings] truck_scale_multiplier = 1.0`.

### Customization / Garage

`Customization` (autoload) spawns `scenes/garage/garage_window.tscn` via `WindowManager.spawn_window` when the truck has stopped. The garage positions **itself** above the truck in its own `_ready()` (`Global.get_truck_rect()` → `Player.get_truck_rect()` + `position_above_rect()`, centered fallback if no truck rect). Color/cabin/wheel changes are broadcast as `customization_*` signals; `TruckEntity` applies them as shader parameters.

### Per-Instance Shader Material

`TruckEntity._ready()` **duplicates** the `ShaderMaterial` from `_truck_body` and assigns the duplicate to `_truck_body` and all three wheel sprites. Required for multi-monitor: the material is a shared sub-resource in `truck_entity.tscn`, so without duplication all windows would write into the **same** material. Each entity instance must own its material.

### Edge-Fade Shader

`shaders/truck_fade.gdshader` (a `CanvasItem` shader on the truck body) fades the truck at monitor edges. It needs global screen coordinates. Uniforms are split into two calls:

- **Once, in `_ready()`** — `truck_entity.init_shader_constants(window_width, screen_left, screen_right)` sets the four uniforms that never change: `window_width`, `screen_left`, `screen_right`, `fade_margin` (from config, scaled by `_display_scale`).
- **Per-frame, in `_process()`** — `truck_entity.update_shader_window_x(clamped_x)` sets only `window_x`. This must remain per-frame because `SCREEN_UV` in the shader is viewport-relative (0–1 within the window), not OS-desktop-relative, so there is no way to eliminate this CPU write.

With multiple windows, each `TruckWindow` feeds its own monitor's bounds — correct only because each entity owns a duplicated material.

### Config

`ConfigManager._ready()` copies `res://settings.cfg` to the executable's directory on first run (falls back to `res://` in the editor). Read values only through `ConfigManager.get_setting(section, key, default)` — defaults at every call site keep settings keys loosely coupled.

Current sections:
- `[TruckSettings]` — `min_speed`, `max_speed`, `min_wait_time`, `max_wait_time`, `vertical_offset`, `customization`, `multimonitor`, `truck_scale_multiplier`
- `[ShaderSettings]` — `fade_margin`

### Debug Tooling (Debug Builds Only)

`DebugManager` early-returns unless `OS.is_debug_build()`. Spawns a control panel (`scenes/debug/debug_panel.tscn`) and an optional "portal" window that mirrors the truck's `world_2d` into a second viewport for inspecting collision/debug shapes (`canvas_cull_mask` layer 2). Both self-position in `_ready()`. The portal links to the truck's `world_2d` via a `CONNECT_ONE_SHOT` signal so the link always happens after `_ready()` regardless of call order. In multi-monitor mode the portal attaches only to the **first** truck window's `world_2d`. Neither ships in release builds.

---

## Assets & Repo Notes

- Binary assets use **Git LFS** — run `git lfs pull` after cloning. Missing `.ctex` / "failed loading" errors usually mean LFS wasn't pulled; delete `.godot/` to force a clean re-import.
- Design specs live under `docs/superpowers/specs/`; implementation plans under `docs/superpowers/plans/`.
- Never hardcode absolute paths. Always use `res://`-relative paths.
- Ignore `.godot/` and other generated artifacts.
