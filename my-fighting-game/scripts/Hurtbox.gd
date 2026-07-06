extends Area2D
class_name Hurtbox

## Attach to an Area2D child of the character. One per character.
## Hitboxes on collision_layer "hitbox" signal into this via area_entered.

signal hurt(hit_data: Dictionary)

## Owning character (assign in the character's _ready()).
var owner_character: Node = null

## Temporary invulnerability (e.g. during a dodge/teleport special or the
## start of a knockdown wake-up) — set true to ignore incoming hits.
var invulnerable: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# Hurtboxes live on their own layer/mask so they only ever get *entered*
	# by hitboxes, never push against other physics bodies.
	collision_layer = 2   # "hurtbox" layer
	collision_mask = 0    # hurtboxes don't need to detect anything themselves


func _on_area_entered(area: Area2D) -> void:
	if invulnerable:
		return
	if area is Hitbox:
		var hitbox := area as Hitbox
		if hitbox.owner_character == owner_character:
			return  # can't hit yourself
		if hitbox.has_hit(self):
			return  # this hitbox already connected with this hurtbox this swing
		hitbox.mark_hit(self)
		hurt.emit({
			"move": hitbox.move_data,
			"attacker": hitbox.owner_character,
			"defender": owner_character,
			"from_position": hitbox.global_position,
		})
