# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A Godot 4.6 (GDScript, `gl_compatibility`/OpenGL renderer) desktop companion: a truck drives across the bottom of the screen inside its own borderless, per-pixel-transparent OS window.

See `AGENTS.md` for the full code-style/conventions guide. The points below are the architecture that isn't obvious from any single file.

## Commands (PowerShell)

```powershell
# Verify all scripts parse (headless, exits after import) — use after edits
godot.exe --headless --path . -e -q

# Run the game (console build keeps stdout/stderr attached)
godot_console.exe --path .

# Export a release build
godot_console.exe --path . --export-release "Windows Desktop" .
```

There is **no automated test suite**; `-e -q` headless import is the only syntax/parse check. Verifying runtime behavior (window flashes, transparency, movement) requires running the GUI build — ask the user to run it; the agent can't reliably observe a GUI window.

## Hard constraints

- **Renderer must stay `gl_compatibility`.** Vulkan (`forward_plus`) fails to negotiate per-pixel transparency with the Windows DWM. Set in `project.godot` and `rendering/viewport/transparent_background=true`.
- **Do not use `class_name` types statically inside autoloads.** It breaks Godot's class registry on boot. In autoloads, hold windows as base `Window`/`Node` and use `has_method()` / `is_instance_valid()` dynamic checks (see how `player.gd` holds truck windows as `Window` and calls methods via `has_method()`).
- **Do not `git commit`** — the user commits manually.

## Architecture

### Autoloads coordinate everything through SignalBus
Cross-system communication is **never** a direct call between scenes/autoloads — it routes through `SignalBus` (`autoloads/signal_bus.gd`), a signal-only Node. Autoload boot order (from `project.godot`): `SignalBus`, `ConfigManager`, `WindowManager`, `Player`, `Global`, `DebugManager`, `Customization`. The root scene `levels/main.tscn` does almost nothing — `main.gd` just shrinks/minimizes the engine's launcher window off-screen; the real app lives in the autoloads.

### Window spawning & the startup-flash pattern
Every OS window except the engine's launcher is created through `WindowManager.spawn_window(path)`. To stop the OS from drawing a window at a default location for a frame (the "flash"), `spawn_window` makes each window **born hidden + off-screen + absolute** *before* a deferred `add_child`: it sets `initial_position = WINDOW_INITIAL_POSITION_ABSOLUTE`, `visible = false`, and `position = WindowManager.OFFSCREEN`. `ABSOLUTE` is **required** — otherwise the OS ignores the position and centers the window regardless.

There is **no central reveal, by design.** Each window positions and `show()`s **itself** at the end of its own `_ready()` (truck, garage, debug panel, debug portal all do this) — `WindowManager` owns only the mechanism, placement policy lives in each window. The trade-off: a spawned window that forgets to `show()` itself stays silently invisible; there is no safety net. When adding a new window, route it through `spawn_window` and have its `_ready()` finish with position + `show()`.

The engine's launcher (root) window can't go through `spawn_window`, so it's kept off-screen via `project.godot` (`window/size/initial_position_type=0`, `initial_position=Vector2i(-10000,-10000)`); `main.gd` then minimizes it.

### The pass lifecycle (Player is the state machine)
One truck `Window` per monitor is spawned **once** at startup and reused — never recreated per pass (avoids OS window-creation lag). `Player` (`autoloads/player.gd`) owns all movement state. The loop:

1. `Player._ready()` → calls `_setup_windows()` which spawns one `TruckWindow` per monitor (single window when `multimonitor = false`), then starts the first pass after a 1s delay.
2. `start_next_pass()` reads random speed from config, sets `_logical_x` just off the leading edge, calls `initialize_truck(dir)` on each window → each `TruckWindow` calls `_entity.reset_visual(dir)`.
3. `Player._physics_process()` advances `_logical_x`; each `TruckWindow._process()` reads it and emits `border_reached` when the truck fully exits that monitor.
4. `_check_pass_completion()` waits until all windows have emitted `border_reached`, then hides all windows, flips `_direction`, starts the wait timer, and emits `SignalBus.truck_pass_completed`.

`Global` (`autoloads/global.gd`) is now a thin relay: it fires the initial customization stop timer, re-emits `truck_movement_resume_triggered` on `customization_finished`, and delegates `get_truck_rect()` to `Player.get_truck_rect()`. It no longer owns movement or spawns windows.

### Coordinate model (the non-obvious part — read these together)
`Player` owns `_logical_x`: the truck's position in absolute screen-space pixels, which can be negative or beyond the screen edge. Each `TruckWindow._process()` converts that into an OS window position for **its own monitor**:
- The window's X is **clamped** to its `_monitor_rect` (set by `Player._setup_windows()` via `set_monitor_rect()`).
- The overflow (`offset_x = roundi(logical_x) - clamped_x`) is pushed into the *entity's* local position, so the truck visually slides past the screen edge while the window itself stays clamped inside the monitor.
- All positions use `roundi()` and only assign `position` when it actually changes — this avoids sub-pixel jitter and DWM compositor thrash. Preserve both behaviors when editing movement code.

`WindowManager` is the single source of screen bounds: `get_usable_rect()` returns the primary screen's rect; `get_ordered_screen_rects(is_multimonitor)` returns all screens sorted left-to-right (or just the primary if `is_multimonitor` is false). `Player` uses `_window_monitors: Dictionary` (Window → Rect2i) to track which rect belongs to which window.

