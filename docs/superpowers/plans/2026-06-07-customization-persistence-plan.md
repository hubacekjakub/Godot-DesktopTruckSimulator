# Customize Saved State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store the selected truck customization indices in the `Customization` autoload, load them when the garage window is spawned, keep the color list solely inside `garage_window.gd`, and apply the customized color to the truck on startup.

**Architecture:** We will keep the `cabin_colors` array local to `garage_window.gd`. The `truck_entity.gd` will dynamically load `garage_window.gd` to retrieve the default colors on boot, avoiding duplication. The `Customization` autoload will only store the selected index.

**Tech Stack:** Godot 4, GDScript.

---

### Task 1: Update Customization Autoload & Truck Startup

**Files:**
- Modify: `autoloads/customization.gd`
- Modify: `scenes/truck/truck_entity.gd`

- [ ] **Step 1: Modify `autoloads/customization.gd`**
  Remove the `cabin_colors` list from the autoload (keep only tracking indices):
  ```gdscript
  extends Node
  ## Handles skin customization to the truck

  var _garage_window_resource: String = "res://scenes/garage/garage_window.tscn"
  var _garage_window_instance: Window = null

  var current_color_index: int = 0
  var current_cabin_index: int = 0
  var current_wheels_index: int = 0
  ```

- [ ] **Step 2: Modify `scenes/truck/truck_entity.gd`**
  In `_ready()`, load and apply the default custom color by instantiating the script temporarily:
  ```gdscript
  func _ready() -> void:
  	_center_x = position.x
  	_truck_wheels.material = _truck_body.material

  	SignalBus.truck_movement_stop_triggered.connect(_on_truck_movement_stop_triggered)
  	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)

  	SignalBus.truck_color_randomize_requested.connect(_on_color_randomize_requested)
  	SignalBus.customization_color_changed.connect(_on_customization_color_changed)
  	SignalBus.customization_cabin_changed.connect(_on_customization_cabin_changed)
  	SignalBus.customization_wheels_changed.connect(_on_customization_wheels_changed)

  	# Apply initial customization color on boot by querying the garage window script
  	var garage_script = load("res://scenes/garage/garage_window.gd")
  	if garage_script:
  		var temp_obj = garage_script.new()
  		if temp_obj and "cabin_colors" in temp_obj:
  			var colors = temp_obj.cabin_colors
  			if colors.size() > Customization.current_color_index:
  				var initial_color = colors[Customization.current_color_index]
  				_on_customization_color_changed(initial_color)
  		if is_instance_valid(temp_obj):
  			temp_obj.free()

  	_start_bobbing()
  ```

- [ ] **Step 3: Run headless syntax verification**
  Run: `godot.exe --headless --path . -e -q`
  Expected: Success.

---

### Task 2: Update Garage Window Script

**Files:**
- Modify: `scenes/garage/garage_window.gd`

- [ ] **Step 1: Modify `scenes/garage/garage_window.gd`**
  Keep `cabin_colors` defined locally and update loading/saving:
  ```gdscript
  extends Window

  @export var current_color_index: int = 0

  @export var cabin_colors: Array[Color] = [
  	Color("#ebede9"),
  	Color("#3c5e8b"),
  	Color("#468232"),
  	Color("#de9e41"),
  	Color("#a8ca58"),
  	Color("#577277"),
  ]

  # UI elements mapped to new tscn hierarchy
  @onready var color_counter: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxColor/CounterColor
  @onready var color_next: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxColor/NextColor
  @onready var color_prev: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxColor/PreviousColor
  @onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Confirm

  func _ready() -> void:
  	# Load current setup from customization manager
  	current_color_index = Customization.current_color_index
  	update_ui()
  	# Emit active color on spawn to ensure preview matches
  	SignalBus.customization_color_changed.emit(cabin_colors[current_color_index])

  func next_color() -> void:
  	if current_color_index == cabin_colors.size() - 1:
  		current_color_index = 0
  	else:
  		current_color_index += 1
  	SignalBus.customization_color_changed.emit(cabin_colors[current_color_index])
  	update_ui()

  func previous_color() -> void:
  	if current_color_index == 0:
  		current_color_index = cabin_colors.size() - 1
  	else:
  		current_color_index -= 1
  	SignalBus.customization_color_changed.emit(cabin_colors[current_color_index])
  	update_ui()

  func update_ui() -> void:
  	color_counter.text = "%d/%d" % [current_color_index + 1, cabin_colors.size()]

  func confirm() -> void:
  	# Save setup to customization manager
  	Customization.current_color_index = current_color_index
  	SignalBus.customization_finished.emit()
  ```

- [ ] **Step 2: Run headless syntax verification**
  Run: `godot.exe --headless --path . -e -q`
  Expected: Success.
