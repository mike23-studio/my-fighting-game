extends CanvasLayer
class_name HUD

## Attach to the CanvasLayer root of the HUD scene. Expects child nodes:
##   P1Health (ProgressBar), P2Health (ProgressBar)
##   P1Wins/Pip1, P1Wins/Pip2 (TextureRect or ColorRect, shown when won)
##   P2Wins/Pip1, P2Wins/Pip2
##   TimerLabel (Label)
##   RoundLabel (Label) — big center text for "ROUND 1", "K.O.!", "YOU WIN"

@onready var p1_health: ProgressBar = $P1Health
@onready var p2_health: ProgressBar = $P2Health
@onready var timer_label: Label = $TimerLabel
@onready var round_label: Label = $RoundLabel
@onready var p1_pips: Array = [$P1Wins/Pip1, $P1Wins/Pip2]
@onready var p2_pips: Array = [$P2Wins/Pip1, $P2Wins/Pip2]


func _ready() -> void:
	GameManager.timer_tick.connect(_on_timer_tick)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_over.connect(_on_round_over)
	GameManager.match_over.connect(_on_match_over)
	round_label.visible = false
	_refresh_pips()


func bind_players(p1: Character, p2: Character) -> void:
	p1.health_changed.connect(func(hp, max_hp): _set_health(p1_health, hp, max_hp))
	p2.health_changed.connect(func(hp, max_hp): _set_health(p2_health, hp, max_hp))
	_set_health(p1_health, p1.MAX_HEALTH, p1.MAX_HEALTH)
	_set_health(p2_health, p2.MAX_HEALTH, p2.MAX_HEALTH)


func _set_health(bar: ProgressBar, hp: float, max_hp: float) -> void:
	bar.max_value = max_hp
	bar.value = hp


func _on_timer_tick(seconds_left: int) -> void:
	timer_label.text = str(seconds_left)


func _on_round_started(round_number: int) -> void:
	_refresh_pips()
	_flash_round_label("ROUND %d" % round_number)


func _on_round_over(winner_index: int, _round_number: int) -> void:
	_refresh_pips()
	if winner_index == -1:
		_flash_round_label("DRAW")
	else:
		_flash_round_label("K.O.!")


func _on_match_over(winner_index: int) -> void:
	_flash_round_label("PLAYER %d WINS!" % (winner_index + 1))


func _flash_round_label(text: String) -> void:
	round_label.text = text
	round_label.visible = true
	var tween = create_tween()
	tween.tween_interval(1.4)
	tween.tween_callback(func(): round_label.visible = false)


func _refresh_pips() -> void:
	for i in range(p1_pips.size()):
		p1_pips[i].visible = i < GameManager.wins[0]
	for i in range(p2_pips.size()):
		p2_pips[i].visible = i < GameManager.wins[1]
