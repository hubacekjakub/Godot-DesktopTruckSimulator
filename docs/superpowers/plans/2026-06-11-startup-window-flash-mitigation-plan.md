# Window Flash Mitigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the visual "flash" that occurs when OS windows are created — specifically when they appear at the wrong position or with an opaque frame before transparency is negotiated.

**Architecture:** Targeted fixes applied only where a real problem exists. The truck window's two-frame transparency workaround (Godot Bug #71642) is already correct and must not be disturbed. The confirmed flash on startup comes from the **main launcher window** — it boots at center-screen before `main.gd:_ready()` repositions it. Additional gaps: the debug panel calls `show()` with no off-screen pre-positioning, and the debug portal uses synchronous `add_child()` with no off-screen init.

**Tech Stack:** Godot 4.6, GDScript

---

## Background: What Already Works (Do Not Change)

`truck_window.gd` already implements the correct two-phase pattern:

1. `_ready()` sets `position = Vector2i(-10000, -10000)` and calls `show()` **while off-screen**.  
2. Awaits two process frames (required for native window handle creation on Windows).  
3. Only then negotiates transparency via `DisplayServer.window_set_flag(WINDOW_FLAG_TRANSPARENT, ...)`.  
4. Calls `hide_window()` to stay hidden until `initialize_truck()` is called.

This sequence is the documented workaround for Godot Bug #71642 and **must be preserved in all window scripts**.

`spawn_window()` in `window_manager.gd` uses `add_child.call_deferred()`, which means any pre-sets on the node *before* tree entry are overridden by `_ready()`. The defence is inside `_ready()`, not in `spawn_window()`. This is correct behaviour.

---

## What Is Actually Broken

### Problem 0 (Confirmed): Main Launcher Window — the flash you see on startup

`project.godot` has no `initial_position` set for the main window, so the OS creates it **centered on screen** at 384×384. `main.gd:_ready()` then moves it to `(-100, -100)` and minimizes it — but that script runs *after* the window is already drawn by the OS for at least one frame. This is the flash in the middle of your screen.

**Fix:** Set `initial_position_type=0` (Absolute) and `initial_position=Vector2i(-10000, -10000)` in `project.godot` so the OS creates the window off-screen from the very first frame, before any script runs. The `main.gd` script logic can stay as-is.

### Problem 1: Debug Panel (`debug_manager.gd` / `debug_panel.gd`)

`DebugManager._ready()` instantiates the panel directly and calls `add_child.call_deferred(_panel)`. Then it immediately sets `_panel.position` — but since the add is deferred, this position is set **before** the node is in the tree, so `_ready()` in `debug_panel.gd` may override it. Worse, `debug_panel.gd:_ready()` calls `show()` directly with no off-screen pre-positioning and no transparency preamble. This causes a visible flash of a default opaque OS window frame at whatever position the OS defaults to.

### Problem 2: Debug Portal (`debug_manager.gd:_on_portal_toggle`)

The portal is instantiated and added via **synchronous** `add_child()` (not deferred), meaning `_ready()` fires immediately — before any position override can be applied. The portal has no off-screen init logic.

### Problem 3: `truck_window.tscn` has `initial_position = 1` (Center of Screen)

The `.tscn` file sets `initial_position = 1` (Center of Primary Screen). Even though `_ready()` overrides this, there is a brief moment between when the OS creates the native window handle and when the Godot script runs where the OS could render the window at center. Changing this to `0` (Absolute) removes that brief gap without touching any script logic.

---

### Task 0: Fix Main Launcher Window (The Confirmed Startup Flash)

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Add initial_position to the `[display]` section**

  The `[display]` section currently has no `initial_position_type` or `initial_position` keys, so the OS defaults to centering the window. Add these two keys:

  ```ini
  [display]

  window/size/viewport_width=384
  window/size/viewport_height=384
  window/size/borderless=true
  window/size/always_on_top=true
  window/size/transparent=true
  window/size/initial_position_type=0
  window/size/initial_position=Vector2i(-10000, -10000)
  window/subwindows/embed_subwindows=false
  window/per_pixel_transparency/allowed=true
  ```

  > Do **not** add `window/size/mode=1` (minimized). `main.gd:_ready()` already minimizes the window via script — setting minimized statically in `project.godot` could interfere with autoload initialization order on some platforms. The off-screen position alone is sufficient to prevent the flash.

