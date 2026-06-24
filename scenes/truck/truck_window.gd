extends Window
class_name TruckWindow
## OS window for one monitor. Clamps the shared Player.logical_x to its own
## monitor rect and slides the truck visually past the edge via the offset.

signal border_reached

@onready var _entity: TruckEntity = $TruckEntity

const PARK_TWEEN_TIME: float = 0.2

var _monitor_rect: Rect2i
var _screen_index: int = 0
var _scale_factor: float = 1.0
var _pass_direction: int = 1
var _border_emitted: bool = false

# Vertical "park" offset added to the window's target Y. 0 = on-screen at the
# normal driving position; +monitor_height = slid fully below the monitor (idle,
# out of the clickable area). Animated by a tween so the window only ever moves
# in small per-frame steps — which (unlike a visibility toggle or a big OFFSCREEN
# jump) does not produce the opaque flash on Windows.
var _park_offset_y: float = 0.0
var _park_tween: Tween = null
var _revealed: bool = false

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

	_scale_factor = _detect_monitor_scale()
	if _scale_factor != 1.0:
		_apply_display_scale()
	_entity.init_shader_constants(float(size.x), float(_monitor_rect.position.x), float(_monitor_rect.end.x))

	# Emit signal to let DebugManager link the world_2d and track viewport
	SignalBus.truck_spawned.emit(self)

	# Immediately hide the window at boot until the first pass drives it
	hide_window()

## Called by Player right after spawn_window, before the first pass.
func set_monitor_rect(rect: Rect2i, screen_index: int) -> void:
	_monitor_rect = rect
	_screen_index = screen_index

func _detect_monitor_scale() -> float:
	var s := DisplayServer.screen_get_scale(_screen_index)
	if OS.is_debug_build():
		print("TruckWindow: screen %d scale=%.2f" % [_screen_index, s])
	return s * ConfigManager.get_setting("TruckSettings", "truck_scale_multiplier", 1.0)

func _apply_display_scale() -> void:
	size = Vector2i(roundi(size.x * _scale_factor), roundi(size.y * _scale_factor))
	_entity.apply_display_scale(_scale_factor)

func is_truck_visible() -> bool:
	return is_instance_valid(_entity) and _entity.visible

func initialize_truck(dir: int) -> void:
	_pass_direction = dir
	_border_emitted = false

	# Pre-position the entity off-screen before revealing (so the first _process
	# frame already sees the correct off-screen offset) and reset its visual state.
	if is_instance_valid(_entity):
		var off: int = -size.x if dir == 1 else size.x
		_entity.position.x = _entity.get_center_x() + off
		_entity.reset_visual(dir)

	# First reveal of this window's lifetime. _process has not run yet (it is
	# gated on _revealed), so the window is still at OFFSCREEN from _ready —
	# the single visible=true here renders its one opaque frame off-screen and
	# is invisible. This is the ONLY visibility toggle in the window's life: a
	# false->true toggle flashes an opaque frame at an OS-chosen position
	# regardless of where we set `position`, so after this we never hide it again
	# and rely purely on the park-offset slide.
	if not _revealed:
		_park_offset_y = float(_monitor_rect.size.y)
		_revealed = true
		visible = true

	_slide_up()

func hide_window() -> void:
	# Hide the truck and slide the window straight down, fully below its monitor.
	# The slide is a tween (small per-frame steps) so it never produces the opaque
	# flash that a visibility toggle or a big OFFSCREEN jump would.
	if is_instance_valid(_entity):
		_entity.visible = false
	if _monitor_rect.size.y > 0:
		_slide_down()
	else:
		# Boot: monitor rect not set yet. Window is already at OFFSCREEN from
		# _ready, so just keep it hidden until the first initialize_truck.
		visible = false

## Reveal: tween the park offset back to 0 so the window slides up into view.
## The window stays visible throughout (see initialize_truck — we never toggle
## visibility after the first reveal, because that flashes).
func _slide_up() -> void:
	_start_park_tween(0.0)

## Hide: tween the park offset down until the window is fully below the monitor.
## The window stays visible+transparent (parked below, out of the clickable area)
## — toggling visibility to release it from the compositor reintroduces the flash.
func _slide_down() -> void:
	_start_park_tween(float(_monitor_rect.size.y))

func _start_park_tween(target: float) -> void:
	if _park_tween and _park_tween.is_valid():
		_park_tween.kill()
	_park_tween = create_tween()
	_park_tween.tween_property(self, "_park_offset_y", target, PARK_TWEEN_TIME) \
		.set_trans(Tween.TRANS_LINEAR)

func _process(_delta: float) -> void:
	# Gated on _revealed so the window stays untouched at OFFSCREEN until the
	# first pass reveals it (which also implies _ready's transparency setup is
	# done). After that it runs even while the entity is hidden (idle), to keep
	# driving the park-offset tween (slide down/up).
	if not _revealed or not is_instance_valid(_entity):
		return

	var logical_x: float = Player.get_logical_x()

	# Clamp the shared logical_x to THIS window's monitor.
	# roundi() avoids sub-pixel rendering and snaps to integer pixel positions.
	var clamped_x: int = clampi(roundi(logical_x), _monitor_rect.position.x, _monitor_rect.end.x - size.x)

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
	_entity.set_particles_active(multiplier > 0.1)
	_entity.set_bob_speed(multiplier)

	# Feed the edge-fade shader the current window X (one float, per-frame).
	_entity.update_shader_window_x(float(clamped_x))

	# Emit once when the truck has fully exited this monitor in its travel direction.
	if not _border_emitted:
		var exited := (
			(_pass_direction == 1 and logical_x > _monitor_rect.end.x)
			or (_pass_direction == -1 and logical_x < _monitor_rect.position.x - size.x)
		)
		if exited:
			_border_emitted = true
			border_reached.emit()

func _get_target_y() -> int:
	# vertical_offset is calibrated for scale 1.0; multiply so the parking
	# position stays proportional on high-DPI monitors
	var vert_offset: int = roundi(
		ConfigManager.get_setting("TruckSettings", "vertical_offset", -192) * _scale_factor)
	return _monitor_rect.position.y + _monitor_rect.size.y - size.y - vert_offset
