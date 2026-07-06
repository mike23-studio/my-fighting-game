extends Camera2D
class_name FightCamera

## Keeps both fighters on screen: follows the midpoint between them and
## zooms out as they separate (classic fighting-game camera behavior).

@export var target_a: NodePath
@export var target_b: NodePath

@export var min_zoom: float = 1.0     # closest zoom (characters close together)
@export var max_zoom: float = 1.7     # furthest zoom (characters far apart)
@export var zoom_distance_min: float = 150.0   # px apart -> min_zoom
@export var zoom_distance_max: float = 700.0   # px apart -> max_zoom
@export var follow_speed: float = 6.0
@export var zoom_speed: float = 4.0
@export var vertical_offset: float = -80.0
@export var stage_left_bound: float = -400.0
@export var stage_right_bound: float = 400.0

var _a: Node2D
var _b: Node2D


func _ready() -> void:
	if target_a != NodePath():
		_a = get_node(target_a)
	if target_b != NodePath():
		_b = get_node(target_b)


## Call this from the fight scene once both fighters exist, instead of
## relying on NodePaths set in the editor (useful when characters are
## instanced/loaded dynamically at runtime).
func set_targets(a: Node2D, b: Node2D) -> void:
	_a = a
	_b = b


func _process(delta: float) -> void:
	if not _a or not _b:
		return

	var midpoint = (_a.global_position + _b.global_position) * 0.5
	midpoint.x = clamp(midpoint.x, stage_left_bound, stage_right_bound)
	midpoint.y += vertical_offset

	global_position = global_position.lerp(midpoint, clamp(follow_speed * delta, 0.0, 1.0))

	var distance = _a.global_position.distance_to(_b.global_position)
	var t = clamp(
		inverse_lerp(zoom_distance_min, zoom_distance_max, distance), 0.0, 1.0
	)
	var target_zoom_scalar = lerp(min_zoom, max_zoom, t)
	# Camera2D zoom < 1 = zoomed IN (closer), so invert: bigger distance -> smaller zoom value.
	var target_zoom = Vector2.ONE / target_zoom_scalar
	zoom = zoom.lerp(target_zoom, clamp(zoom_speed * delta, 0.0, 1.0))
