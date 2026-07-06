extends Node2D
class_name FightScene

## Root script for a fight. Reads the two character names from
## MatchSetup (autoload) if present, otherwise falls back to the
## defaults below — lets this scene run standalone for quick testing
## (just press F6 on fight_scene.tscn) as well as from a real
## character-select flow.

@export var default_p1: String = "kaion"
@export var default_p2: String = "reiga"

@onready var p1: Character = $Fighters/P1
@onready var p2: Character = $Fighters/P2
@onready var camera: FightCamera = $FightCamera
@onready var hud: HUD = $HUD


func _ready() -> void:
	# TODO: once a character-select screen exists, read the chosen names
	# from an autoload (e.g. MatchSetup.p1_name / p2_name) instead of the
	# hardcoded defaults below.
	var p1_name = default_p1
	var p2_name = default_p2

	p1.player_index = 0
	p2.player_index = 1
	p1.load_character(p1_name)
	p2.load_character(p2_name)
	p1.opponent = p2
	p2.opponent = p1

	camera.set_targets(p1, p2)

	hud.bind_players(p1, p2)
	GameManager.start_match(p1, p2)
