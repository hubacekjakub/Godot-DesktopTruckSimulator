extends Window
class_name TruckWindow
## OS window for one monitor. Clamps the shared Player.logical_x to its own
## monitor rect and slides the truck visually past the edge via the offset.

signal border_reached

@onready var _entity: TruckEntity = $TruckEntity

const PARK_TWEEN_TIME: float = 0.1

var _is_initialized: bool = false
var _monitor_rect: Rect2i
var _pass_direction: int = 1
var _border_emitted: bool = false

# Vertical "park" offset added to the window's target Y. 0 = on-screen at the
# normal driving position; +monitor_height = slid fully below the monitor (idle,
# out of the clickable area). Animated by a tween so the window only ever moves
# in small per-frame steps — which (unlike a visibility toggle or a big OFFSCREEN
# jump) does not produce the opaque flash on Windows.
var _park_offset_y: float = 0.0
var _park_tween: Tween = null
var _shown_once: bool = false

func _ready() -> void:
	assert(_entity != null, "TruckEntity child node is missing from TruckWindow scene!")
	borderless = true
	unresizable = true
	always_on_top = true
	unfocusable = true
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

func is_truck_visible() -> bool:
	return is_instance_valid(_entity) and _entity.visible

func initialize_truck(dir: int) -> void:
	_pass_direction = dir
	_border_emitted = false
	# Pre-position the entity off-screen before revealing, so the first _process
	# frame already sees it at the correct off-screen offset.
	if is_instance_valid(_entity):
		var off: int = -size.x if dir == 1 else size.x
		_entity.position.x = _entity.get_center_x() + off

	# First reveal of this window's lifetime. _process has not run yet (it is
	# gated on _shown_once), so the window is still at OFFSCREEN from _ready —
	# the single visible=true here renders its one opaque frame off-screen and
	# is invisible. Start fully parked below; the next _process places it
	# below-monitor and the tween slides it up.
	if not _shown_once:
		_park_offset_y = float(_monitor_rect.size.y)
		_shown_once = true
		visible = true

	if is_instance_valid(_entity) and _entity.has_method("reset_visual"):
		_entity.reset_visual(dir)

	# Slide up into view (small per-frame steps, no flash).
	_tween_park_offset(0.0)

func hide_window() -> void:
	# Slide the window straight down, fully below its monitor, while keeping it
	# visible + transparent. This removes it from the clickable area (no idle
	# click-block) without a visibility toggle or a huge OFFSCREEN jump — both of
	# which produce an opaque flash on Windows.
	if is_instance_valid(_entity):
		_entity.visible = false
	if _monitor_rect.size.y > 0:
		_tween_park_offset(float(_monitor_rect.size.y))
	else:
		# Boot: monitor rect not set yet. Window is already at OFFSCREEN from
		# _ready, so just keep it hidden until the first initialize_truck.
		visible = false

func _tween_park_offset(target: float) -> void:
	if _park_tween and _park_tween.is_valid():
		_park_tween.kill()
	_park_tween = create_tween()
	_park_tween.tween_property(self, "_park_offset_y", target, PARK_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(_delta: float) -> void:
	# Gated on _shown_once so the window stays untouched at OFFSCREEN until the
	# first pass reveals it. After that it runs even while the entity is hidden
	# (idle), to keep driving the park-offset tween (slide down/up).
	if not _is_initialized or not _shown_once or not is_instance_valid(_entity):
		return

	var logical_x: float = Player.get_logical_x()

	# Clamp the shared logical_x to THIS window's monitor.
	# roundi() avoids sub-pixel rendering and snaps to integer pixel positions.
	var clamped_x: int = clampi(roundi(logical_x),
		_monitor_rect.position.x,
		_monitor_rect.position.x + _monitor_rect.size.x - size.x)

	# Changing the window position every frame causes DWM compositor roundtrips.
	# Only assign when it actually changes. Y includes the park offset so the
	# slide down/up tween moves the whole window vertically.
	var new_pos := Vector2i(clamped_x, _get_target_y() + roundi(_park_offset_y))
	if position != new_pos:
		position = new_pos

	# Overflow past the clamp is pushed into the entity's local position so the
	# truck visually slides past the monitor edge while the window stays clamped.
	var offset_x: int = roundi(logical_x) - clamped_x
	_entity.position.x = _entity.get_center_x() + offset_x

	# Everything below is pass-active only — skip while the truck is hidden
	# (idle / parked below) so particles, bobbing and the border-exit signal
	# don't run between passes.
	if not _entity.visible:
		return

	var multiplier: float = Player.get_speed_multiplier()

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
