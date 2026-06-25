# System Tray Feature — Design Spec

**Date:** 2025-06-25
**Status:** Approved for implementation

## Overview

Add a native Windows system tray icon to the Desktop Truck Simulator using Godot's built-in `StatusIndicator` node. The tray provides quick access to visibility toggling, customization, and application exit — and will later serve as the anchor for a Jobs feature.

## Tray Menu Structure

```
┌──────────────────┐
│ ✓ Visible        │  ← checkbox toggle, checked by default
│──────────────────│
│   Customize      │  ← disabled when app is hidden
│   Jobs           │  ← always disabled (TBD)
│──────────────────│
│   Quit           │
└──────────────────┘
```

- **Visible** — Checkbox item. Checked = truck driving normally. Unchecked = all windows hidden, driving suspended.
- **Customize** — Opens the garage. Disabled while app is hidden.
- **Jobs** — Placeholder for a future feature. Always disabled, grayed out.
- **Quit** — Exits the application via `Global.close_application()`.

## New Signals (SignalBus)

| Signal | Type | Emitter | Purpose |
|--------|------|---------|---------|
| `tray_visibility_changed(visible: bool)` | `bool` | `SystemTray` | Visibility checkbox toggled |
| `tray_customization_requested()` | void | `SystemTray` | "Customize" menu item clicked |
| `tray_quit_requested()` | void | `SystemTray` | "Quit" menu item clicked |

No existing signals are removed or renamed. The current customization flow (`truck_movement_stop_triggered` → `stop_finished` → garage spawns → `customization_confirmed` → `customization_finished` → `truck_movement_resume_triggered`) stays untouched.

## Flows

### Toggle to Hidden

1. User unchecks "Visible" in tray menu
2. `SystemTray` emits `tray_visibility_changed(false)`
3. `SystemTray` disables "Customize" menu item
4. **Player** receives signal:
   - Sets `_app_hidden = true`
   - Stops any active wait timer
   - Sets `_moving = false`
   - Cancels any active `_multiplier_tween`
   - Hides all truck windows (calls `hide_window()` on each)
   - Resets `_logical_x` to 0
   - Resets `_speed_multiplier` to 1.0
   - Clears `_crossed_windows`
5. **Customization** receives signal:
   - If garage window is open, `queue_free()` it and null the reference

### Toggle to Visible

1. User checks "Visible" in tray menu
2. `SystemTray` emits `tray_visibility_changed(true)`
3. `SystemTray` re-enables "Customize" menu item
4. **Player** receives signal:
   - Sets `_app_hidden = false`
   - Calls `start_next_pass()` to begin a fresh driving pass

### Open Customization (from tray)

1. User clicks "Customize" (only clickable when Visible is checked)
2. `SystemTray` emits `tray_customization_requested()`
3. **Global** receives signal:
   - Emits `truck_movement_stop_triggered` — reuses existing stop→garage flow entirely
4. Existing flow handles the rest:
   - Player tweens `_speed_multiplier` → 0 over 2.5s
   - Player emits `truck_movement_stop_finished`
   - Customization spawns the garage window
   - User interacts with garage
   - Garage emits `customization_confirmed`
   - Customization emits `customization_finished`
   - Global relays to `truck_movement_resume_triggered`
   - Player tweens back to full speed

### Quit

1. User clicks "Quit"
2. `SystemTray` emits `tray_quit_requested()`
3. **Global** receives signal → calls `close_application()`
4. `Global.close_application()` calls `get_tree().quit()`
   - This method is the future hook point for save manager integration

## New Autoload: SystemTray

**File:** `autoloads/system_tray.gd`
**Boot order:** After `Customization` (last autoload)

### Responsibilities
- Creates and owns a `StatusIndicator` node with `res://icon.svg` as the icon
- Creates and owns a `PopupMenu` as child, wired to the `StatusIndicator`
- Manages menu item states (enable/disable Customize based on visibility)
- Emits signals through `SignalBus` — never calls other autoloads directly
- Tracks visibility state internally to toggle the checkbox

### Menu Item IDs (constants)

| Constant | Value | Menu Item |
|----------|-------|-----------|
| `MENU_VISIBLE` | `0` | Visible (checkbox) |
| `MENU_CUSTOMIZE` | `1` | Customize |
| `MENU_JOBS` | `2` | Jobs |
| `MENU_QUIT` | `3` | Quit |

### Signal Connections
- Listens to `customization_finished` to know when garage closes (keeps internal state consistent if customization was triggered from tray)
- Listens to own `PopupMenu.id_pressed` for menu item dispatch

## Changes to Existing Files

### signal_bus.gd
Add three new signals:
```gdscript
# System tray
signal tray_visibility_changed(visible: bool)
signal tray_customization_requested()
signal tray_quit_requested()
```

### player.gd
- New variable: `var _app_hidden: bool = false`
- New method: `_on_tray_visibility_changed(visible: bool)`
  - When `false`: set `_app_hidden = true`, cancel pass (stop timer, stop moving, cancel tween), hide all windows, reset `_logical_x` / `_speed_multiplier` / `_crossed_windows`
  - When `true`: set `_app_hidden = false`, call `start_next_pass()`
- Connect `SignalBus.tray_visibility_changed` in `_ready()`
- Guard `start_next_pass()` with `if _app_hidden: return` to prevent wait-timer callbacks from starting passes while hidden
- Guard `_on_truck_movement_resume_triggered()` similarly

### customization.gd
- New method: `_on_tray_visibility_changed(visible: bool)`
  - When `false`: if `_garage_window_instance` is valid, `queue_free()` it, null the reference
  - When `true`: no-op
- New method: `_on_tray_customization_requested()`
  - Guard: if `_garage_window_instance` is valid (garage already open), return early
  - Otherwise: emit `SignalBus.truck_movement_stop_triggered` to trigger existing stop→garage flow
- Connect `SignalBus.tray_visibility_changed` in `_ready()`
- Connect `SignalBus.tray_customization_requested` in `_ready()`

### global.gd
- New method: `close_application()`
  - Calls `get_tree().quit()` (future hook for save manager)
- Connect `SignalBus.tray_quit_requested` → `close_application()`

### project.godot
- Add `SystemTray` autoload entry: `SystemTray="*res://autoloads/system_tray.gd"` after `Customization`

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Toggle Hidden while garage is open | Garage is `queue_free()`'d, all windows hidden, pass reset |
| Toggle Visible after being Hidden | Fresh pass starts from scratch |
| Click Customize while truck is between passes (waiting) | Stop triggered, wait timer cancelled by Player's stop handler, garage opens when tween finishes |
| Click Customize while already in customization | Guard in `customization.gd`: if garage is already open (`_garage_window_instance` is valid), ignore the `tray_customization_requested` signal. Customization connects to this signal directly and only relays to `truck_movement_stop_triggered` when appropriate. |
| Click Customize while hidden | Menu item is disabled, not clickable |
| Quit while garage is open | `get_tree().quit()` handles cleanup |
| Multiple rapid visibility toggles | Each toggle cancels previous state cleanly — `_app_hidden` is authoritative |

## Not In Scope

- Custom tray icon art (using `res://icon.svg` for now)
- Jobs feature (menu item present but disabled)
- Save manager integration in `close_application()` (future work)
- Linux tray support (`StatusIndicator` is Windows/macOS only — acceptable for this project)
