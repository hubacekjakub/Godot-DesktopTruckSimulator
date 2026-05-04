extends Node2D
## Manager script for the Desktop Truck Simulator.
## Hides the main Godot application window and configures the sub-window
## with a transparent background using the Godot #71642 workaround.
## Animates the truck window across the bottom of the screen, alternating direction.

@export var speed_min = 200
@export var speed_max = 600

@onready var _sub_window: Window = $Window
@onready var _truck_sprite: Sprite2D = $Window/Truck
@onready var _wait_timer: Timer = $WaitTimer

var _current_x: float = 0.0
var _speed: float = 400.0
var _direction: int = 1 # 1 = left-to-right, -1 = right-to-left
var _moving: bool = false
var _desktop_rect: Rect2i

func _ready():
	# Hide the main application window off-screen.
	var main_window = get_window()
	main_window.position = Vector2i(-10000, -10000)

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

	# Connect the wait timer
	_wait_timer.timeout.connect(_on_wait_timer_timeout)

	# Start the first pass (left to right)
	_start_pass()

## Begins a new pass across the screen in the current _direction.
func _start_pass():
	var screen_size = DisplayServer.screen_get_size()
	var taskbar_margin = -100
	
	_speed = randf_range(speed_min, speed_max)

	if _direction == 1:
		_current_x = float(-_sub_window.size.x)
	else:
		_current_x = float(screen_size.x)

	_truck_sprite.flip_h = (_direction == -1)

	_sub_window.position = Vector2i(
		int(_current_x),
		screen_size.y - _sub_window.size.y - taskbar_margin
	)
	_moving = true

func _process(delta: float):
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

## Stops movement and starts a random 5–15s wait before the next pass.
func _begin_wait():
	_moving = false
	_wait_timer.wait_time = randf_range(5.0, 15.0)
	_wait_timer.start()

## Calculates the total bounding box of all connected screens and updates _desktop_rect.
func _update_desktop_bounds():
	var screen_count = DisplayServer.get_screen_count()
	var min_x = 0
	var max_x = 0
	var min_y = 0
	var max_y = 0
	
	for i in range(screen_count):
		var pos = DisplayServer.screen_get_position(i)
		var size = DisplayServer.screen_get_size(i)
		
		if i == 0:
			min_x = pos.x
			max_x = pos.x + size.x
			min_y = pos.y
			max_y = pos.y + size.y
		else:
			min_x = min(min_x, pos.x)
			max_x = max(max_x, pos.x + size.x)
			min_y = min(min_y, pos.y)
			max_y = max(max_y, pos.y + size.y)
			
	_desktop_rect = Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)

## Called when the wait timer fires. Flips direction and starts a new pass.
func _on_wait_timer_timeout():
	_direction *= -1
	_start_pass()
