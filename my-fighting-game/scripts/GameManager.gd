extends Node

## Autoload singleton — tracks round wins, round timer, and orchestrates
## resets between rounds. The fight scene connects its two Characters'
## `ko` and `health_changed` signals to this, and listens to
## `round_started` / `round_over` / `match_over` to drive UI/camera resets.

signal round_started(round_number: int)
signal round_over(winner_index: int, round_number: int)  # -1 = double KO / draw
signal match_over(winner_index: int)
signal timer_tick(seconds_left: int)

const ROUND_TIME := 99
const ROUNDS_TO_WIN := 2

var round_number: int = 0
var wins: Array = [0, 0]           # wins[0] = P1 wins, wins[1] = P2 wins
var time_left: float = ROUND_TIME
var round_active: bool = false

var players: Array = []  # populated by fight scene: [Character, Character]


func start_match(p1: Character, p2: Character) -> void:
	players = [p1, p2]
	wins = [0, 0]
	round_number = 0
	for p in players:
		if not p.ko.is_connected(_on_character_ko):
			p.ko.connect(_on_character_ko)
	start_next_round()


func start_next_round() -> void:
	round_number += 1
	time_left = ROUND_TIME
	round_active = true
	for p in players:
		p.reset_for_round()
	round_started.emit(round_number)


func _process(delta: float) -> void:
	if not round_active:
		return
	time_left -= delta
	var whole_seconds = int(ceil(time_left))
	timer_tick.emit(max(0, whole_seconds))
	if time_left <= 0.0:
		_end_round_by_timeout()


func _end_round_by_timeout() -> void:
	round_active = false
	# Whoever has more health wins on timeout; equal health = draw.
	var p1_hp = players[0].health
	var p2_hp = players[1].health
	var winner := -1
	if p1_hp > p2_hp:
		winner = 0
	elif p2_hp > p1_hp:
		winner = 1
	_resolve_round_winner(winner)


func _on_character_ko(character: Character) -> void:
	if not round_active:
		return
	round_active = false
	var loser_index = players.find(character)
	var winner_index = 1 - loser_index if loser_index != -1 else -1
	_resolve_round_winner(winner_index)


func _resolve_round_winner(winner_index: int) -> void:
	if winner_index != -1:
		wins[winner_index] += 1
	round_over.emit(winner_index, round_number)

	if wins[0] >= ROUNDS_TO_WIN or wins[1] >= ROUNDS_TO_WIN:
		var match_winner = 0 if wins[0] > wins[1] else 1
		match_over.emit(match_winner)
	else:
		await get_tree().create_timer(2.0).timeout
		start_next_round()
