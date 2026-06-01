extends Window
## Debug Panel UI controller.

var _truck_moving: bool = true
var _portal_open: bool = false

@onready var btn_move: Button = $Panel/Margin/VBox/BtnMove
@onready var btn_portal: Button = $Panel/Margin/VBox/BtnPortal

func _ready() -> void:
	borderless = false
	title = "Debug Control Panel"
	size = Vector2i(280, 240)
	close_requested.connect(func(): queue_free())
	SignalBus.debug_portal_toggle_requested.connect(_on_portal_toggle_received)
	show()

func _on_btn_move_pressed() -> void:
	_truck_moving = not _truck_moving
	btn_move.text = "Start Truck" if not _truck_moving else "Stop Truck"
	SignalBus.movement_toggle_requested.emit(_truck_moving)

func _on_btn_portal_pressed() -> void:
	SignalBus.debug_portal_toggle_requested.emit(not _portal_open)

func _on_portal_toggle_received(open: bool) -> void:
	_portal_open = open
	btn_portal.text = "Close Debug Portal" if _portal_open else "Open Debug Portal"

func _on_btn_color_pressed() -> void:
	SignalBus.truck_color_randomize_requested.emit()
