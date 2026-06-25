# System Tray Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native Windows system tray icon with Visible toggle, Customize, Jobs (disabled), and Quit menu items.

**Architecture:** New `SystemTray` autoload owns the `StatusIndicator` + `PopupMenu`. All cross-system communication flows through `SignalBus`. Player gains an `_app_hidden` flag to gate pass lifecycle. Customization gains the tray-customize relay with a garage-open guard. Global gains `close_application()` as the future save-manager hook.

**Tech Stack:** Godot 4.6, GDScript, `StatusIndicator` node (native Windows tray), `PopupMenu`

**Spec:** `docs/superpowers/specs/2025-06-25-system-tray-design.md`

---

### Task 1: Add tray signals to SignalBus

**Files:**
- Modify: `autoloads/signal_bus.gd` (lines 22-25)

- [ ] **Step 1: Add three new signals**

Append the system tray signal group before the debug section. Open `autoloads/signal_bus.gd` and replace lines 22-25:

```gdscript
# System tray
signal tray_visibility_changed(visible: bool)
signal tray_customization_requested()
signal tray_quit_requested()

# Debug actions
signal debug_portal_toggle_requested(open: bool)
signal truck_color_randomize_requested()
```

The file should now have these sections in order: truck lifecycle → truck movement → customization → system tray → debug.

- [ ] **Step 2: Verify syntax**

Run: `godot.exe --headless --path . -e -q`
Expected: Exit code 0, no errors.

---

### Task 2: Create SystemTray autoload

**Files:**
- Create: `autoloads/system_tray.gd`

- [ ] **Step 1: Create the system tray autoload script**

Create `autoloads/system_tray.gd` with this content:

```gdscript
extends Node
## System tray icon with visibility toggle, customization access, and quit.
## Owns the StatusIndicator and PopupMenu. Communicates only through SignalBus.

const MENU_VISIBLE: int = 0
const MENU_CUSTOMIZE: int = 1
const MENU_JOBS: int = 2
const MENU_QUIT: int = 3

var _status_indicator: StatusIndicator
var _popup_menu: PopupMenu
var _is_visible: bool = true

func _ready() -> void:
	_popup_menu = PopupMenu.new()
	_popup_menu.add_check_item("Visible", MENU_VISIBLE)
	_popup_menu.add_separator()
	_popup_menu.add_item("Customize", MENU_CUSTOMIZE)
	_popup_menu.add_item("Jobs", MENU_JOBS)
	_popup_menu.add_separator()
	_popup_menu.add_item("Quit", MENU_QUIT)

	# Visible starts checked; Jobs is always disabled.
	_popup_menu.set_item_checked(_popup_menu.get_item_index(MENU_VISIBLE), true)
	_popup_menu.set_item_disabled(_popup_menu.get_item_index(MENU_JOBS), true)

	_popup_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_popup_menu)

	_status_indicator = StatusIndicator.new()
	_status_indicator.icon = load("res://icon.svg")
	_status_indicator.tooltip = "Desktop Truck Simulator"
	_status_indicator.menu = _popup_menu.get_path()
	_status_indicator.visible = true
	add_child(_status_indicator)

func _on_menu_id_pressed(id: int) -> void:
	match id:
		MENU_VISIBLE:
			_toggle_visibility()
		MENU_CUSTOMIZE:
			SignalBus.tray_customization_requested.emit()
		MENU_QUIT:
			SignalBus.tray_quit_requested.emit()

func _toggle_visibility() -> void:
	_is_visible = not _is_visible
	var idx: int = _popup_menu.get_item_index(MENU_VISIBLE)
	_popup_menu.set_item_checked(idx, _is_visible)

	# Disable Customize when hidden; re-enable when visible.
	var customize_idx: int = _popup_menu.get_item_index(MENU_CUSTOMIZE)
	_popup_menu.set_item_disabled(customize_idx, not _is_visible)

	SignalBus.tray_visibility_changed.emit(_is_visible)
```

- [ ] **Step 2: Verify syntax**

Run: `godot.exe --headless --path . -e -q`
Expected: Exit code 0. (Script exists but is not yet registered as autoload — no runtime errors.)

---

### Task 3: Update Player for app-hidden visibility

**Files:**
- Modify: `autoloads/player.gd` (lines 12, 22-34, 62-64, 152-164)

- [ ] **Step 1: Add `_app_hidden` variable**

In `autoloads/player.gd`, after line 12 (`var _is_paused: bool = false`), add:

```gdscript
var _app_hidden: bool = false
```

- [ ] **Step 2: Connect tray_visibility_changed in _ready()**

In `autoloads/player.gd`, after line 29 (`SignalBus.truck_movement_resume_triggered.connect(...)`), add:

```gdscript
	SignalBus.tray_visibility_changed.connect(_on_tray_visibility_changed)
```

- [ ] **Step 3: Add `_app_hidden` guard to `start_next_pass()`**

In `autoloads/player.gd`, replace lines 63-64:

```gdscript
	if _is_paused:
		return
```

with:

```gdscript
	if _is_paused or _app_hidden:
		return
```

- [ ] **Step 4: Add `_app_hidden` guard to `_on_truck_movement_resume_triggered()`**

