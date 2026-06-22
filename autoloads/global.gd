extends Node
## Customization event relay. All truck movement lives in the Player autoload.

var _first_pass_customization_delay: float = 2.5

func _ready() -> void:
	SignalBus.customization_finished.connect(_on_customization_finished)

	# Trigger the one-time customization stop shortly after the first pass starts.
	if ConfigManager.get_setting("TruckSettings", "customization", false):
		get_tree().create_timer(_first_pass_customization_delay).timeout.connect(
			_on_first_pass_customization_timer_timeout)

func _on_first_pass_customization_timer_timeout() -> void:
	SignalBus.truck_movement_stop_triggered.emit()

func _on_customization_finished() -> void:
	SignalBus.truck_movement_resume_triggered.emit()

func get_truck_rect() -> Rect2i:
	return Player.get_truck_rect()
