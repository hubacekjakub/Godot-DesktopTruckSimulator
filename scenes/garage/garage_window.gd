extends Window

var _colors: Array[String] = []
var _cabin_keys: Array[String] = []
var _cabin_values: Array[Resource] = []

var _current_color_index: int = 0
var _current_cabin_index: int = 0

@onready var color_counter: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxColor/CounterColor
@onready var cabin_counter: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxCabin/CounterCabin

func _ready() -> void:
	_colors = Customization.get_available_colors()
	var bodies: Dictionary = Customization.get_bodies()
	# .keys() and .values() return untyped Array — use .assign() to populate typed arrays
	_cabin_keys.assign(bodies.keys())
	_cabin_values.assign(bodies.values())
	assert(_colors.size() > 0, "garage_window: color list must not be empty")
	assert(_cabin_keys.size() > 0, "garage_window: cabin list must not be empty")

	_current_color_index = max(0, _colors.find(Customization.current_color_id))
	_current_cabin_index = max(0, _cabin_keys.find(Customization.current_cabin_id))
	update_ui()

	# Emit customization_finished if the user closes via the OS X button, so the
	# truck resumes instead of staying stopped forever (deadlock prevention).
	close_requested.connect(func(): SignalBus.customization_finished.emit())

	var truck_rect := Global.get_truck_rect()
	if truck_rect.size != Vector2i.ZERO:
		position_above_rect(truck_rect, -100)
	else:
		var r := WindowManager.get_usable_rect()
		position = Vector2i(r.position.x + (r.size.x - size.x) / 2,
			r.position.y + (r.size.y - size.y) / 2)
	show()

func next_color() -> void:
	_current_color_index = (_current_color_index + 1) % _colors.size()
	SignalBus.customization_color_changed.emit(Color(_colors[_current_color_index]))
	update_ui()

func previous_color() -> void:
	_current_color_index = (_current_color_index - 1 + _colors.size()) % _colors.size()
	SignalBus.customization_color_changed.emit(Color(_colors[_current_color_index]))
	update_ui()

func next_cabin() -> void:
	_current_cabin_index = (_current_cabin_index + 1) % _cabin_keys.size()
	SignalBus.customization_cabin_changed.emit(_cabin_values[_current_cabin_index])
	update_ui()

func previous_cabin() -> void:
	_current_cabin_index = (_current_cabin_index - 1 + _cabin_keys.size()) % _cabin_keys.size()
	SignalBus.customization_cabin_changed.emit(_cabin_values[_current_cabin_index])
	update_ui()

func update_ui() -> void:
	color_counter.text = "%d/%d" % [_current_color_index + 1, _colors.size()]
	cabin_counter.text = "%d/%d" % [_current_cabin_index + 1, _cabin_keys.size()]

func confirm() -> void:
	SignalBus.customization_confirmed.emit(_colors[_current_color_index], _cabin_keys[_current_cabin_index])

func position_above_rect(target_rect: Rect2i, vertical_margin: int = 10) -> void:
	initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	var target_x := target_rect.position.x + (target_rect.size.x - size.x) / 2
	var full_offset := size.y + vertical_margin
	var target_y := target_rect.position.y - full_offset
	position = Vector2i(target_x, target_y)
