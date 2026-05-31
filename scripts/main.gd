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

# -- Debug Portal and Shapes --
var _debug_portal: Window = null
var _debug_control_panel: Window = null
var _debug_camera: Camera2D = null
var _debug_box: ReferenceRect = null
var _debug_label: Label = null
var _debug_track: Line2D = null

# -- Movement Controls --
var _speed_multiplier: float = 1.0
var _target_multiplier: float = 1.0
var _multiplier_tween: Tween = null
var _btn_toggle_move: Button = null
var _btn_window: Window = null


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

	# Only render Layer 1 (visuals) on the main window.
	# This keeps the desktop overlay completely clean of debug shapes.
	_main_window.canvas_cull_mask = 1

	# Create a debug boundary box around the truck (Layer 2)
	_debug_box = ReferenceRect.new()
	_debug_box.name = "DebugBox"
	_debug_box.border_color = Color(0.0, 1.0, 0.0, 1.0) # Green outline
	_debug_box.border_width = 2.0
	_debug_box.editor_only = false
	_debug_box.size = Vector2(260, 160)
	_debug_box.position = Vector2(-130, -80) # Centered on truck
	_debug_box.visibility_layer = 2
	_truck.add_child(_debug_box)

	# Create a debug stats label above the truck (Layer 2)
	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_label.size = Vector2(200, 50)
	_debug_label.position = Vector2(-100, -140)
	_debug_label.visibility_layer = 2
	_truck.add_child(_debug_label)

	# Create a debug track line (Layer 2)
	_debug_track = Line2D.new()
	_debug_track.name = "DebugTrack"
	_debug_track.width = 2.0
	_debug_track.default_color = Color(1.0, 0.0, 0.0, 0.6) # Red trajectory line
	_debug_track.visibility_layer = 2
	add_child(_debug_track)


	# Share the same ShaderMaterial instance so both sprites fade identically.
	_truck_wheels.material = _truck_body.material

	_wait_timer.timeout.connect(_on_wait_timer_timeout)

	# Query screen bounds and start the first pass
	_update_desktop_bounds()
	_start_pass()
	_start_bobbing()

	# Spawn the interactive debug windows after a short delay
	get_tree().create_timer(1.5).timeout.connect(func():
		_spawn_debug_portal_window()
		_spawn_debug_control_panel()
	)


## Called every frame. Handles window alignment, debug camera tracking, shape positions,
## and advances the truck's position during movement passes.
func _process(delta: float) -> void:
	# -- Real-time debug alignment & tracking (Always active, even during wait times) --
	# Align the debug camera to matches the portal's physical screen offset.
	if is_instance_valid(_debug_portal) and _debug_portal.visible and is_instance_valid(_debug_camera):
		_debug_camera.position = Vector2(_debug_portal.position - _main_window.position)

	# Update red track line points to stay static relative to screen coordinates
	if is_instance_valid(_debug_track):
		_debug_track.clear_points()
		var track_y = _target_y + 192 - _main_window.position.y
		_debug_track.add_point(Vector2(_usable_rect.position.x - _main_window.position.x, track_y))
		_debug_track.add_point(Vector2(_usable_rect.position.x + _usable_rect.size.x - _main_window.position.x, track_y))

	# Update positions of all spawned shapes to stay static relative to screen coordinates
	var shapes = get_tree().get_nodes_in_group("spawned_debug_shapes")
	for shape in shapes:
		if is_instance_valid(shape):
			var abs_pos = shape.get_meta("absolute_position") as Vector2
			shape.position = abs_pos - Vector2(_main_window.position)

	# Update debug stats text
	if is_instance_valid(_debug_label):
		_debug_label.text = "STATE: %s\nSPEED: %.1f px/s\nDIR: %s\nSCREEN_X: %d" % [
			"MOVING" if _moving else "WAITING",
			_speed,
			"R" if _direction == 1 else "L",
			int(_current_x)
		]

	# Align the hello button window next to the truck window
	if is_instance_valid(_btn_window):
		_btn_window.visible = _truck.visible and _moving
		if _btn_window.visible:
			# Position it right next to the main window viewport
			_btn_window.position = _main_window.position + Vector2i(_main_window.size.x, 150)

	if is_instance_valid(_bob_tween):
		_bob_tween.set_speed_scale(_speed_multiplier)

	for emitter in _wheel_emitters:
		if emitter:
			emitter.emitting = _moving and (_speed_multiplier > 0.1)

	# -- logical Movement (Only active during movement passes) --
	if not _moving:
		return

	_current_x += _speed * _direction * _speed_multiplier * delta

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


