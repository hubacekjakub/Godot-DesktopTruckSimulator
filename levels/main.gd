extends Node2D
## Bootstrap entry point.

func _ready() -> void:
	# Main viewport setup is handled by Autoloads. 
	# We ensure the main launcher window remains minimized to prevent 
	# blocking inputs, or sizing it to 1x1.
	var win = get_window()
	win.size = Vector2i(1, 1)
	win.position = Vector2i(-100, -100)
	win.mode = Window.MODE_MINIMIZED
