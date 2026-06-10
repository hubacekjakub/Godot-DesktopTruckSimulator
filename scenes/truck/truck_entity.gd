extends Node2D
class_name TruckEntity
## Visual sprites, animation state, and physics variables.

@onready var _truck_body: Sprite2D = $TruckBody
@onready var _truck_wheels: Sprite2D = $TruckWheels
@onready var _wheel_emitters: Array[GPUParticles2D] = [
	$WheelDust,
	$WheelDust2,
	$WheelDust3
]

var _target_y: int = 0
var _speed: float = 0.0
var _direction: int = 1
var _moving: bool = false
var _bob_tween: Tween

# Speed multiplier for gradual starting/stopping
var _speed_multiplier: float = 1.0
var _target_multiplier: float = 1.0
var _multiplier_tween: Tween = null

func _ready() -> void:
	# Process before TruckWindow so position.x is current when the portal reads it
	process_priority = -1

	_truck_wheels.material = _truck_body.material

	SignalBus.truck_movement_stop_triggered.connect(_on_truck_movement_stop_triggered)
	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)
	
	SignalBus.truck_color_randomize_requested.connect(_on_color_randomize_requested)
	
	SignalBus.customization_color_changed.connect(_on_customization_color_changed)
	SignalBus.customization_cabin_changed.connect(_on_customization_cabin_changed)
	SignalBus.customization_wheels_changed.connect(_on_customization_wheels_changed)

	_start_bobbing()

func _process(delta: float) -> void:
	if not _moving:
		return

	position.x += _speed * _direction * _speed_multiplier * delta

	# Update particle emitters and bobbing tween based on speed multiplier
	for emitter in _wheel_emitters:
		if is_instance_valid(emitter):
			emitter.emitting = _moving and (_speed_multiplier > 0.1)

	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.set_speed_scale(_speed_multiplier)

func is_moving() -> bool:
	return _moving

func get_target_y() -> int:
	return _target_y

func get_truck_body_material() -> ShaderMaterial:
	return _truck_body.material as ShaderMaterial

func spawn_truck(dir: int, spd: float, spawn_x: float, target_y: int) -> void:
	_direction = dir
	_speed = spd
	_moving = true

	# Reset multiplier to full speed on fresh spawn
	_speed_multiplier = 1.0
	if _multiplier_tween and _multiplier_tween.is_valid():
		_multiplier_tween.kill()

	_target_y = target_y
	position.x = spawn_x
	# Keep entity at vertical center of the window
	position.y = get_parent().size.y / 2.0

	scale.x = abs(scale.x) * _direction
	visible = true
	for emitter in _wheel_emitters:
		if is_instance_valid(emitter):
			emitter.emitting = true

func stop_moving() -> void:
	_moving = false

func update_shader_parameters(window_x: float, window_width: float, screen_left: float, screen_right: float) -> void:
	var mat := get_truck_body_material()
	if mat:
		mat.set_shader_parameter("window_x", window_x)
		mat.set_shader_parameter("window_width", window_width)
		mat.set_shader_parameter("screen_left", screen_left)
		mat.set_shader_parameter("screen_right", screen_right)

		# Set dynamic fade bounds configured next to EXE
		var fade_margin: float = ConfigManager.get_setting("ShaderSettings", "fade_margin", 100.0)
		mat.set_shader_parameter("fade_margin", fade_margin)

func _on_truck_movement_stop_triggered() -> void:
	_target_multiplier = 0.0

	# Tween the speed multiplier smoothly to avoid any sudden jumping
	if _multiplier_tween and _multiplier_tween.is_valid():
		_multiplier_tween.kill()
	_multiplier_tween = create_tween()
	_multiplier_tween.tween_property(self , "_speed_multiplier", _target_multiplier, 2.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	_multiplier_tween.finished.connect(SignalBus.truck_movement_stop_finished.emit)

func _on_truck_movement_resume_triggered() -> void:
	_target_multiplier = 1.0

	# Tween the speed multiplier smoothly to avoid any sudden jumping
	if _multiplier_tween and _multiplier_tween.is_valid():
		_multiplier_tween.kill()
	_multiplier_tween = create_tween()
	_multiplier_tween.tween_property(self , "_speed_multiplier", _target_multiplier, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_multiplier_tween.finished.connect(SignalBus.truck_movement_resume_finished.emit)

func _on_color_randomize_requested() -> void:
	if is_instance_valid(_truck_body):
		var mat := get_truck_body_material()
		if mat:
			var new_color = Color(
				randf_range(0.2, 1.0),
				randf_range(0.2, 1.0),
				randf_range(0.2, 1.0),
				1.0
			)
			mat.set_shader_parameter("paint_color", new_color)

func _start_bobbing() -> void:    
	_bob_tween = create_tween().set_loops()
	
	# Tween a custom method instead of the property directly
	_bob_tween.tween_method(_update_bob_position, 0.0, -4.0, 0.4).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_method(_update_bob_position, -4.0, 0.0, 0.1).set_trans(Tween.TRANS_SINE)

func _update_bob_position(value: float) -> void:
	# round() forces the truck to lock strictly to whole pixel boundaries
	_truck_body.position.y = round(value)

func _on_customization_color_changed(color: Color) -> void:
	var mat := get_truck_body_material()
	if mat:
		mat.set_shader_parameter("paint_color", color)

func _on_customization_cabin_changed(cabin_id: int) -> void:
	#TODO: Change the cabin
	pass

func _on_customization_wheels_changed(wheel_id: int) -> void:
	#TODO: Change the wheels
	pass