## Spawns an interactive test window to demonstrate multi-window capabilities.
## Spawns an interactive debug portal window that renders both layers (truck + debug shapes).
func _spawn_debug_portal_window() -> void:
	_debug_portal = Window.new()
	_debug_portal.title = "Debug Shape Portal"
	_debug_portal.size = Vector2i(450, 300)
	
	# Position it in the center of the screen
	var screen_center = _usable_rect.position + _usable_rect.size / 2
	_debug_portal.position = screen_center - _debug_portal.size / 2
	
	# Window configuration: bordered (movable), focusable, transient (attaches to main window)
	_debug_portal.borderless = false
	_debug_portal.always_on_top = false
	_debug_portal.unfocusable = false
	_debug_portal.transient = true
	
	# Share the 2D world database so it sees the same scene tree
	_debug_portal.world_2d = _main_window.world_2d
	
	# Render Layer 1 (truck) and Layer 2 (debug shapes)
	_debug_portal.canvas_cull_mask = 1 | 2
	
	# Add a Camera2D to handle tracking relative to screen offset
	_debug_camera = Camera2D.new()
	_debug_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_debug_portal.add_child(_debug_camera)
	
	# Connection for closing
	_debug_portal.close_requested.connect(func(): _debug_portal.queue_free())
	
	# Add to main window as child and display
	add_child(_debug_portal)
	_debug_portal.show()
	print("Debug Portal spawned at: ", _debug_portal.position)


## Spawns the Debug Control Panel window containing options to spawn debug shapes.
func _spawn_debug_control_panel() -> void:
	_debug_control_panel = Window.new()
	_debug_control_panel.title = "Debug Control Panel"
	_debug_control_panel.size = Vector2i(280, 270)
	
	# Position it to the right of the center screen (offset from the portal)
	var screen_center = _usable_rect.position + _usable_rect.size / 2
	_debug_control_panel.position = Vector2i(screen_center.x + 250, screen_center.y - _debug_control_panel.size.y / 2)
	
	_debug_control_panel.borderless = false
	_debug_control_panel.always_on_top = false
	_debug_control_panel.unfocusable = false
	_debug_control_panel.transient = true
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_debug_control_panel.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var label = Label.new()
	label.text = "Spawn shapes into Layer 2:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var btn_spawn = Button.new()
	btn_spawn.text = "Spawn Random ColorRect"
	btn_spawn.pressed.connect(_spawn_random_debug_shape)
	vbox.add_child(btn_spawn)
	
	var btn_clear = Button.new()
	btn_clear.text = "Clear Spawned Shapes"
	btn_clear.pressed.connect(_clear_spawned_shapes)
	vbox.add_child(btn_clear)
	
	_btn_toggle_move = Button.new()
	_btn_toggle_move.text = "Stop Truck"
	_btn_toggle_move.pressed.connect(_toggle_truck_movement)
	vbox.add_child(_btn_toggle_move)
	
	var btn_hello = Button.new()
	btn_hello.text = "Toggle Hello Button"
	btn_hello.pressed.connect(_toggle_hello_button)
	vbox.add_child(btn_hello)
	
	var btn_tint = Button.new()
	btn_tint.text = "Randomize Color"
	btn_tint.pressed.connect(_randomize_truck_color)
	vbox.add_child(btn_tint)
	
	_debug_control_panel.close_requested.connect(func(): _debug_control_panel.queue_free())
	
	add_child(_debug_control_panel)
	_debug_control_panel.show()
	print("Debug Control Panel spawned at: ", _debug_control_panel.position)