### Transparency workaround (Godot bug #71642)
The truck is the one window whose self-reveal is elaborate — it's the most complex instance of the spawn pattern above. Windows ignores transparency flags set before the native window handle exists, so `truck_window.gd._ready()` is the canonical sequence and **must be preserved**: position at `WindowManager.OFFSCREEN` with `transparent = false`, `show()`, `await get_tree().process_frame` twice, then set `DisplayServer.window_set_flag(WINDOW_FLAG_TRANSPARENT, …)` and `transparent = true`. After init it emits `SignalBus.truck_spawned` and hides until the first pass. An `_is_initialized` guard prevents `_process` from running mid-setup. (Unlike the simple windows, the truck doesn't show itself at `_ready` end — it stays hidden until `initialize_truck()` drives a pass.)

### Two-phase movement handshake
Stop/resume is not instantaneous — it's a tween owned by `Player` with a begin/end signal pair:
- `truck_movement_stop_triggered` → `Player` tweens `_speed_multiplier` to 0 → on completion emits `truck_movement_stop_finished` (which `Customization` listens to, to open the garage).
- `truck_movement_resume_triggered` → tweens back to full → `truck_movement_resume_finished`.
- `customization_finished` → `Global` re-emits resume. When reading movement-related code, match each `_triggered` to its `_finished`.
- Edge case: if the pass completes during the 2.5 s stop tween, `Player` cancels the wait timer and starts a fresh pass on resume to avoid a deadlock.

### Multi-monitor traversal
Enabled by `multimonitor = true` in `settings.cfg` (controlled by `ConfigManager.is_multimonitor()`). `Player._setup_windows()` calls `WindowManager.get_ordered_screen_rects(true)` to get all screens sorted left-to-right, spawns one `TruckWindow` per monitor, and assigns each its `_monitor_rect`. All windows share the same `_logical_x`; each clamps independently to its monitor, so the truck appears simultaneously split across adjacent screens during a boundary crossing. The pass completes only when **every** window has emitted `border_reached` (tracked via `_crossed_windows`). `Player.get_truck_rect()` returns the rect of the window whose monitor actually contains `_logical_x`, which the garage uses to open above the right screen.

### Customization / garage
`Customization` (autoload) spawns `scenes/garage/garage_window.tscn` via `WindowManager.spawn_window` when the truck has stopped; the garage then positions **itself** above the truck in its own `_ready()` (`Global.get_truck_rect()` → `Player.get_truck_rect()` + `position_above_rect()`, with a centered fallback if there's no truck rect) and shows itself. Color/cabin/wheel changes are broadcast as `customization_*` signals; `truck_entity` applies them as shader parameters on the truck body material.

### Per-instance shader material
`TruckEntity._ready()` **duplicates** the `ShaderMaterial` from `_truck_body` and assigns the duplicate to both `_truck_body` and `_truck_wheels`. This is required for multi-monitor: the material is a shared sub-resource in `truck_entity.tscn`, so without duplication all windows would write their own monitor's screen bounds into the **same** material. Each entity instance must own its material.

### Edge-fade shader
`shaders/truck_fade.gdshader` (a `CanvasItem` shader on the truck body) fades the truck at monitor edges. It needs **global** screen coordinates, so `truck_window._ready()` sets four constant uniforms (`window_width`, `screen_left`, `screen_right`, `fade_margin`) once via `truck_entity.init_shader_constants()`, and `truck_window._process()` updates only `window_x` each frame via `truck_entity.update_shader_window_x()`. With multiple windows, each `TruckWindow` feeds its own monitor's bounds — this only works correctly because each entity owns a duplicated material (see above).

### Config lives next to the EXE
`ConfigManager._ready()` copies `res://settings.cfg` to the executable's directory on first run (falls back to `res://` in the editor), then loads it. Read values only through `ConfigManager.get_setting(section, key, default)` — defaults are passed at every call site, so settings keys are loosely coupled. The helper `ConfigManager.is_multimonitor()` wraps the `multimonitor` key. Current sections: `[TruckSettings]` (speeds, wait times, `vertical_offset`, `customization`, `multimonitor`) and `[ShaderSettings]` (`fade_margin`).

### Debug tooling is debug-build-only
`DebugManager` early-returns unless `OS.is_debug_build()`. It spawns a control panel (`scenes/debug/`) and an optional "portal" window that mirrors the truck's `world_2d` into a second viewport for inspecting collision/debug shapes (`canvas_cull_mask` layer 2). Both self-position in `_ready()` like every other window; the portal links to the truck's `world_2d` via its own `ready` signal (`CONNECT_ONE_SHOT`), so the link always happens after `_ready()` rather than depending on call order. In multi-monitor mode, the portal only attaches to the **first** truck window's `world_2d`. These never ship in release builds.

## Assets & repo notes
- Binary assets use **Git LFS** — run `git lfs pull` after cloning. Missing `.ctex`/"failed loading" errors usually mean LFS wasn't pulled, or delete `.godot/` to force a clean re-import.
- Design specs and implementation plans live under `docs/superpowers/specs/` and `docs/superpowers/plans/`.
