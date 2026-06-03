extends Node
## Handles skin customization to the truck

var _garage_window_resource: String = "res://scenes/garage/garage_window.tscn"
var _garage_window_instance: Window = null

func _ready() -> void:

	SignalBus.truck_movement_stop_finished.connect(_on_truck_movement_stop_finished)
	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)

func _on_truck_movement_stop_finished() -> void:

	# First validate resource is valid
	if _garage_window_resource.is_empty():
		return

	_garage_window_instance = WindowManager.spawn_window(_garage_window_resource)



	# Spawn customization window after stopping is fully completed
	pass

func _on_truck_movement_resume_triggered() -> void:
	# Remove and clear customization window when truck starts moving again
	pass
