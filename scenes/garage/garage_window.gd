extends Window

var _colors: Array[Color] = []
var _bodies: Array[Resource] = []

var current_color_index: int = 0
var current_cabin_index: int = 0

@onready var color_counter: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxColor/CounterColor
@onready var cabin_counter: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxCabin/CounterCabin

func _ready() -> void:
	_colors = Customization.get_colors()
	_bodies = Customization.get_bodies()
	assert(_colors.size() > 0, "garage_window: color list must not be empty")
	assert(_bodies.size() > 0, "garage_window: body list must not be empty")
	current_color_index = Customization.current_color_index
	current_cabin_index = Customization.current_cabin_index
	update_ui()

	var truck_rect := Global.get_truck_rect()
	if truck_rect.size != Vector2i.ZERO:
		position_above_rect(truck_rect, 10)
	else:
		var r := WindowManager.get_usable_rect()
		position = Vector2i(r.position.x + (r.size.x - size.x) / 2,
			r.position.y + (r.size.y - size.y) / 2)
	show()

func next_color() -> void:
	current_color_index = (current_color_index + 1) % _colors.size()
	SignalBus.customization_color_changed.emit(_colors[current_color_index])
	update_ui()

func previous_color() -> void:
	current_color_index = (current_color_index - 1 + _colors.size()) % _colors.size()
	SignalBus.customization_color_changed.emit(_colors[current_color_index])
	update_ui()

func next_cabin() -> void:
	current_cabin_index = (current_cabin_index + 1) % _bodies.size()
	SignalBus.customization_cabin_changed.emit(_bodies[current_cabin_index])
	update_ui()

func previous_cabin() -> void:
	current_cabin_index = (current_cabin_index - 1 + _bodies.size()) % _bodies.size()
	SignalBus.customization_cabin_changed.emit(_bodies[current_cabin_index])
	update_ui()

func update_ui() -> void:
	color_counter.text = "%d/%d" % [current_color_index + 1, _colors.size()]
	cabin_counter.text = "%d/%d" % [current_cabin_index + 1, _bodies.size()]

func confirm() -> void:
	SignalBus.customization_confirmed.emit(current_color_index, current_cabin_index)

func position_above_rect(target_rect: Rect2i, vertical_margin: int = 10) -> void:
	initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	var target_x := target_rect.position.x + (target_rect.size.x - size.x) / 2
	var target_y := target_rect.position.y - size.y - vertical_margin
	position = Vector2i(target_x, target_y)
