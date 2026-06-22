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
	SignalBus.truck_spawned.connect(_on_truck_spawned)
	SignalBus.truck_movement_stop_finished.connect(_on_truck_movement_stop_finished)
	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)
	SignalBus.customization_confirmed.connect(_on_customization_confirmed)
	SignalBus.customization_finished.connect(_on_customization_finished)

func get_colors() -> Array[Color]:
	return _colors

func get_bodies() -> Array[Resource]:
	return _bodies

## Pushes current customization to a freshly-spawned truck over SignalBus.
## Fires once per window; idempotent across multi-monitor spawns.
func _on_truck_spawned(_truck_window: Window) -> void:
	if current_color_index >= 0 and current_color_index < _colors.size():
		SignalBus.customization_color_changed.emit(_colors[current_color_index])
	if current_cabin_index >= 0 and current_cabin_index < _bodies.size():
		SignalBus.customization_cabin_changed.emit(_bodies[current_cabin_index])

func _on_truck_movement_stop_finished() -> void:
	if _garage_window_resource.is_empty():
		return
	_garage_window_instance = WindowManager.spawn_window(_garage_window_resource)

func _on_truck_movement_resume_triggered() -> void:
	if is_instance_valid(_garage_window_instance):
		_garage_window_instance.queue_free()
		_garage_window_instance = null

## Garage broadcasts this UP when the user confirms; Customization saves the
## selection and emits customization_finished to close the garage and resume movement.
func _on_customization_confirmed(color_idx: int, cabin_idx: int) -> void:
	current_color_index = color_idx
	current_cabin_index = cabin_idx
	SignalBus.customization_finished.emit()

func _on_customization_finished() -> void:
	if is_instance_valid(_garage_window_instance):
		_garage_window_instance.queue_free()
		_garage_window_instance = null
