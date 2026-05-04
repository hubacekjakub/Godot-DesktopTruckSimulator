extends Window
## A self-contained transparent truck window that drives across the bottom
## of the screen from left to right and cleans itself up when done.
## Intended to be instantiated by the Manager (main.gd) via PackedScene.
##
## NOTE: Currently unused — Main.tscn uses a static $Window node instead.
## This scene will be used once we implement the 10-second spawner.

@export var speed: float = 150.0

var _current_x: float = 0.0

func _ready():
	# Window flags
	borderless = true
	always_on_top = true
	mouse_passthrough = true

	# Workaround for Godot bug #71642 on Windows:
	# Cycle transparency off→on after 2 frames so the OS window handle
	# is fully constructed before we request alpha compositing from DWM.
	transparent = false
	transparent_bg = false
	await get_tree().process_frame
	await get_tree().process_frame
	transparent = true
	transparent_bg = true

	# Strip Godot's default UI panel (draws a gray background)
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("embedded_border", empty_style)
	add_theme_stylebox_override("embedded_unfocused_border", empty_style)
	add_theme_stylebox_override("panel", empty_style)

	# Position at bottom of the screen, starting off-screen to the left
	var screen_size = DisplayServer.screen_get_size()
	var taskbar_margin = 80
	_current_x = float(-size.x)
	position = Vector2i(int(_current_x), screen_size.y - size.y - taskbar_margin)

func _process(delta: float):
	_current_x += speed * delta
	position.x = int(_current_x)

	# Self-destruct once fully off-screen on the right
	if position.x > DisplayServer.screen_get_size().x:
		queue_free()
