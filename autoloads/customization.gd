extends Node
## Handles skin customization to the truck

var _garage_window_resource: String = "res://scenes/garage/garage_window.tscn"
var _garage_window_instance: Window = null

var current_color_index: int = 0
var current_cabin_index: int = 0
var current_wheels_index: int = 0


func _ready() -> void:
	SignalBus.truck_movement_stop_finished.connect(_on_truck_movement_stop_finished)
	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)
	SignalBus.customization_finished.connect(_on_customization_finished)

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