In `autoloads/player.gd`, at the start of `_on_truck_movement_resume_triggered()` (line 152-153), replace:

```gdscript
func _on_truck_movement_resume_triggered() -> void:
	_is_paused = false
```

with:

```gdscript
func _on_truck_movement_resume_triggered() -> void:
	if _app_hidden:
		return
	_is_paused = false
```

- [ ] **Step 5: Add the `_on_tray_visibility_changed` handler**

At the end of `autoloads/player.gd` (after `get_truck_rect()`), append:

```gdscript
func _on_tray_visibility_changed(visible: bool) -> void:
	if not visible:
		_app_hidden = true
		_moving = false
		_is_paused = false
		_wait_timer.stop()
		if _multiplier_tween and _multiplier_tween.is_valid():
			_multiplier_tween.kill()
		_speed_multiplier = 1.0
		_logical_x = 0.0
		_crossed_windows.clear()
		for win in _window_monitors:
			if is_instance_valid(win) and win.has_method("hide_window"):
				win.hide_window()
	else:
		_app_hidden = false
		start_next_pass()
```

- [ ] **Step 6: Verify syntax**

Run: `godot.exe --headless --path . -e -q`
Expected: Exit code 0, no errors.

---

### Task 4: Update Customization for tray signals

**Files:**
- Modify: `autoloads/customization.gd` (lines 50-55)

- [ ] **Step 1: Connect tray signals in _ready()**

In `autoloads/customization.gd`, after line 55 (`SignalBus.customization_finished.connect(...)`), add:

```gdscript
	SignalBus.tray_visibility_changed.connect(_on_tray_visibility_changed)
	SignalBus.tray_customization_requested.connect(_on_tray_customization_requested)
```

- [ ] **Step 2: Add the tray visibility handler**

At the end of `autoloads/customization.gd` (after `_on_customization_finished()`), append:

```gdscript
func _on_tray_visibility_changed(visible: bool) -> void:
	if not visible and is_instance_valid(_garage_window_instance):
		_garage_window_instance.queue_free()
		_garage_window_instance = null
```

- [ ] **Step 3: Add the tray customization request handler**

Immediately after the `_on_tray_visibility_changed` method, append:

```gdscript
func _on_tray_customization_requested() -> void:
	if is_instance_valid(_garage_window_instance):
		return
	SignalBus.truck_movement_stop_triggered.emit()
```

- [ ] **Step 4: Verify syntax**

Run: `godot.exe --headless --path . -e -q`
Expected: Exit code 0, no errors.

---

### Task 5: Update Global with close_application()

**Files:**
- Modify: `autoloads/global.gd` (lines 1-2, 6-7)

- [ ] **Step 1: Update the doc comment**

In `autoloads/global.gd`, replace line 2:

```gdscript
## Customization event relay. All truck movement lives in the Player autoload.
```

with:

```gdscript
## Customization event relay and application lifecycle. All truck movement lives
## in the Player autoload.
```

- [ ] **Step 2: Connect tray_quit_requested in _ready()**

In `autoloads/global.gd`, after line 7 (`SignalBus.customization_finished.connect(...)`), add:

```gdscript
	SignalBus.tray_quit_requested.connect(close_application)
```

- [ ] **Step 3: Add close_application()**

At the end of `autoloads/global.gd` (after `get_truck_rect()`), append:

```gdscript
## Graceful shutdown. Hook point for future save-manager integration.
func close_application() -> void:
	get_tree().quit()
```

- [ ] **Step 4: Verify syntax**

Run: `godot.exe --headless --path . -e -q`
Expected: Exit code 0, no errors.

---

### Task 6: Register SystemTray autoload in project.godot

**Files:**
- Modify: `project.godot` (line 28)

- [ ] **Step 1: Add SystemTray to the autoload section**

In `project.godot`, after line 28 (`Customization="*res://autoloads/customization.gd"`), add:

```ini
SystemTray="*res://autoloads/system_tray.gd"
```

The `[autoload]` section should now read:
```ini
[autoload]

SignalBus="*res://autoloads/signal_bus.gd"
ConfigManager="*res://autoloads/config_manager.gd"
WindowManager="*res://autoloads/window_manager.gd"
Player="*res://autoloads/player.gd"
Global="*res://autoloads/global.gd"
DebugManager="*res://autoloads/debug_manager.gd"
Customization="*res://autoloads/customization.gd"
SystemTray="*res://autoloads/system_tray.gd"
```

- [ ] **Step 2: Verify syntax**

Run: `godot.exe --headless --path . -e -q`
Expected: Exit code 0, no errors.

---

### Task 7: Full verification

**Files:** None (verification only)

- [ ] **Step 1: Run headless syntax check**

Run: `godot.exe --headless --path . -e -q`
Expected: Exit code 0, no script errors.

- [ ] **Step 2: Run the game and verify tray icon appears**

Run: `godot_console.exe --path .`

Verify:
1. A tray icon appears in the Windows system tray using the Godot icon
2. Right-clicking shows the menu: Visible (checked), Customize, Jobs (grayed), Quit
3. Unchecking Visible hides all truck windows; Customize becomes grayed out
4. Checking Visible again starts a fresh driving pass
5. Clicking Customize stops the truck and opens the garage
6. Clicking Quit exits the application

