extends Node2D

func _ready():
	# The main viewport must also be transparent and click-through
	var main_window = get_window()
	main_window.transparent = true
	main_window.transparent_bg = true
	main_window.borderless = true
	main_window.mouse_passthrough = true
	
	# Crucial: The default Godot clear color is opaque gray/black. We must set it to transparent!
	# RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	
	# Move the main Godot application window completely off-screen so we only see the sub-window
	main_window.position = Vector2i(-10000, -10000)
	
	# The sub-window needs its transparent flag cycled to work around Godot #71642 on Windows
	var sub_window = $Window
	sub_window.borderless = true
	sub_window.transparent = false
	sub_window.transparent_bg = false
	
	# Wait for OS windows to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	sub_window.transparent = true
	sub_window.transparent_bg = true
	
	# Center the sub-window on the screen
	var screen_size = DisplayServer.screen_get_size()
	var window_size = sub_window.size
	sub_window.position = Vector2i((screen_size.x - window_size.x) / 2, (screen_size.y - window_size.y) / 2)
