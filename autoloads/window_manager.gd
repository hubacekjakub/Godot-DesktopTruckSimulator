extends Node
## Singleton managing OS Windows, bounds mapping, and transparency.

## Far off-screen origin where windows are created invisibly, before each window
## moves itself to its real position and shows itself.
const OFFSCREEN := Vector2i(-10000, -10000)

var _target_screen_idx: int = 0
var _usable_rect: Rect2i

func _ready() -> void:
	# Pin to the primary screen. The launcher window now boots off-screen
	# (project.godot initial_position), so its current_screen is unreliable
	# for picking the monitor the truck should drive on.
	_target_screen_idx = DisplayServer.get_primary_screen()
	update_desktop_bounds()

func update_desktop_bounds() -> void:
	var screen_count = DisplayServer.get_screen_count()
	if _target_screen_idx >= screen_count:
		_target_screen_idx = DisplayServer.get_primary_screen()
	_usable_rect = DisplayServer.screen_get_usable_rect(_target_screen_idx)

func get_usable_rect() -> Rect2i:
	return _usable_rect

## Instantiates a window born invisible and off-screen, so the OS never draws it
## at a default location (the startup "flash"). The window is responsible for
## positioning and showing ITSELF (typically at the end of its own _ready), since
## only the window knows where it belongs and when it is ready to appear.
func spawn_window(scene_path: String) -> Window:
	assert(not scene_path.is_empty(), "WindowManager: spawn_window was called with an empty scene path")
	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("WindowManager: Cannot load window scene (or it is not a PackedScene): " + scene_path)
		return null
	
	var win_node = scene.instantiate() as Window
	if not win_node:
		push_error("WindowManager: Instantiated node is not a Window subclass.")
		return null

	# Every spawned window is born invisible and off-screen so the OS never
	# draws it at a default location (the startup "flash"). ABSOLUTE is required
	# or the OS ignores our position and centers the window regardless.
	win_node.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	win_node.visible = false
	win_node.position = OFFSCREEN

	get_tree().root.add_child.call_deferred(win_node)
	return win_node
