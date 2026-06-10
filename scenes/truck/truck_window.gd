extends Window
class_name TruckWindow
## OS window that acts as a camera portal into the truck's world.
## Clamps to the usable screen rect while the Camera2D tracks the truck.

@onready var _entity: TruckEntity = $TruckEntity
@onready var _camera: Camera2D = $Camera2D

var _half_width: int = 0
var _half_height: int = 0
var _is_initialized: bool = false

func _ready() -> void:
	assert(_entity != null, "TruckEntity child node is missing from TruckWindow scene!")
	assert(_camera != null, "Camera2D child node is missing from TruckWindow scene!")

	_half_width = size.x / 2
	_half_height = size.y / 2

	borderless = true
	unresizable = true
	always_on_top = true
	unfocusable = true
	mouse_passthrough = true
	gui_embed_subwindows = false
	canvas_cull_mask = 1 # Visual elements only

	# Window starts off-screen to avoid transparency flash
	position = Vector2i(-10000, -10000)
	transparent = false
	transparent_bg = false
	show()

	# Two-frame transparency setup
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, get_window_id())
	transparent = true
	transparent_bg = true

	# Emit signal to let DebugManager link the world_2d and track viewport
	SignalBus.truck_spawned.emit(self )

	# Mark as fully initialized
	_is_initialized = true

	# Immediately hide the window at boot until first pass is started
	hide_window()

func initialize_truck(dir: int, spd: float) -> void:
	# Reposition off-screen first to avoid visual jump/flash
	position = Vector2i(-10000, -10000)
	visible = true

	if is_instance_valid(_entity) and _entity.has_method("spawn_truck"):
		var rect: Rect2i = WindowManager.get_usable_rect()
		var vert_offset: int = ConfigManager.get_setting("TruckSettings", "vertical_offset", -192)
		var target_y: int = rect.position.y + rect.size.y - size.y - vert_offset

		# Compute spawn position in world-space (maps to screen-space)
		var spawn_x: float
		if dir == 1:
			spawn_x = float(rect.position.x - _half_width)
		else:
			spawn_x = float(rect.position.x + rect.size.x + _half_width)

		_entity.spawn_truck(dir, spd, spawn_x, target_y)

func hide_window() -> void:
	visible = false
	if is_instance_valid(_entity):
		_entity.visible = false

func _process(_delta: float) -> void:
	# Do not update positions if window is hidden or not initialized
	if not visible or not _is_initialized or not is_instance_valid(_entity):
		return

	var usable_rect: Rect2i = WindowManager.get_usable_rect()
	var entity_x: float = _entity.position.x

	# Where we WANT the window on screen (centered on truck)
	var desired_x: int = int(entity_x) - _half_width

	# Clamp portal to usable screen bounds
	var clamped_x: int = clampi(desired_x,
		usable_rect.position.x,
		usable_rect.position.x + usable_rect.size.x - size.x)

	# Position the OS window
	position = Vector2i(clamped_x, _entity.get_target_y())

	# Camera shows the world region corresponding to the window's screen position.
	# The entity slides through this view when the window is clamped at edges.
	_camera.position.x = float(clamped_x + _half_width)
	_camera.position.y = _entity.position.y

	# Check if the truck has exited the usable screen area
	if _entity.is_moving():
		var dir: int = 1 if _entity.scale.x > 0 else -1
		if dir == 1 and entity_x > usable_rect.position.x + usable_rect.size.x + _half_width:
			_entity.stop_moving()
			SignalBus.truck_pass_completed.emit()
		elif dir == -1 and entity_x < usable_rect.position.x - _half_width:
			_entity.stop_moving()
			SignalBus.truck_pass_completed.emit()

	# Update edge-fade shader parameters
	if _entity.has_method("update_shader_parameters"):
		_entity.update_shader_parameters(
			float(clamped_x),
			float(size.x),
			float(usable_rect.position.x),
			float(usable_rect.position.x + usable_rect.size.x)
		)
