extends Node2D
## Manager script for the Desktop Truck Simulator.
## Hides the main Godot application window and configures the sub-window
## with a transparent background using the Godot #71642 workaround.
## Animates the truck window across the bottom of the screen, alternating direction.

@export var speed_min: float = 200.0
@export var speed_max: float = 600.0
@export var taskbar_margin: int = 100

var _current_x: float = 0.0
var _speed: float = 400.0
var _direction: int = 1 # 1 = left-to-right, -1 = right-to-left
var _moving: bool = false
var _desktop_rect: Rect2i
var _fade_padding: int = 200
var _safety_margin: int = 30 # Distance from edge where truck is fully invisible

@onready var _sub_window: Window = $Window
@onready var _truck_sprite: Sprite2D = $Window/Truck
@onready var _wait_timer: Timer = $WaitTimer


# region Virtual Methods

func _ready() -> void:
	# Hide the main application window off-screen.
	var main_window = get_window()
	main_window.position = Vector2i(-10000, -10000)

	# Ensure the sub-window is not transient to the hidden main window.
	# Transient windows are often clamped to the parent's screen by the OS.
	_sub_window.transient = false
	
	_update_desktop_bounds()

	# Workaround for Godot bug #71642 on Windows:
	# The OS ignores transparency flags set before the native window handle
	# (HWND) is fully created. We start with transparent = false, wait 2
	# frames for the OS to finish constructing the window, then toggle it on.
	_sub_window.transparent = false
	_sub_window.transparent_bg = false

	await get_tree().process_frame
	await get_tree().process_frame

	_sub_window.transparent = true
	_sub_window.transparent_bg = true

	# Shrink window to truck size to minimize OS-level multi-monitor glitches.
	var truck_size = _truck_sprite.get_rect().size * _truck_sprite.scale
	_sub_window.size = Vector2i(int(truck_size.x), int(truck_size.y))
	_truck_sprite.position = _sub_window.size / 2.0

	# Connect the wait timer
	_wait_timer.timeout.connect(_on_wait_timer_timeout)

	# Start the first pass (left to right)
	_start_pass()


func _process(delta: float) -> void:
	if not _moving or _sub_window == null:
		return

	_current_x += _speed * _direction * delta
	_sub_window.position.x = int(_current_x)

	# Update shader uniforms for per-pixel global fade.
	# We use _current_x instead of _sub_window.position.x to ensure mathematical 
	# stability even if the OS tries to clamp the physical window position.
	var shader_material = _truck_sprite.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("window_x", float(_current_x))
		shader_material.set_shader_parameter("window_width", float(_sub_window.size.x))
		shader_material.set_shader_parameter("screen_width", float(_desktop_rect.size.x))
		shader_material.set_shader_parameter("fade_margin", float(_fade_padding))
		shader_material.set_shader_parameter("safety_margin", float(_safety_margin))

	# Check if fully off-screen using desktop bounds + safety margin.
	# The truck is fully invisible once its leading edge is past safety_margin.
	if _direction == 1 and _current_x > _desktop_rect.position.x + _desktop_rect.size.x - _safety_margin:
		_begin_wait()
	elif _direction == -1 and _current_x < _desktop_rect.position.x - _sub_window.size.x + _safety_margin:
		_begin_wait()

# endregion


# region Private Methods

## Begins a new pass across the screen in the current _direction.
func _start_pass() -> void:
	_update_desktop_bounds()
	_speed = randf_range(speed_min, speed_max)

	# Position the window just outside the safety margin where it is already 100% transparent.
	if _direction == 1:
		_current_x = float(_desktop_rect.position.x - _sub_window.size.x + _safety_margin)
	else:
		_current_x = float(_desktop_rect.position.x + _desktop_rect.size.x - _safety_margin)

	_truck_sprite.flip_h = (_direction == -1)

	_sub_window.position = Vector2i(
		int(_current_x),
		_desktop_rect.position.y + _desktop_rect.size.y - _sub_window.size.y - taskbar_margin
	)
	_moving = true


## Stops movement and starts a random 5–15s wait before the next pass.
func _begin_wait() -> void:
	_moving = false
	
	# Move the window off-screen immediately so it doesn't linger in 
	# multi-monitor "clamping" zones or cause OS-level glitches.
	_sub_window.position = Vector2i(-10000, -10000)
	
	_wait_timer.wait_time = randf_range(5.0, 15.0)
	_wait_timer.start()


## Calculates the bounding box of the primary screen and updates _desktop_rect.
func _update_desktop_bounds() -> void:
	var screen_idx = 0 # Always use primary screen
	var pos = DisplayServer.screen_get_position(screen_idx)
	var size = DisplayServer.screen_get_size(screen_idx)

	_desktop_rect = Rect2i(pos.x, pos.y, size.x, size.y)

## Called when the wait timer fires. Flips direction and starts a new pass.
func _on_wait_timer_timeout() -> void:
	_direction *= -1
	_start_pass()

# endregion
