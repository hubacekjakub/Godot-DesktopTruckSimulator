extends Node2D
## Manager script for the Desktop Truck Simulator.
##
## Architecture: The main Godot window (384×384) acts as a viewport for the truck.
## It is borderless, transparent, always-on-top, and moved in absolute screen
## coordinates to follow the truck across the desktop. No Camera2D is used —
## the truck sprite sits at the center of the viewport and the window itself moves.
## No subwindow is spawned (unlike the old architecture). Inspired by the
## Geegaz/Multiple-Windows-tutorial pattern.
##
## Safezone: The window is clamped to the target screen so it never escapes onto
## an adjacent monitor. The truck sprite offsets within the window to visually
## slide off the screen edges while the window stays in bounds.
##
## Lifecycle:
##   _ready()          → configure window, detect screen, start first pass
##   _process()        → move truck, clamp window to screen, update shader
##   _begin_wait()     → hide truck, start random delay timer
##   _on_wait_timer()  → flip direction, start next pass


@export var speed_min: float = 200.0
@export var speed_max: float = 600.0
## Vertical offset from the bottom of the usable screen area.
## Positive values move the truck UP, negative values move it DOWN.
@export var vertical_offset: int = -192

# -- Movement state --
var _current_x: float = 0.0        ## Logical X position (can exceed screen bounds)
var _target_y: int = 0             ## Y position (bottom of usable screen area)
var _speed: float = 400.0          ## Current pass speed (randomised each pass)
var _direction: int = 1            ## 1 = left-to-right, -1 = right-to-left
var _moving: bool = false          ## True while the truck is driving across the screen

# -- Screen bounds --
var _usable_rect: Rect2i           ## Usable rect of the target screen (excludes taskbar)
var _target_screen_idx: int = 0    ## Locked at startup; falls back if monitor disconnected

# -- Shader parameters (used when ShaderMaterial is assigned to sprites) --
var _fade_padding: int = 100       ## Width of the fade zone in pixels
var _safety_margin: int = 0        ## Distance from screen edge where alpha reaches 0

# -- Animation --
var _bob_tween: Tween
var _truck_center_x: float         ## Captured from Truck node position in _ready()

@onready var _main_window: Window = get_window()
@onready var _truck: Node2D = $Truck
@onready var _truck_body: Sprite2D = $Truck/TruckBody
@onready var _truck_wheels: Sprite2D = $Truck/TruckWheels
@onready var _wheel_emitters: Array[GPUParticles2D] = [
	$Truck/WheelDust,
	$Truck/WheelDust2,
	$Truck/WheelDust3
]
@onready var _wait_timer: Timer = $WaitTimer


func _ready() -> void:
	# Capture truck's default center position from the scene before we start moving it.
	_truck_center_x = _truck.position.x

	# Lock to whichever screen the window opens on. This index is used for all
	# subsequent screen_get_usable_rect() calls, even if the window moves.
	_target_screen_idx = _main_window.current_screen

	# ---- MAIN WINDOW SETUP ----
	# The main window IS the truck. Configure it as a transparent overlay.
	_main_window.borderless = true
	_main_window.unresizable = true
	_main_window.always_on_top = true
	_main_window.unfocusable = true
	_main_window.mouse_passthrough = true
	_main_window.gui_embed_subwindows = false  # Future subwindows become real OS windows

	# Move off-screen while we set up transparency to avoid a flash.
	_main_window.position = Vector2i(-10000, -10000)

	# Transparency workaround for Godot bug #71642 on Windows:
	# The native window handle (HWND) isn't fully created yet, so transparency
	# flags set now get ignored. We start with transparent=false, wait for the
	# window to be realized, then enable transparency.
	_main_window.transparent = false
	_main_window.transparent_bg = false

	await get_tree().process_frame
	await get_tree().process_frame

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, _main_window.get_window_id())

	_main_window.transparent = true
	_main_window.transparent_bg = true


	# Share the same ShaderMaterial instance so both sprites fade identically.
	_truck_wheels.material = _truck_body.material

	_wait_timer.timeout.connect(_on_wait_timer_timeout)

	# Query screen bounds and start the first pass
	_update_desktop_bounds()
	_start_pass()
	_start_bobbing()


