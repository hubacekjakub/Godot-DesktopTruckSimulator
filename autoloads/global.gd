extends Node
## Main application lifecycle and pass coordinator.

var _wait_timer: Timer
var _active_truck_window: Window = null
var _is_paused: bool = false
var _direction: int = 1 # Start driving Left-to-Right

var _first_pass_customization_delay: float = 2.5

func _ready() -> void:
	# Create and configure wait timer
	_wait_timer = Timer.new()
	_wait_timer.one_shot = true
	_wait_timer.timeout.connect(_on_wait_timer_timeout)
	add_child(_wait_timer)

	SignalBus.truck_pass_completed.connect(_on_truck_pass_completed)
	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)
	SignalBus.truck_movement_stop_triggered.connect(_on_truck_movement_stop_triggered)
	SignalBus.customization_finished.connect(_on_customization_finished)

	# Instantiate the single persistent window at startup
	_active_truck_window = WindowManager.spawn_window("res://scenes/truck/truck_window.tscn")

	# Boot the first driving pass after setup is finished
	get_tree().create_timer(1.0).timeout.connect(start_next_pass)

	if ConfigManager.get_setting("TruckSettings", "customization", false):
		get_tree().create_timer(_first_pass_customization_delay).timeout.connect(_on_first_pass_customization_timer_timeout)

func _on_first_pass_customization_timer_timeout() -> void:
	assert(not _is_paused, "Should never be paused when pausing movement!")
	SignalBus.truck_movement_stop_triggered.emit()

func start_next_pass() -> void:
	if _is_paused:
		return

	# Fallback if window was deleted/freed dynamically
	if not is_instance_valid(_active_truck_window):
		_active_truck_window = WindowManager.spawn_window("res://scenes/truck/truck_window.tscn")

	var min_speed: float = ConfigManager.get_setting("TruckSettings", "min_speed", 200.0)
	var max_speed: float = ConfigManager.get_setting("TruckSettings", "max_speed", 600.0)
	assert(min_speed >= 0.0, "TruckSettings: min_speed cannot be negative")
	assert(min_speed <= max_speed, "TruckSettings: min_speed cannot be greater than max_speed")

	# Randomize driving speed
	var speed: float = randf_range(min_speed, max_speed)

	if is_instance_valid(_active_truck_window) and _active_truck_window.has_method("initialize_truck"):
		_active_truck_window.initialize_truck(_direction, speed)

		# Alternate direction for the next pass
		_direction = - _direction

func _on_truck_pass_completed() -> void:
	# Keep the window instance but hide it
	if is_instance_valid(_active_truck_window) and _active_truck_window.has_method("hide_window"):
		_active_truck_window.hide_window()

	var min_wait: float = ConfigManager.get_setting("TruckSettings", "min_wait_time", 5.0)
	var max_wait: float = ConfigManager.get_setting("TruckSettings", "max_wait_time", 15.0)

	_wait_timer.wait_time = randf_range(min_wait, max_wait)
	_wait_timer.start()

func _on_wait_timer_timeout() -> void:
	start_next_pass()

func _on_truck_movement_resume_triggered() -> void:
	var has_active_pass: bool = is_instance_valid(_active_truck_window) and _active_truck_window.visible
	if has_active_pass:
		# Only allow pausing/resuming movement if the truck is active on screen
		_is_paused = false

func _on_truck_movement_stop_triggered() -> void:
	var has_active_pass: bool = is_instance_valid(_active_truck_window) and _active_truck_window.visible
	if has_active_pass:
		_is_paused = true

func _on_customization_finished() -> void:
	SignalBus.truck_movement_resume_triggered.emit()

## Returns the current screen bounds (position and size) of the active truck window
func get_truck_rect() -> Rect2i:
	if is_instance_valid(_active_truck_window):
		return Rect2i(_active_truck_window.position, _active_truck_window.size)
	return Rect2i()