## Spawns a colored rectangle on Layer 2 at a random screen location.
func _spawn_random_debug_shape() -> void:
	var rect = ColorRect.new()
	
	# Pick a random size and color
	rect.size = Vector2(randf_range(60, 160), randf_range(60, 160))
	rect.color = Color(randf(), randf(), randf(), 0.6) # 60% opacity
	
	# Pick a random screen out of all connected screens (for multi-monitor support)
	var screen_count = DisplayServer.get_screen_count()
	var rand_screen = randi() % screen_count
	var s_rect = DisplayServer.screen_get_usable_rect(rand_screen)
	
	# Position it randomly inside that screen's bounds
	var rand_x = randf_range(s_rect.position.x + 50, s_rect.position.x + s_rect.size.x - rect.size.x - 50)
	var rand_y = randf_range(s_rect.position.y + 50, s_rect.position.y + s_rect.size.y - rect.size.y - 50)
	
	# Store absolute screen position and set initial local position relative to main window
	rect.set_meta("absolute_position", Vector2(rand_x, rand_y))
	rect.position = Vector2(rand_x, rand_y) - Vector2(_main_window.position)
	
	# Assign to Layer 2 so it is only visible through the debug portal
	rect.visibility_layer = 2
	rect.add_to_group("spawned_debug_shapes")
	
	add_child(rect)
	print("Spawned debug shape on screen ", rand_screen, " at absolute position: ", Vector2(rand_x, rand_y))


## Clears all shapes created via the Debug Control Panel.
func _clear_spawned_shapes() -> void:
	var shapes = get_tree().get_nodes_in_group("spawned_debug_shapes")
	for shape in shapes:
		shape.queue_free()
	print("Cleared all spawned debug shapes.")


## Smoothly starts or stops the truck using a Tween.
func _toggle_truck_movement() -> void:
	if _target_multiplier == 1.0:
		_target_multiplier = 0.0
		if is_instance_valid(_btn_toggle_move):
			_btn_toggle_move.text = "Start Truck"
		# Pause the wait timer if the truck is currently waiting off-screen
		if is_instance_valid(_wait_timer) and not _wait_timer.is_stopped():
			_wait_timer.paused = true
	else:
		_target_multiplier = 1.0
		if is_instance_valid(_btn_toggle_move):
			_btn_toggle_move.text = "Stop Truck"
		# Resume the wait timer if it was paused
		if is_instance_valid(_wait_timer) and _wait_timer.paused:
			_wait_timer.paused = false
	
	# Tween the speed multiplier smoothly to avoid any sudden jumping
	if _multiplier_tween:
		_multiplier_tween.kill()
	_multiplier_tween = create_tween()
	_multiplier_tween.tween_property(self, "_speed_multiplier", _target_multiplier, 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


## Randomizes the truck cabin/body texture self-modulation tint.
func _randomize_truck_color() -> void:
	if is_instance_valid(_truck_body):
		# Generate random color with decent brightness (ranges 0.2 to 1.0)
		_truck_body.self_modulate = Color(
			randf_range(0.2, 1.0),
			randf_range(0.2, 1.0),
			randf_range(0.2, 1.0),
			1.0
		)
		print("Randomized truck body tint to: ", _truck_body.self_modulate)


## Spawns or destroys a small, borderless, clickable window right next to the truck.
func _toggle_hello_button() -> void:
	if is_instance_valid(_btn_window):
		_btn_window.queue_free()
		_btn_window = null
		print("Hello button window removed.")
	else:
		_btn_window = Window.new()
		_btn_window.title = "Hello"
		_btn_window.size = Vector2i(80, 40)
		
		# Configuration: borderless (floating button look), always on top, focusable
		_btn_window.borderless = true
		_btn_window.always_on_top = false
		_btn_window.unfocusable = false
		_btn_window.transient = true
		
		var btn = Button.new()
		btn.text = "Hello!"
		btn.pressed.connect(func():
			print("Hello!")
			_randomize_truck_color()
		)
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_btn_window.add_child(btn)
		
		# Spawn relative to the main window
		_btn_window.position = _main_window.position + Vector2i(_main_window.size.x, 150)
		
		add_child(_btn_window)
		_btn_window.show()
		print("Hello button window spawned next to the truck.")