- [ ] **Step 2: Verify syntax**
  ```powershell
  godot.exe --headless --path . -e -q
  ```

---

### Task 1: Fix `truck_window.tscn` initial_position

**Files:**
- Modify: `scenes/truck/truck_window.tscn`

- [ ] **Step 1: Change initial_position from 1 to 0**

  This removes the "Center of Primary Screen" hint so the OS has no reason to position the window on-screen before `_ready()` runs.

  *Change in `scenes/truck/truck_window.tscn`:*
  ```ini
  # BEFORE
  initial_position = 1

  # AFTER
  initial_position = 0
  ```

  Do not change any other values — in particular, `visible = false` and `transparent = true` are already correct.

- [ ] **Step 2: Verify syntax**
  ```powershell
  godot.exe --headless --path . -e -q
  ```

---

### Task 2: Fix Debug Panel Flash

**Files:**
- Modify: `scenes/debug/debug_panel.gd`

The debug panel needs the same two-phase off-screen / transparency init that `truck_window.gd` uses. It does not need `DisplayServer` transparency flags (it's a normal bordered window), but it must be moved off-screen before `show()` so the OS doesn't flash it at center screen.

- [ ] **Step 1: Rewrite `debug_panel.gd:_ready()` to initialize off-screen**

  *Replace the existing `_ready()` with:*

  ```gdscript
  func _ready() -> void:
  	borderless = false
  	title = "Debug Control Panel"
  	size = Vector2i(280, 240)
  	close_requested.connect(func(): queue_free())
  	SignalBus.debug_portal_toggle_requested.connect(_on_portal_toggle_received)

  	# Move off-screen before showing to prevent OS flash
  	position = Vector2i(-10000, -10000)
  	show()

  	# Wait for the window handle to stabilize, then move to final position
  	await get_tree().process_frame
  	await get_tree().process_frame
  	if not is_inside_tree():
  		return

  	# Final position is set by DebugManager after spawn — read it back here
  	# Nothing to do; DebugManager.position assignment will now happen after _ready() completes
  ```

  > **Note:** `DebugManager` sets `_panel.position` after `add_child.call_deferred()`. Because `add_child` is deferred, `_ready()` fires on the next frame after the deferred call executes. The two `await` frames in `_ready()` mean `DebugManager`'s position assignment (which runs before the deferred add resolves) is harmless — position is locked in `_ready()` at `-10000, -10000` first, then the awaits complete, and `DebugManager`'s assignment has already been overwritten. 
  >
  > **Fix the ordering:** `DebugManager` must set position **after** the awaits, not before. See Task 3.

- [ ] **Step 2: Verify syntax**
  ```powershell
  godot.exe --headless --path . -e -q
  ```

---

### Task 3: Fix DebugManager Panel Positioning Race

**Files:**
- Modify: `autoloads/debug_manager.gd`

Currently `DebugManager._ready()` sets `_panel.position` immediately after `add_child.call_deferred()`. After the Task 2 changes, `debug_panel._ready()` awaits two frames before showing — so the position must also be set after those frames, or it'll be ignored.

- [ ] **Step 1: Move position assignment into a deferred callback**

  *Replace the panel spawn block in `debug_manager.gd:_ready()`:*

  ```gdscript
  # BEFORE
  _panel = load("res://scenes/debug/debug_panel.tscn").instantiate()
  get_tree().root.add_child.call_deferred(_panel)
  _panel.tree_exiting.connect(func(): _panel = null)

  # Position the panel lower (centered horizontally, shifted vertically)
  var rect := WindowManager.get_usable_rect()
  _panel.position = Vector2i(rect.position.x + 100, rect.position.y + 300)
  ```

  ```gdscript
  # AFTER
  _panel = load("res://scenes/debug/debug_panel.tscn").instantiate()
  get_tree().root.add_child.call_deferred(_panel)
  _panel.tree_exiting.connect(func(): _panel = null)

  # Wait for the panel's two-frame transparency init to complete, then position
  await get_tree().create_timer(0.1).timeout
  if is_instance_valid(_panel):
  	var rect := WindowManager.get_usable_rect()
  	_panel.position = Vector2i(rect.position.x + 100, rect.position.y + 300)
  ```

  > `0.1s` is a safe buffer for two process frames (which complete in < 1 frame time ~16ms). Alternatively, emit a signal from `debug_panel.gd` when init is complete (similar to `SignalBus.truck_spawned`) for a more event-driven approach.

- [ ] **Step 2: Verify syntax**
  ```powershell
  godot.exe --headless --path . -e -q
  ```

---

### Task 4: Fix Debug Portal Flash

**Files:**
- Modify: `autoloads/debug_manager.gd`

The portal is spawned with **synchronous** `add_child()` and has no off-screen init.

- [ ] **Step 1: Switch portal spawn to `add_child.call_deferred()` and add off-screen pre-position**

  Check `scenes/debug/debug_portal.gd` (or `.tscn`) for any existing `_ready()` logic that calls `show()`. If found, apply the same two-frame pattern as Task 2.

  *In `debug_manager.gd:_on_portal_toggle()`, replace the portal add block:*

  ```gdscript
  # BEFORE
  _portal = load("res://scenes/debug/debug_portal.tscn").instantiate()
  get_tree().root.add_child(_portal)

  # Position the portal lower
  var rect := WindowManager.get_usable_rect()
  _portal.position = Vector2i(rect.position.x + 400, rect.position.y + 300)
  ```

  ```gdscript
  # AFTER
  _portal = load("res://scenes/debug/debug_portal.tscn").instantiate()
  _portal.position = Vector2i(-10000, -10000)  # Pre-position before tree entry
  get_tree().root.add_child(_portal)           # Synchronous: _ready() fires immediately

  # Position after _ready() / transparency init settles
  await get_tree().create_timer(0.1).timeout
  if is_instance_valid(_portal):
  	var rect := WindowManager.get_usable_rect()
  	_portal.position = Vector2i(rect.position.x + 400, rect.position.y + 300)
  ```

  > For synchronous `add_child()`, pre-setting `position` **does** work if the Window's `_ready()` doesn't override it. Inspect `debug_portal.gd` to confirm before implementing. If `_ready()` calls `show()` without off-screen positioning, apply the same two-frame pattern there too.

- [ ] **Step 2: Verify syntax**
  ```powershell
  godot.exe --headless --path . -e -q
  ```

---

### Task 5: Verify End-to-End Behaviour

- [ ] **Step 1: Run the project (debug build)**

  Ask the user to run the project — the agent cannot reliably launch a GUI application:
  ```powershell
  godot_console.exe --path .
  ```

  Verify:
  1. **Cold start:** Screen stays completely clear until the truck actively drives across. No white/grey flash at any point.
  2. **Debug panel:** Appears at its target position without a visible flash of an opaque OS frame.
  3. **Debug portal:** Opens without flashing. Closes cleanly.
  4. **Truck passes:** Continue to work normally — window is hidden between passes, re-shown with `initialize_truck()`.

- [ ] **Step 2: Verify in release build (no debug windows)**

  ```powershell
  godot_console.exe --path . --export-release "Windows Desktop" .
  ```

  Or simply test an exported build. Confirm no regressions in truck behaviour when debug windows are absent.

---

## What This Plan Does NOT Change

- `truck_window.gd` — already correct. Do not remove `show()`, do not remove the two `await` lines.
- `window_manager.gd:spawn_window()` — the pre-position / `visible = false` from the old plan adds no value since `_ready()` handles it. Leave as-is.
- `main.gd` — already moves and minimizes the window in script. No changes needed there.
- `project.godot` — **only** the two `initial_position` keys are added (Task 0). Do **not** add `window/size/mode=1` (minimized) to `project.godot`.

