extends Node2D
class_name TruckEntity
## Visual sprites and animation only. All movement is owned by the Player autoload.

@onready var _truck_body: Sprite2D = $TruckBody
@onready var _truck_wheels: Sprite2D = $TruckWheels
@onready var _wheel_emitters: Array[GPUParticles2D] = [
	$WheelDust,
	$WheelDust2,
	$WheelDust3
]

var _center_x: float = 192.0
var _bob_tween: Tween

func _ready() -> void:
	_center_x = position.x

	# The ShaderMaterial is a shared sub-resource in truck_entity.tscn. Every
	# TruckWindow instance would otherwise write its own monitor's window_x /
	# screen bounds into the SAME material, so the edge-fade would be correct on
	# only one monitor. Duplicate it so each entity instance owns its material,
	# and share that single duplicate between body and wheels (as before).
	_truck_body.material = _truck_body.material.duplicate()
	_truck_wheels.material = _truck_body.material

	SignalBus.truck_color_randomize_requested.connect(_on_color_randomize_requested)

	SignalBus.customization_color_changed.connect(_on_customization_color_changed)
	SignalBus.customization_cabin_changed.connect(_on_customization_cabin_changed)
	SignalBus.customization_wheels_changed.connect(_on_customization_wheels_changed)

	_start_bobbing()

## Resets visual state at the start of a pass. Replaces the old spawn_truck();
## movement fields (logical_x, speed, target_y, _moving) now live in Player.
func reset_visual(dir: int) -> void:
	scale.x = abs(scale.x) * dir
	visible = true
	for emitter in _wheel_emitters:
		if is_instance_valid(emitter):
			emitter.emitting = true
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.set_speed_scale(1.0)

## Driven each frame by TruckWindow from Player's speed multiplier.
func set_particles_active(active: bool) -> void:
	for emitter in _wheel_emitters:
		if is_instance_valid(emitter):
			emitter.emitting = active

func set_bob_speed(scale: float) -> void:
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.set_speed_scale(scale)

func get_center_x() -> float:
	return _center_x

func get_truck_body_material() -> ShaderMaterial:
	return _truck_body.material as ShaderMaterial

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
