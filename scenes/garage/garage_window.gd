extends Window

@export var current_color_index: int = 0

@export var cabin_colors: Array[Color] = [
	Color("#ebede9"),

	Color("#73bed3"),
	Color("#4f8fba"),
	Color("#577277"),
	Color("#3c5e8b"),
	Color("#253a5e"),

	Color("#d0da91"),
	Color("#a8ca58"),
	Color("#75a743"),
	Color("#468232"),
	Color("#25562e"),

	Color("#ebede9"),
	Color("#c7cfcc"),

	Color("#de9e41"),
	Color("#cf573c"),
	Color("#a53030"),
	Color("#752438"),
	Color("#411d31"),

	Color("#df84a5"),
	Color("#c65197"),
	Color("#a23e8c"),
	Color("#7a367b"),
	Color("#402751"),

]

# UI elements mapped to new tscn hierarchy
@onready var color_counter: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxColor/CounterColor
@onready var color_next: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxColor/NextColor
@onready var color_prev: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxOptions/HBoxColor/PreviousColor
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Confirm

func _ready() -> void:
	assert(cabin_colors.size() > 0, "garage_window: cabin_colors array must not be empty")
	# Load current setup from customization manager
	current_color_index = Customization.current_color_index
	update_ui()

	# Spawned hidden + off-screen by WindowManager; place above the truck
	# (or centered in the usable area as a fallback) and show ourselves.
	var truck_rect := Global.get_truck_rect()
	if truck_rect.size != Vector2i.ZERO:
		position_above_rect(truck_rect, 10)
	else:
		var r := WindowManager.get_usable_rect()
		position = Vector2i(r.position.x + (r.size.x - size.x) / 2,
			r.position.y + (r.size.y - size.y) / 2)
	show()

func next_color() -> void:
	if current_color_index == cabin_colors.size() - 1:
		current_color_index = 0
	else:
		current_color_index += 1
	SignalBus.customization_color_changed.emit(cabin_colors[current_color_index])
	update_ui()

func previous_color() -> void:
	if current_color_index == 0:
		current_color_index = cabin_colors.size() - 1
	else:
		current_color_index -= 1
	SignalBus.customization_color_changed.emit(cabin_colors[current_color_index])
	update_ui()

func update_ui() -> void:
	color_counter.text = "%d/%d" % [current_color_index + 1, cabin_colors.size()]

func confirm() -> void:
	# Save setup to customization manager
	Customization.current_color_index = current_color_index
	SignalBus.customization_finished.emit()

## Aligns this window horizontally centered and vertically above the target screen bounds
func position_above_rect(target_rect: Rect2i, vertical_margin: int = 10) -> void:
	# Override Godot centering behavior so it respects the coordinates we set
	initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	
	# Calculate coordinates using this window's size
	var target_x := target_rect.position.x + (target_rect.size.x - size.x) / 2
	var target_y := target_rect.position.y - size.y - vertical_margin
	
	position = Vector2i(target_x, target_y)
