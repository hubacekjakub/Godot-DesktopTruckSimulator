extends Node2D
## Manager script for the Desktop Truck Simulator.
## Handles window positioning, transparency workarounds, and movement logic.

@export var speed_min: float = 200.0
@export var speed_max: float = 600.0
## Vertical offset from the bottom of the usable screen area.
## Positive values move the truck UP, negative values move it DOWN.
@export var vertical_offset: int = -192

var _current_x: float = 0.0
var _speed: float = 400.0
var _direction: int = 1 # 1 = left-to-right, -1 = right-to-left
var _moving: bool = false
var _desktop_rect: Rect2i
var _usable_rect: Rect2i
var _fade_padding: int = 200
var _safety_margin: int = 60 # Distance from edge where truck is fully invisible
var _bob_tween: Tween

@onready var _sub_window: Window = $Window
@onready var _truck: Node2D = $Window/Truck
@onready var _truck_body: Sprite2D = $Window/Truck/TruckBody
@onready var _truck_wheels: Sprite2D = $Window/Truck/TruckWheels
@onready var _wheel_emitters: Array[GPUParticles2D] = [
	$Window/Truck/WheelDust,
	$Window/Truck/WheelDust2,
	$Window/Truck/WheelDust3
]
@onready var _wait_timer: Timer = $WaitTimer


func _ready() -> void:
	# Hide the main application window off-screen.
	var main_window = get_window()
	main_window.position = Vector2i(-10000, -10000)

	# Master Fix: Set main window transparency to ensure sub-windows can render transparently.
	main_window.transparent = true
	main_window.transparent_bg = true

	# Ensure the sub-window is not transient to the hidden main window.
	_sub_window.transient = false

	_update_desktop_bounds()

	# Workaround for Godot bug #71642 on Windows:
	_sub_window.transparent = false
	_sub_window.transparent_bg = false

	await get_tree().process_frame
	await get_tree().process_frame

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, _sub_window.get_window_id())

	_sub_window.transparent = true
	_sub_window.transparent_bg = true

	# Share the same material instance if they aren't already
	_truck_wheels.material = _truck_body.material
	_wait_timer.timeout.connect(_on_wait_timer_timeout)

	# Start the first pass
	_start_pass()

	# Start the bobbing
	_start_bobbing()


func _process(delta: float) -> void:
	if not _moving or _sub_window == null:
		return

	_current_x += _speed * _direction * delta
	_sub_window.position.x = int(_current_x)

	# Update shader uniforms on the shared material.
	# Since they share the material, we only need to set it on one.
	var mat = _truck_body.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("window_x", float(_current_x))
		mat.set_shader_parameter("window_width", float(_sub_window.size.x))
		mat.set_shader_parameter("screen_left", float(_usable_rect.position.x))
		mat.set_shader_parameter("screen_right", float(_usable_rect.position.x + _usable_rect.size.x))
		mat.set_shader_parameter("fade_margin", float(_fade_padding))
		mat.set_shader_parameter("safety_margin", float(_safety_margin))

	# Check if fully off-screen using usable bounds + safety margin.
	if _direction == 1 and _current_x > _usable_rect.position.x + _usable_rect.size.x - _safety_margin:
		_begin_wait()
	elif _direction == -1 and _current_x < _usable_rect.position.x - _sub_window.size.x + _safety_margin:
		_begin_wait()


## Begins a new pass across the screen.
func _start_pass() -> void:
	_update_desktop_bounds()
	_speed = randf_range(speed_min, speed_max)

	# Position the window just outside the safety margin.
	if _direction == 1:
		_current_x = float(_usable_rect.position.x - _sub_window.size.x + _safety_margin)
	else:
		_current_x = float(_usable_rect.position.x + _usable_rect.size.x - _safety_margin)

	_truck.scale.x = abs(_truck.scale.x) * _direction

	for emitter in _wheel_emitters:
		if emitter: emitter.emitting = true

	var target_y = _usable_rect.position.y + _usable_rect.size.y - _sub_window.size.y - vertical_offset
	_sub_window.position = Vector2i(int(_current_x), target_y)
	print("Pass started. Direction: ", _direction, " Position: ", _sub_window.position, " Speed: ", _speed)
	_moving = true


## Stops movement and starts a random wait before the next pass.
func _begin_wait() -> void:
	_moving = false

	for emitter in _wheel_emitters:
		emitter.emitting = false

	_sub_window.position = Vector2i(-10000, -10000)

	_wait_timer.wait_time = randf_range(5.0, 15.0)
	_wait_timer.start()


## Calculates the bounding box of the primary screen.
func _update_desktop_bounds() -> void:
	var screen_idx = 0
	_desktop_rect = Rect2i(
		DisplayServer.screen_get_position(screen_idx),
		DisplayServer.screen_get_size(screen_idx)
	)
	_usable_rect = DisplayServer.screen_get_usable_rect(screen_idx)


func _on_wait_timer_timeout() -> void:
	_direction *= -1
	_start_pass()


func _start_bobbing() -> void:
	_bob_tween = create_tween().set_loops()
	# Bob up and down by 2 pixels over 0.2 seconds
	_bob_tween.tween_property(_truck_body, "position:y", -4.0, 0.4).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_truck_body, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
