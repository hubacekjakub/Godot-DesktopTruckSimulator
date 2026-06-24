extends Node2D
class_name TruckEntity
## Visual sprites and animation only. All movement is owned by the Player autoload.

@onready var _truck_body: Sprite2D = $TruckBody
@onready var _wheel_sprites: Array[Sprite2D] = [
	$Wheels/Wheel1,
	$Wheels/Wheel2,
	$Wheels/Wheel3
]
@onready var _wheel_emitters: Array[GPUParticles2D] = [
	$Wheels/Wheel1/WheelDust,
	$Wheels/Wheel2/WheelDust2,
	$Wheels/Wheel3/WheelDust3
]

var _center_x: float = 192.0
var _display_scale: float = 1.0
var _bob_tween: Tween

func _ready() -> void:
	_center_x = position.x

	# The ShaderMaterial is a shared sub-resource in truck_entity.tscn. Each
	# per-monitor TruckWindow instance would otherwise write its own monitor's
	# window_x / screen bounds into the SAME material, so the edge-fade would be
	# correct on only one monitor. Duplicate it so each entity instance owns its
	# material, and share that one duplicate across the body and all three wheels.
	_truck_body.material = _truck_body.material.duplicate()
	for wheel in _wheel_sprites:
		if is_instance_valid(wheel):
			wheel.material = _truck_body.material

	SignalBus.truck_color_randomize_requested.connect(_on_color_randomize_requested)

	SignalBus.customization_color_changed.connect(_on_customization_color_changed)
	SignalBus.customization_cabin_changed.connect(_on_customization_cabin_changed)
	SignalBus.customization_wheels_changed.connect(_on_customization_wheels_changed)

	_start_bobbing()

## Resets visual state at the start of a pass. Movement fields live in Player.
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

func apply_display_scale(s: float) -> void:
	scale = Vector2(s, s)
	position *= s
	_center_x = position.x
	_display_scale = s

func init_shader_constants(window_width: float, screen_left: float, screen_right: float) -> void:
	var mat := get_truck_body_material()
	if not mat:
		return
	var fade_margin: float = ConfigManager.get_setting(
		"ShaderSettings", "fade_margin", 100.0) * _display_scale
	mat.set_shader_parameter("window_width", window_width)
	mat.set_shader_parameter("screen_left", screen_left)
	mat.set_shader_parameter("screen_right", screen_right)
	mat.set_shader_parameter("fade_margin", fade_margin)

func update_shader_window_x(window_x: float) -> void:
	var mat := get_truck_body_material()
	if mat:
		mat.set_shader_parameter("window_x", window_x)

## Applies a TruckBodyResource: body texture + the three wheel sprites/positions.
## Param is base Resource because the emitter routes through SignalBus (an autoload
## that must not reference the TruckBodyResource class_name); cast here, where it is
## allowed, and bail out safely if the payload is not a TruckBodyResource.
func _on_customization_cabin_changed(body: Resource) -> void:
	var truck_body := body as TruckBodyResource
	if truck_body == null:
		return
	assert(truck_body.wheel_positions.size() == 3,
		"TruckBodyResource must define exactly 3 wheel positions")
	_truck_body.texture = truck_body.body_sprite
	for i in _wheel_sprites.size():
		if is_instance_valid(_wheel_sprites[i]):
			_wheel_sprites[i].texture = truck_body.wheel_sprite
			_wheel_sprites[i].position = truck_body.wheel_positions[i]

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

func _on_customization_wheels_changed(wheel_id: int) -> void:
	#TODO: Change the wheels (out of scope — wheels come bundled in the body)
	pass