## Called every frame. Advances the truck's logical X position, clamps the window
## to the target screen, and offsets the truck sprite for the edge slide-off effect.
func _process(delta: float) -> void:
	if not _moving:
		return

	_current_x += _speed * _direction * delta

	# Check if the truck's logical position is fully past the screen edge.
	if _direction == 1 and _current_x > _usable_rect.position.x + _usable_rect.size.x:
		_begin_wait()
		return
	elif _direction == -1 and _current_x < _usable_rect.position.x - _main_window.size.x:
		_begin_wait()
		return

	# Clamp the actual window position so it never escapes onto an adjacent monitor.
	var clamped_x = clampi(int(_current_x),
		_usable_rect.position.x,
		_usable_rect.position.x + _usable_rect.size.x - _main_window.size.x)
	_main_window.position = Vector2i(clamped_x, _target_y)

	# Offset the truck sprite within the window so it visually drives off the edge.
	# When unclamped: offset = 0, truck stays centered at (192, 192).
	# When clamped: truck slides toward/past the window edge.
	var offset_x = int(_current_x) - clamped_x
	_truck.position.x = _truck_center_x + offset_x

	# Update shader uniforms for edge-fade effect (only when ShaderMaterial is assigned).
	var mat = _truck_body.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("window_x", float(clamped_x))
		mat.set_shader_parameter("window_width", float(_main_window.size.x))
		mat.set_shader_parameter("screen_left", float(_usable_rect.position.x))
		mat.set_shader_parameter("screen_right", float(_usable_rect.position.x + _usable_rect.size.x))
		mat.set_shader_parameter("fade_margin", float(_fade_padding))
		mat.set_shader_parameter("safety_margin", float(_safety_margin))


## Begins a new pass across the screen.
func _start_pass() -> void:
	_update_desktop_bounds()
	_speed = randf_range(speed_min, speed_max)

	# Logical start: just past the screen edge (truck fully off-screen).
	# The window will be clamped to the screen edge on the first frame.
	if _direction == 1:
		_current_x = float(_usable_rect.position.x - _main_window.size.x)
	else:
		_current_x = float(_usable_rect.position.x + _usable_rect.size.x)

	_truck.scale.x = abs(_truck.scale.x) * _direction

	# Set position BEFORE enabling particles so they don't emit from off-screen.
	_target_y = _usable_rect.position.y + _usable_rect.size.y - _main_window.size.y - vertical_offset
	var clamped_x = clampi(int(_current_x),
		_usable_rect.position.x,
		_usable_rect.position.x + _usable_rect.size.x - _main_window.size.x)
	_main_window.position = Vector2i(clamped_x, _target_y)

	# Set initial truck offset (fully off the window edge)
	var offset_x = int(_current_x) - clamped_x
	_truck.position.x = _truck_center_x + offset_x

	# Show the truck (hidden in _begin_wait)
	_truck.visible = true

	for emitter in _wheel_emitters:
		if emitter: emitter.emitting = true

	# DEBUG: Remove or gate behind a flag before release.
	print("Pass started. Direction: ", _direction, " Position: ", _main_window.position, " Speed: ", _speed)
	_moving = true


## Stops movement and starts a random wait before the next pass.
func _begin_wait() -> void:
	_moving = false

	for emitter in _wheel_emitters:
		emitter.emitting = false

	# Hide truck so the transparent window shows nothing during wait.
	# Window stays in place (no teleport — that caused a flash).
	# mouse_passthrough=true ensures clicks go through the transparent window.
	_truck.visible = false

	_wait_timer.wait_time = randf_range(5.0, 15.0)
	_wait_timer.start()


## Calculates the bounding box of the target screen.
## Falls back to the primary screen if the target was disconnected.
func _update_desktop_bounds() -> void:
	if _target_screen_idx >= DisplayServer.get_screen_count():
		_target_screen_idx = DisplayServer.get_primary_screen()
	_usable_rect = DisplayServer.screen_get_usable_rect(_target_screen_idx)


## Timer callback: flip direction and start the next pass.
func _on_wait_timer_timeout() -> void:
	_direction *= -1
	_start_pass()


## Creates a looping suspension-bob on the truck body only.
## Wheels stay stationary — intentional, simulates suspension travel.
func _start_bobbing() -> void:
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_truck_body, "position:y", -4.0, 0.4).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_truck_body, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
