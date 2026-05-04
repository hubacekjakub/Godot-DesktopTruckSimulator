extends Node2D
## Manager script for the Desktop Truck Simulator.
## Hides the main Godot application window and configures the sub-window
## with a transparent background using the Godot #71642 workaround.
## Animates the truck window across the bottom of the screen, alternating direction.

var _sub_window: Window
var _truck_sprite: Sprite2D
var _current_x: float = 0.0
var _speed: float = 200.0
var _direction: int = 1 # 1 = left-to-right, -1 = right-to-left
var _moving: bool = false
var _waiting: bool = false
var _wait_timer: float = 0.0

func _ready():
	# Hide the main application window off-screen.
	var main_window = get_window()
	main_window.transparent = true
	main_window.transparent_bg = true
	main_window.borderless = true
	main_window.mouse_passthrough = true
	main_window.position = Vector2i(-10000, -10000)

	# Workaround for Godot bug #71642 on Windows:
	# The OS ignores transparency flags set before the native window handle
	# (HWND) is fully created. We start with transparent = false, wait 2
	# frames for the OS to finish constructing the window, then toggle it on.
	_sub_window = $Window
	_truck_sprite = $Window/Truck
	_sub_window.borderless = true
	_sub_window.transparent = false
	_sub_window.transparent_bg = false

	await get_tree().process_frame
	await get_tree().process_frame

	_sub_window.transparent = true
	_sub_window.transparent_bg = true

	# Start the first pass (left to right)
	_start_pass()

func _start_pass():
	var screen_size = DisplayServer.screen_get_size()
	var taskbar_margin = 80

	if _direction == 1:
		# Left to right: start off-screen on the left
		_current_x = float(-_sub_window.size.x)
	else:
		# Right to left: start off-screen on the right
		_current_x = float(screen_size.x)
		# Flip the truck sprite horizontally
	_truck_sprite.flip_h = (_direction == -1)

	_sub_window.position = Vector2i(
		int(_current_x),
		screen_size.y - _sub_window.size.y - taskbar_margin
	)
	_moving = true
	_waiting = false

func _process(delta: float):
	if _waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_direction *= -1
			_start_pass()
		return

	if not _moving or _sub_window == null:
		return

	_current_x += _speed * _direction * delta
	_sub_window.position.x = int(_current_x)

	# Check if fully off-screen
	var screen_width = DisplayServer.screen_get_size().x
	if _direction == 1 and _sub_window.position.x > screen_width:
		_begin_wait()
	elif _direction == -1 and _sub_window.position.x < -_sub_window.size.x:
		_begin_wait()

func _begin_wait():
	_moving = false
	_waiting = true
	_wait_timer = randf_range(5.0, 15.0)
