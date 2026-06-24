extends Node
## Singleton managing OS Windows, bounds mapping, and transparency.

## Far off-screen origin where windows are created invisibly
const OFFSCREEN := Vector2i(-10000, -10000)

var _target_screen_idx: int = 0
var _usable_rect: Rect2i

func _ready() -> void:
	# Pin to the primary screen — the launcher window boots off-screen
	# (project.godot initial_position), so its current_screen is unreliable.
	_target_screen_idx = DisplayServer.get_primary_screen()
	update_desktop_bounds()

# Find usable screen rect for primary screen
func update_desktop_bounds() -> void:
	var screen_count = DisplayServer.get_screen_count()
	if _target_screen_idx >= screen_count:
		_target_screen_idx = DisplayServer.get_primary_screen()
	_usable_rect = DisplayServer.screen_get_usable_rect(_target_screen_idx)

func get_usable_rect() -> Rect2i:
	return _usable_rect

func spawn_window(scene_path: String) -> Window:
	# Instantiates a window born invisible and off-screen, so the OS never draws it
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

## Returns the screen rects the truck should drive across. With multimonitor off,
## that's just the primary screen (today's behavior). With it on, every screen's
## usable rect, ordered left-to-right by virtual-desktop X. Used by Player to lay
## out one truck window per returned rect.
func get_ordered_screen_rects(multimonitor: bool) -> Array[Rect2i]:
	var data := get_ordered_screen_data(multimonitor)
	var rects: Array[Rect2i] = []
	for pair in data:
		rects.append(pair[0])
	return rects

## Like get_ordered_screen_rects but preserves the DisplayServer screen index for
## each rect. Returns Array of [Rect2i, int] pairs sorted left-to-right by X so
## callers never need to re-discover the index via a second DisplayServer loop.
func get_ordered_screen_data(multimonitor: bool) -> Array:
	if not multimonitor:
		return [[_usable_rect, _target_screen_idx]]
	var pairs: Array = []
	for i in DisplayServer.get_screen_count():
		pairs.append([DisplayServer.screen_get_usable_rect(i), i])
	pairs.sort_custom(func(a, b): return a[0].position.x < b[0].position.x)
	return pairs
