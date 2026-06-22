extends Resource
class_name TruckBodyResource
## Data for one swappable truck body: the body sprite, a single wheel sprite reused
## across all three wheel positions, and those three positions (TruckEntity-local
## pixels). Held as base Resource inside autoloads per the class-registry rule.

@export var body_sprite: Texture2D
@export var wheel_sprite: Texture2D
@export var wheel_positions: Array[Vector2] = []  # exactly 3
