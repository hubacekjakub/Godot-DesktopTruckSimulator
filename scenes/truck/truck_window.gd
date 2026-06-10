extends Window
class_name TruckWindow
## OS window container that clamps coordinates to target monitors.

@onready var _entity: TruckEntity = $TruckEntity

var _is_initialized: bool = false

func _ready() -> void:
	assert(_entity != null, "TruckEntity child node is missing from TruckWindow scene!")
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
		_entity.spawn_truck(dir, spd)

func hide_window() -> void:
	visible = false
	if is_instance_valid(_entity):
		_entity.visible = false

func _process(_delta: float) -> void:
	# Do not update positions if window is hidden or not initialized
	if not visible or not _is_initialized or not is_instance_valid(_entity):
		return

	var usable_rect: Rect2i = WindowManager.get_usable_rect()
	var logical_x: float = _entity.get_logical_x()

	# Using roundi() to avoid sub-pixel rendering issues and ensure the window snaps to integer pixel positions.
	var clamped_x: int = clampi(roundi(logical_x),
		usable_rect.position.x,
		usable_rect.position.x + usable_rect.size.x - size.x)

	# Changing windows position every frame can cause performance issues due to DWM compositor roundtrips. Change only when necessary.
	var new_pos := Vector2i(clamped_x, _entity.get_target_y())
	if position != new_pos:
		position = new_pos

	# Using roundi() to avoid sub-pixel rendering issues and ensure the window snaps to integer pixel positions.
	var offset_x: int = roundi(logical_x) - clamped_x
	_entity.position.x = _entity.get_center_x() + offset_x

	# Update edge-fade shader parameters
	if _entity.has_method("update_shader_parameters"):
		_entity.update_shader_parameters(
			float(clamped_x),
			float(size.x),
			float(usable_rect.position.x),
			float(usable_rect.position.x + usable_rect.size.x)
		)
