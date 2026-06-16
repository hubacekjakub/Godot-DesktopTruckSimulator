extends Window
class_name TruckWindow
## OS window for one monitor. Clamps the shared Player.logical_x to its own
## monitor rect and slides the truck visually past the edge via the offset.

signal border_reached

@onready var _entity: TruckEntity = $TruckEntity

var _is_initialized: bool = false
var _monitor_rect: Rect2i
var _pass_direction: int = 1
var _border_emitted: bool = false

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
	position = WindowManager.OFFSCREEN
	transparent = false
	transparent_bg = false
	show()

	# Two-frame transparency setup (Godot bug #71642 workaround)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, get_window_id())
	transparent = true
	transparent_bg = true

	# Emit signal to let DebugManager link the world_2d and track viewport
	SignalBus.truck_spawned.emit(self)

	# Mark as fully initialized
	_is_initialized = true

	# Immediately hide the window at boot until the first pass drives it
	hide_window()

## Called by Player right after spawn_window, before the first pass.
func set_monitor_rect(rect: Rect2i) -> void:
	_monitor_rect = rect

func initialize_truck(dir: int) -> void:
	# Reposition off-screen first to avoid a visual jump/flash
	position = WindowManager.OFFSCREEN
	_pass_direction = dir
	_border_emitted = false
	visible = true
	if is_instance_valid(_entity) and _entity.has_method("reset_visual"):
		_entity.reset_visual(dir)

func hide_window() -> void:
	visible = false
	if is_instance_valid(_entity):
		_entity.visible = false

func _process(_delta: float) -> void:
	# Do not update positions if window is hidden or not initialized
	if not visible or not _is_initialized or not is_instance_valid(_entity):
		return

	var logical_x: float = Player.get_logical_x()
	var multiplier: float = Player.get_speed_multiplier()

	# Clamp the shared logical_x to THIS window's monitor.
	# roundi() avoids sub-pixel rendering and snaps to integer pixel positions.
	var clamped_x: int = clampi(roundi(logical_x),
		_monitor_rect.position.x,
		_monitor_rect.position.x + _monitor_rect.size.x - size.x)

	# Changing the window position every frame causes DWM compositor roundtrips.
	# Only assign when it actually changes.
	var new_pos := Vector2i(clamped_x, _get_target_y())
	if position != new_pos:
		position = new_pos

	# Overflow past the clamp is pushed into the entity's local position so the
	# truck visually slides past the monitor edge while the window stays clamped.
	var offset_x: int = roundi(logical_x) - clamped_x
	_entity.position.x = _entity.get_center_x() + offset_x

	if _entity.has_method("set_particles_active"):
		_entity.set_particles_active(multiplier > 0.1)

	if _entity.has_method("set_bob_speed"):
		_entity.set_bob_speed(multiplier)

	# Feed the edge-fade shader global screen coordinates for THIS monitor.
	if _entity.has_method("update_shader_parameters"):
		_entity.update_shader_parameters(
			float(clamped_x),
			float(size.x),
			float(_monitor_rect.position.x),
			float(_monitor_rect.position.x + _monitor_rect.size.x)
		)

	# Emit once when the truck has fully exited this monitor in its travel direction.
	if not _border_emitted:
		var exited := (
			(_pass_direction == 1 and logical_x > _monitor_rect.position.x + _monitor_rect.size.x)
			or (_pass_direction == -1 and logical_x < _monitor_rect.position.x - size.x)
		)
		if exited:
			_border_emitted = true
			border_reached.emit()

func _get_target_y() -> int:
	var vert_offset: int = ConfigManager.get_setting("TruckSettings", "vertical_offset", -192)
	return _monitor_rect.position.y + _monitor_rect.size.y - size.y - vert_offset
