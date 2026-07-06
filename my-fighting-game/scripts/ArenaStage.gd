extends Node2D
## Attached to ArenaStage. Starts the stage theme looping on load and
## demonstrates how gameplay code should call into AudioManager for SFX.
## Wire the commented calls below into your actual hit/jump/block signals
## once the combat state machine exists.

func _ready() -> void:
	AudioManager.play_music("stage_theme", 0.8)

	# --- Example hookups (call these from your Fighter state machine) ---
	# AudioManager.play_sfx("hit_light", fighter.global_position)
	# AudioManager.play_sfx("hit_medium", fighter.global_position)
	# AudioManager.play_sfx("hit_heavy", fighter.global_position)
	# AudioManager.play_sfx("whiff", fighter.global_position)
	# AudioManager.play_sfx("block", fighter.global_position)
	# AudioManager.play_sfx("jump", fighter.global_position)
	# AudioManager.play_sfx("special_charge", fighter.global_position)
	# AudioManager.play_sfx("special_release", fighter.global_position)
	# AudioManager.play_sfx("ko_stinger", fighter.global_position)
