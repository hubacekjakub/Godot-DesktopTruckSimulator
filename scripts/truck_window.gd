extends Window

var speed: float = 150.0
var current_x: float = 0.0

func _ready():
	# Ensure the window is configured correctly for transparency
	borderless = true
	always_on_top = true
	mouse_passthrough = true
	
	# With Godot 4.3+ on OpenGL, we still might need the cycle trick, but
	# let's try just setting it normally first since OpenGL is robust.
	transparent = false
	transparent_bg = false
	await get_tree().process_frame
	await get_tree().process_frame
	transparent = true
	transparent_bg = true
	
	# Strip theme background just in case
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("embedded_border", empty_style)
	add_theme_stylebox_override("embedded_unfocused_border", empty_style)
	add_theme_stylebox_override("panel", empty_style)
	
	# Get the screen size to spawn the truck at the bottom left
	var screen_size = DisplayServer.screen_get_size()
	
	# Position at bottom of the screen, start off-screen to the left
	# Let's say 40 pixels above the absolute bottom to account for taskbar
	var taskbar_margin = 40
	var start_y = screen_size.y - size.y - taskbar_margin
	current_x = -size.x
	position = Vector2i(int(current_x), start_y)

func _process(delta: float):
	# Move the window to the right smoothly
	current_x += speed * delta
	position.x = int(current_x)
	
	# If the window has moved completely off the right side of the screen, destroy it
	var screen_size = DisplayServer.screen_get_size()
	if position.x > screen_size.x:
		queue_free()
