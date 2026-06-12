extends Window
## Secondary Viewport showing shared world and tracking Camera2D.

var _camera: Camera2D
var _tracked_win: Window = null

func _ready() -> void:
	borderless = false
	title = "Debug Shape Portal"
	size = Vector2i(450, 300)
	close_requested.connect(func(): queue_free())
	
	_camera = Camera2D.new()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camera)
	
	# Enable layers 1 (truck) and 2 (debug shapes)
	canvas_cull_mask = 1 | 2

	# Spawned hidden + off-screen by WindowManager; place and show ourselves.
	var rect := WindowManager.get_usable_rect()
	position = Vector2i(rect.position.x + 400, rect.position.y + 300)
	show()

func connect_world(source_window: Window) -> void:
	world_2d = source_window.world_2d
	_tracked_win = source_window

func _process(_delta: float) -> void:
	if is_instance_valid(_tracked_win) and is_instance_valid(_camera):
		_camera.position = Vector2(position - _tracked_win.position)
