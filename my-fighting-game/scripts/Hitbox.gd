extends Area2D
class_name Hitbox

## Attach to an Area2D child of the character (one is enough — it gets
## resized/repositioned and toggled on/off per-move rather than having a
## separate node per attack). Only enabled during a move's "active" frames.

## Owning character — set once in the character's _ready().
var owner_character: Node = null

## The MoveData currently driving this hitbox's size/offset/damage.
var move_data: MoveData = null

## Hurtboxes already hit during the current active window, so a single
## multi-frame swing doesn't hit the same opponent repeatedly.
var _already_hit: Array = []

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 1   # "hitbox" layer
	collision_mask = 2    # only looks for hurtboxes
	monitoring = false
	monitorable = true


## Call at the start of a move's active window.
func activate(data: MoveData, facing_right: bool) -> void:
	move_data = data
	_already_hit.clear()
	if _shape and _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = data.hitbox_size
	var offset = data.hitbox_offset
	if not facing_right:
		offset.x = -offset.x
	position = offset
	monitoring = true


## Call at the end of a move's active window (recovery start).
func deactivate() -> void:
	monitoring = false
	move_data = null
	_already_hit.clear()


func has_hit(hurtbox: Hurtbox) -> bool:
	return _already_hit.has(hurtbox)


func mark_hit(hurtbox: Hurtbox) -> void:
	_already_hit.append(hurtbox)
