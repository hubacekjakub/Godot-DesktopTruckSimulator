## Main scene controller for the Godot QuickStart template
##
## Handles initial scene setup and basic input management.
extends Node2D

@onready var ball: CharacterBody2D = $Ball

func _ready() -> void:
	print("Godot QuickStart Template Ready!")
	_setup_initial_ball_position()


func _setup_initial_ball_position() -> void:
	# Position ball at center of screen
	var screen_size := get_viewport().get_visible_rect().size
	ball.position = screen_size / 2.0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
