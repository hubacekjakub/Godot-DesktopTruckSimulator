extends Node
## Handles skin customization to the truck. Owns the color + body lists and the
## current selection. No persistence — selections last only for the session.

var _garage_window_resource: String = "res://scenes/garage/garage_window.tscn"
var _garage_window_instance: Window = null

# Body list. Held as base Resource (NOT TruckBodyResource) — this is an autoload and
# must not reference the class_name statically (class-registry rule).
var _bodies: Array[Resource] = [
	preload("res://resources/truck_bodies/eu_truck_basic.tres"),
	preload("res://resources/truck_bodies/us_truck_basic.tres"),
]

# Paint colors (moved out of garage_window.gd so the garage reads them from here).
var _colors: Array[Color] = [
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

var current_color_index: int = 0
var current_cabin_index: int = 0
var current_wheels_index: int = 0

func _ready() -> void:
	SignalBus.truck_movement_stop_finished.connect(_on_truck_movement_stop_finished)
	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)
	SignalBus.customization_finished.connect(_on_customization_finished)

func get_colors() -> Array[Color]:
	return _colors

func get_bodies() -> Array[Resource]:
	return _bodies

func _on_truck_movement_stop_finished() -> void:
	# First validate resource is valid
	if _garage_window_resource.is_empty():
		return

	# The garage positions itself above the truck and shows itself in its _ready.
	_garage_window_instance = WindowManager.spawn_window(_garage_window_resource)

func _on_truck_movement_resume_triggered() -> void:
	if is_instance_valid(_garage_window_instance):
		_garage_window_instance.queue_free()
		_garage_window_instance = null

func _on_customization_finished() -> void:
	if is_instance_valid(_garage_window_instance):
		_garage_window_instance.queue_free()
		_garage_window_instance = null
