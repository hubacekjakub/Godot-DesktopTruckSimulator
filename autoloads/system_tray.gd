extends Node
## System tray icon with visibility toggle, customization access, and quit.
## Owns the StatusIndicator and PopupMenu. Communicates only through SignalBus.

const MENU_VISIBLE: int = 0
const MENU_CUSTOMIZE: int = 1
const MENU_JOBS: int = 2
const MENU_QUIT: int = 3

var _status_indicator: StatusIndicator
var _popup_menu: PopupMenu
var _is_visible: bool = true

func _ready() -> void:
	_popup_menu = PopupMenu.new()
	_popup_menu.add_check_item("Visible", MENU_VISIBLE)
	_popup_menu.add_separator()
	_popup_menu.add_item("Customize", MENU_CUSTOMIZE)
	_popup_menu.add_item("Jobs", MENU_JOBS)
	_popup_menu.add_separator()
	_popup_menu.add_item("Quit", MENU_QUIT)

	# Visible starts checked; Jobs is always disabled.
	_popup_menu.set_item_checked(_popup_menu.get_item_index(MENU_VISIBLE), true)
	_popup_menu.set_item_disabled(_popup_menu.get_item_index(MENU_JOBS), true)

	_popup_menu.id_pressed.connect(_on_menu_id_pressed)
	_popup_menu.focus_exited.connect(_popup_menu.hide)
	add_child(_popup_menu)

	_status_indicator = StatusIndicator.new()
	add_child(_status_indicator)
	_status_indicator.icon = load("res://icon.svg")
	_status_indicator.tooltip = "Desktop Truck Simulator"
	_status_indicator.pressed.connect(_on_status_indicator_pressed)
	_status_indicator.visible = true

func _on_status_indicator_pressed(mouse_button: MouseButton, mouse_pos: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_RIGHT:
		if _popup_menu.visible:
			_popup_menu.hide()
		else:
			get_tree().root.grab_focus()
			_popup_menu.popup(Rect2i(mouse_pos, Vector2i.ZERO))
			# popup() clamps the menu into the screen of its parent visible
			# window — the launcher parked at WindowManager.OFFSCREEN — which
			# drags it onto the leftmost monitor (Popup::_popup_adjust_rect).
			# Re-assert the position now that the menu is visible: assigning it
			# directly bypasses that clamp.
			_popup_menu.position = _menu_position(mouse_pos)
			_popup_menu.grab_focus()

## Menu position kept inside the usable rect of the clicked screen, so the
## menu opens above the taskbar instead of running past the screen edge.
func _menu_position(click_pos: Vector2i) -> Vector2i:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(_screen_containing(click_pos))
	return click_pos.clamp(usable.position, usable.end - _popup_menu.size)

## Screen whose full rect (taskbar included) contains the point.
func _screen_containing(point: Vector2i) -> int:
	for i in DisplayServer.get_screen_count():
		if Rect2i(DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i)).has_point(point):
			return i
	return DisplayServer.get_primary_screen()

func _on_menu_id_pressed(id: int) -> void:
	match id:
		MENU_VISIBLE:
			_toggle_visibility()
		MENU_CUSTOMIZE:
			SignalBus.tray_customization_requested.emit()
		MENU_QUIT:
			SignalBus.tray_quit_requested.emit()

func _toggle_visibility() -> void:
	_is_visible = not _is_visible
	var idx: int = _popup_menu.get_item_index(MENU_VISIBLE)
	_popup_menu.set_item_checked(idx, _is_visible)

	# Disable Customize when hidden; re-enable when visible.
	var customize_idx: int = _popup_menu.get_item_index(MENU_CUSTOMIZE)
	_popup_menu.set_item_disabled(customize_idx, not _is_visible)

	SignalBus.tray_visibility_changed.emit(_is_visible)
