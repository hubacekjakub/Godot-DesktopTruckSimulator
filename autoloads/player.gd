extends Node
## Owns all truck movement: the authoritative logical_x, speed, direction, the
## pass lifecycle, the per-monitor truck windows, and the stop/resume speed tween.
## Windows are held as base Window (not the TruckWindow class) and driven through
## dynamic has_method()/has_signal() checks, per the autoload class-registry rule.

const TRUCK_WINDOW_SCENE := "res://scenes/truck/truck_window.tscn"

var _logical_x: float = 0.0
var _speed: float = 0.0
var _direction: int = 1            # 1 = L->R, -1 = R->L
var _moving: bool = false
var _speed_multiplier: float = 1.0
var _is_paused: bool = false
var _app_hidden: bool = false

var _window_monitors: Dictionary = {} # Window -> Rect2i
var _crossed_windows: Array[Window] = []

var _wait_timer: Timer
var _multiplier_tween: Tween = null

var _first_pass_boot_delay: float = 1.0

func _ready() -> void:
	_wait_timer = Timer.new()
	_wait_timer.one_shot = true
	_wait_timer.timeout.connect(_on_wait_timer_timeout)
	add_child(_wait_timer)

	SignalBus.truck_movement_stop_triggered.connect(_on_truck_movement_stop_triggered)
	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)
	SignalBus.tray_visibility_changed.connect(_on_tray_visibility_changed)

	_setup_windows()

	# Boot the first driving pass after setup is finished.
	get_tree().create_timer(_first_pass_boot_delay).timeout.connect(start_next_pass)

func _setup_windows() -> void:
	var screen_data: Array = WindowManager.get_ordered_screen_data(ConfigManager.is_multimonitor())

	for pair in screen_data:
		var rect: Rect2i = pair[0]
		var screen_index: int = pair[1]
		var win: Window = WindowManager.spawn_window(TRUCK_WINDOW_SCENE)
		if not is_instance_valid(win):
			continue
		if win.has_method("set_monitor_rect"):
			win.set_monitor_rect(rect, screen_index)
		if win.has_signal("border_reached"):
			win.connect("border_reached", _on_border_reached.bind(win))
		win.tree_exited.connect(_on_window_freed.bind(win))
		_window_monitors[win] = rect

func _on_window_freed(win: Window) -> void:
	if not is_inside_tree():
		return
	_window_monitors.erase(win)
	_crossed_windows.erase(win)
	if _moving:
		_check_pass_completion()

func _process(delta: float) -> void:
	if _moving:
		_logical_x += _speed * _direction * _speed_multiplier * delta

func start_next_pass() -> void:
	if _is_paused or _app_hidden:
		return
	if _window_monitors.is_empty():
		return

	var min_speed: float = ConfigManager.get_setting("TruckSettings", "min_speed", 200.0)
	var max_speed: float = ConfigManager.get_setting("TruckSettings", "max_speed", 600.0)
	assert(min_speed >= 0.0, "TruckSettings: min_speed cannot be negative")
	assert(min_speed <= max_speed, "TruckSettings: min_speed cannot be greater than max_speed")

	_speed = randf_range(min_speed, max_speed)
	_crossed_windows.clear()
	_speed_multiplier = 1.0
	if _multiplier_tween and _multiplier_tween.is_valid():
		_multiplier_tween.kill()

	# Start just off the leading screen edge so no window pre-emits border_reached.
	var window_width: int = 0
	for win in _window_monitors:
		if is_instance_valid(win):
			window_width = win.size.x
			break

	var rects := _window_monitors.values()
	if rects.is_empty():
		return

	if _direction == 1:
		var first: Rect2i = rects[0]
		_logical_x = float(first.position.x - window_width)
	else:
		var last: Rect2i = rects[-1]
		_logical_x = float(last.position.x + last.size.x)

	for win in _window_monitors:
		if not is_instance_valid(win):
			continue
		if win.has_method("initialize_truck"):
			win.initialize_truck(_direction)

	_moving = true

func _on_border_reached(win: Window) -> void:
	if is_instance_valid(win) and not _crossed_windows.has(win):
		_crossed_windows.append(win)
	_check_pass_completion()

func _check_pass_completion() -> void:
	var valid_count := 0
	for win in _window_monitors:
		if is_instance_valid(win):
			valid_count += 1

	var crossed_count := 0
	for win in _crossed_windows:
		if is_instance_valid(win):
			crossed_count += 1

	if crossed_count < valid_count:
		return

	_moving = false
	_direction = -_direction
	for win in _window_monitors:
		if not is_instance_valid(win):
			continue
		if win.has_method("hide_window"):
			win.hide_window()

	var min_wait: float = ConfigManager.get_setting("TruckSettings", "min_wait_time", 5.0)
	var max_wait: float = ConfigManager.get_setting("TruckSettings", "max_wait_time", 15.0)
	_wait_timer.wait_time = randf_range(min_wait, max_wait)
	_wait_timer.start()

	SignalBus.truck_pass_completed.emit()

func _on_wait_timer_timeout() -> void:
	start_next_pass()

func _on_truck_movement_stop_triggered() -> void:
	if not _moving:
		_wait_timer.stop()
		_is_paused = true
		SignalBus.truck_movement_stop_finished.emit()
		return
	_is_paused = true
	if _multiplier_tween and _multiplier_tween.is_valid():
		_multiplier_tween.kill()
	_multiplier_tween = create_tween()
	_multiplier_tween.tween_property(self, "_speed_multiplier", 0.0, 2.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	_multiplier_tween.finished.connect(SignalBus.truck_movement_stop_finished.emit)

func _on_truck_movement_resume_triggered() -> void:
	if _app_hidden:
		return
	_is_paused = false
	if _moving:
		if _multiplier_tween and _multiplier_tween.is_valid():
			_multiplier_tween.kill()
		_multiplier_tween = create_tween()
		_multiplier_tween.tween_property(self, "_speed_multiplier", 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_multiplier_tween.finished.connect(SignalBus.truck_movement_resume_finished.emit)
	else:
		# Edge case: pass finished during the 2.5s stop tween while paused.
		_wait_timer.stop()
		SignalBus.truck_movement_resume_finished.emit()
		start_next_pass()

func get_logical_x() -> float:
	return _logical_x

func get_speed_multiplier() -> float:
	return _speed_multiplier

func get_truck_rect() -> Rect2i:
	var x: int = roundi(_logical_x)
	for win in _window_monitors:
		if not is_instance_valid(win):
			continue
		var rect: Rect2i = _window_monitors[win]
		var truck_visible: bool = win.has_method("is_truck_visible") and win.call("is_truck_visible")
		if x >= rect.position.x and x < rect.position.x + rect.size.x and truck_visible:
			return Rect2i(win.position, win.size)
	for win in _window_monitors:
		if not is_instance_valid(win):
			continue
		if win.has_method("is_truck_visible") and win.call("is_truck_visible"):
			return Rect2i(win.position, win.size)
	return Rect2i()

func _on_tray_visibility_changed(visible: bool) -> void:
	if not visible:
		# If paused for customization, notify listeners (Customization) to clean
		# up the garage window before we reset movement state.
		if _is_paused:
			SignalBus.truck_movement_resume_triggered.emit()
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
