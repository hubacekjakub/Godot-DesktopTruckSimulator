extends Node2D
## Manager script for the Desktop Truck Simulator.

@export var speed_min: float = 200.0
@export var speed_max: float = 600.0
@export var vertical_offset: int = -192

var _current_x: float = 0.0
var _speed: float = 400.0
var _direction: int = 1 # 1 = left-to-right, -1 = right-to-left
var _moving: bool = false
var _desktop_rect: Rect2i
var _usable_rect: Rect2i
var _fade_padding: int = 200
var _safety_margin: int = 30 

@onready var _sub_window: Window = $Window
@onready var _truck_sprite: Sprite2D = $Window/Truck
@onready var _wait_timer: Timer = $WaitTimer

func _log(message: String) -> void:
	print(message)
	var f = FileAccess.open("user://debug.log", FileAccess.READ_WRITE)
	if not f:
		f = FileAccess.open("user://debug.log", FileAccess.WRITE)
	else:
		f.seek_end()
	f.store_line(str(Time.get_datetime_string_from_system()) + ": " + message)

func _ready() -> void:
	# Clear log
	var f = FileAccess.open("user://debug.log", FileAccess.WRITE)
	if f:
		f.store_line("--- Log Started ---")
		f.close()

	_log("Main: _ready() started")
	var main_window = get_window()
	main_window.position = Vector2i(-10000, -10000)
	
	_sub_window.transient = false
	
	_update_desktop_bounds()
	_log("Main: Desktop Rect: " + str(_desktop_rect))
	_log("Main: Usable Rect: " + str(_usable_rect))
	_log("Main: Screen Scale: " + str(DisplayServer.screen_get_scale(0)))

	_sub_window.transparent = false
	_sub_window.transparent_bg = false
	
	# Increase wait for export-build stability
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	_sub_window.transparent = true
	_sub_window.transparent_bg = true
	_log("Main: Transparency workaround applied (extended wait)")

	var truck_size = _truck_sprite.get_rect().size * _truck_sprite.scale
	_sub_window.size = Vector2i(int(truck_size.x), int(truck_size.y))
	_truck_sprite.position = _sub_window.size / 2.0

	_wait_timer.timeout.connect(_on_wait_timer_timeout)
	_start_pass()

func _process(delta: float) -> void:
	if not _moving or _sub_window == null:
		return
	_current_x += _speed * _direction * delta
	_sub_window.position.x = int(_current_x)
	var shader_material = _truck_sprite.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("window_x", float(_current_x))
		shader_material.set_shader_parameter("window_width", float(_sub_window.size.x))
		shader_material.set_shader_parameter("screen_left", float(_usable_rect.position.x))
		shader_material.set_shader_parameter("screen_right", float(_usable_rect.position.x + _usable_rect.size.x))
		shader_material.set_shader_parameter("fade_margin", float(_fade_padding))
		shader_material.set_shader_parameter("safety_margin", float(_safety_margin))
	if _direction == 1 and _current_x > _usable_rect.position.x + _usable_rect.size.x - _safety_margin:
		_begin_wait()
	elif _direction == -1 and _current_x < _usable_rect.position.x - _sub_window.size.x + _safety_margin:
		_begin_wait()

func _start_pass() -> void:
	_update_desktop_bounds()
	_speed = randf_range(speed_min, speed_max)
	if _direction == 1:
		_current_x = float(_usable_rect.position.x - _sub_window.size.x + _safety_margin)
	else:
		_current_x = float(_usable_rect.position.x + _usable_rect.size.x - _safety_margin)
	_truck_sprite.flip_h = (_direction == -1)
	_sub_window.position = Vector2i(int(_current_x), _usable_rect.position.y + _usable_rect.size.y - _sub_window.size.y - vertical_offset)
	_moving = true

func _begin_wait() -> void:
	_moving = false
	_sub_window.position = Vector2i(-10000, -10000)
	_wait_timer.wait_time = randf_range(5.0, 15.0)
	_wait_timer.start()

func _update_desktop_bounds() -> void:
	var screen_idx = 0
	_desktop_rect = Rect2i(DisplayServer.screen_get_position(screen_idx), DisplayServer.screen_get_size(screen_idx))
	_usable_rect = DisplayServer.screen_get_usable_rect(screen_idx)

func _on_wait_timer_timeout() -> void:
	_direction *= -1
	_start_pass()
