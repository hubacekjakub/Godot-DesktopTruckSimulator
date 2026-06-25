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
			_popup_menu.popup(Rect2i(mouse_pos, Vector2i.ZERO))
			_popup_menu.grab_focus()

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
