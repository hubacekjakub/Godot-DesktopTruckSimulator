extends Node
## Main application lifecycle and pass coordinator.

var _wait_timer: Timer
var _active_truck_window: Window = null
var _is_paused: bool = false

func _ready() -> void:
	# Create and configure wait timer
	_wait_timer = Timer.new()
	_wait_timer.one_shot = true
	_wait_timer.timeout.connect(_on_wait_timer_timeout)
	add_child(_wait_timer)
	
	SignalBus.truck_pass_completed.connect(_on_truck_pass_completed)
	SignalBus.movement_toggle_requested.connect(_on_movement_toggle_requested)
	
	# Instantiate the single persistent window at startup
	_active_truck_window = WindowManager.spawn_window("res://scenes/truck/truck_window.tscn")
	
	# Boot the first driving pass after setup is finished
	get_tree().create_timer(1.0).timeout.connect(start_next_pass)

func start_next_pass() -> void:
	if _is_paused:
		return
		
	# Fallback if window was deleted/freed dynamically
	if not is_instance_valid(_active_truck_window):
		_active_truck_window = WindowManager.spawn_window("res://scenes/truck/truck_window.tscn")
		
	var min_speed: float = ConfigManager.get_setting("TruckSettings", "min_speed", 200.0)
	var max_speed: float = ConfigManager.get_setting("TruckSettings", "max_speed", 600.0)
	
	# Randomize driving settings
	var speed: float = randf_range(min_speed, max_speed)
	var direction: int = 1 if randf() > 0.5 else -1
	
	if is_instance_valid(_active_truck_window) and _active_truck_window.has_method("initialize_truck"):
		_active_truck_window.initialize_truck(direction, speed)

func _on_truck_pass_completed() -> void:
	# Keep the window instance but hide it
	if is_instance_valid(_active_truck_window) and _active_truck_window.has_method("hide_window"):
		_active_truck_window.hide_window()
		
	var min_wait: float = ConfigManager.get_setting("TruckSettings", "min_wait_time", 5.0)
	var max_wait: float = ConfigManager.get_setting("TruckSettings", "max_wait_time", 15.0)
	
	_wait_timer.wait_time = randf_range(min_wait, max_wait)
	_wait_timer.start()
	_wait_timer.paused = _is_paused

func _on_wait_timer_timeout() -> void:
	start_next_pass()

func _on_movement_toggle_requested(is_moving: bool) -> void:
	_is_paused = not is_moving
	if _is_paused:
		_wait_timer.paused = true
	else:
		_wait_timer.paused = false
		var has_active_pass: bool = is_instance_valid(_active_truck_window) and _active_truck_window.visible
		if not has_active_pass and _wait_timer.is_stopped():
			# Only start a new pass if there is no active pass running on screen
			start_next_pass()
