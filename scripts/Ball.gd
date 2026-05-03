## A simple controllable ball character
##
## This class handles player input and movement for a ball character.
## Supports both WASD and arrow key controls with screen boundary clamping.
extends CharacterBody2D

const SPEED: float = 300.0

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO

	# Handle horizontal movement (Arrow keys + WASD)
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0

	# Handle vertical movement (Arrow keys + WASD)
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0

	# Normalize diagonal movement and apply velocity
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Keep ball within screen bounds
	_clamp_to_screen_bounds()


func _clamp_to_screen_bounds() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	const MARGIN: float = 25.0

	position.x = clamp(position.x, MARGIN, screen_size.x - MARGIN)
	position.y = clamp(position.y, MARGIN, screen_size.y - MARGIN)
