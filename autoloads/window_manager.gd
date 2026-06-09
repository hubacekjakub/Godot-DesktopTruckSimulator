extends Node
## Singleton managing OS Windows, bounds mapping, and transparency.

var _target_screen_idx: int = 0
var _usable_rect: Rect2i

func _ready() -> void:
	# Track the startup screen of the primary window
	_target_screen_idx = get_window().current_screen
	update_desktop_bounds()

func update_desktop_bounds() -> void:
	var screen_count = DisplayServer.get_screen_count()
	if _target_screen_idx >= screen_count:
		_target_screen_idx = DisplayServer.get_primary_screen()
	_usable_rect = DisplayServer.screen_get_usable_rect(_target_screen_idx)

func get_usable_rect() -> Rect2i:
	return _usable_rect

## Instantiates and configures a new OS window
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
		
	get_tree().root.add_child.call_deferred(win_node)
	return win_node
