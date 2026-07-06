extends Resource
class_name MoveData

## Data-driven definition of a single attack or special move.
## Create instances as .tres files in resources/moves/ and assign in the
## Inspector — tune numbers there without touching code.

## Display name shown in debug/UI.
@export var move_name: String = "Move"

## Animation name this move plays (must exist in the character's SpriteFrames).
@export var animation: String = "punch"

## Frame data (in engine frames @ 60fps, matching the interpolated sprite counts).
@export var startup: int = 4       # frames before the hitbox becomes active
@export var active: int = 3        # frames the hitbox can actually hit
@export var recovery: int = 8      # frames after active where character is vulnerable

## Damage & stun.
@export var damage: float = 8.0
@export var hitstun: float = 0.35   # seconds opponent is frozen on hit
@export var blockstun: float = 0.18 # seconds opponent is frozen on block

## Knockback applied to the opponent, in px/sec (x = horizontal push, y = negative is up).
@export var knockback: Vector2 = Vector2(220, -40)

## Whether this move can be blocked while crouching / standing.
@export var high_hitting: bool = false   # must be blocked standing
@export var low_hitting: bool = false    # must be blocked crouching

## Marks a move as a "special" — used for input-buffer motion matching and
## meter/resource costs later if you add them.
@export var is_special: bool = false

## Optional projectile scene to spawn on the active frame (for beam/ki-blast
## style specials like Homing Wave / Spiral Sphere). Leave null for melee.
@export var projectile_scene: PackedScene = null

## Hitbox size/offset relative to the character origin, in pixels.
@export var hitbox_size: Vector2 = Vector2(40, 30)
@export var hitbox_offset: Vector2 = Vector2(30, -50)
