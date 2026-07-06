extends CharacterBody2D
class_name Character

## Drives one fighter. Attach to a CharacterBody2D with children:
##   AnimatedSprite2D (named "Sprite", frames set from resources/sprites/*.tres)
##   Hitbox (Area2D, script Hitbox.gd, with a CollisionShape2D child)
##   Hurtbox (Area2D, script Hurtbox.gd, with a CollisionShape2D child)
## Assign `move_set` in the Inspector (a Dictionary populated at _ready from
## resources/moves/<character>/*.tres — see load_moves_for()).

enum State { IDLE, WALK, JUMP, CROUCH, ATTACK, BLOCKSTUN, HITSTUN, KNOCKDOWN, KO }

const GRAVITY := 1400.0
const WALK_SPEED := 160.0
const JUMP_VELOCITY := -520.0
const MAX_HEALTH := 100.0

@export var player_index: int = 0          # 0 = P1, 1 = P2
@export var character_folder: String = ""  # e.g. "kaion" — used to auto-load moves/frames

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox

var state: int = State.IDLE
var health: float = MAX_HEALTH
var facing_right: bool = true
var opponent: Character = null

var input_prefix: String = "p1_"
var input_buffer: InputBuffer

var moves: Dictionary = {}          # e.g. "light_punch" -> MoveData
var current_move: MoveData = null
var state_frame: int = 0            # frames elapsed since entering current state/move
var hitstun_timer: float = 0.0
var blockstun_timer: float = 0.0
var knockdown_timer: float = 0.0
var is_crouching_block: bool = false

signal health_changed(new_health: float, max_health: float)
signal ko(character: Character)
signal hit_landed(attacker: Character, defender: Character, move: MoveData)


func _ready() -> void:
	input_prefix = "p1_" if player_index == 0 else "p2_"
	input_buffer = InputBuffer.new()
	hitbox.owner_character = self
	hurtbox.owner_character = self
	hurtbox.hurt.connect(_on_hurt)
	if character_folder != "":
		load_character(character_folder)


## Loads SpriteFrames + MoveData for this character folder name.
## Call this at runtime (e.g. from a character-select screen) instead of
## setting character_folder in the Inspector if you want to swap fighters.
func load_character(folder: String) -> void:
	character_folder = folder
	var frames_path = "res://resources/sprites/%s_frames.tres" % folder
	if ResourceLoader.exists(frames_path):
		sprite.sprite_frames = load(frames_path)

	moves.clear()
	var dir_path = "res://resources/moves/%s" % folder
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var move: MoveData = load(dir_path + "/" + file_name)
				var key = file_name.trim_suffix(".tres")
				# Normalize special_1_name -> name for buffer lookups, keep both keys.
				moves[key] = move
			file_name = dir.get_next()
		dir.list_dir_end()


func _physics_process(delta: float) -> void:
	if opponent:
		_face_opponent()

	match state:
		State.IDLE, State.WALK, State.CROUCH:
			_process_grounded_input(delta)
		State.JUMP:
			_process_jump(delta)
		State.ATTACK:
			_process_attack(delta)
		State.BLOCKSTUN:
			_process_blockstun(delta)
		State.HITSTUN:
			_process_hitstun(delta)
		State.KNOCKDOWN:
			_process_knockdown(delta)
		State.KO:
			pass

	velocity.y += GRAVITY * delta
	move_and_slide()
	state_frame += 1
	_update_input_buffer()
	_check_specials()


func _face_opponent() -> void:
	var should_face_right = opponent.global_position.x > global_position.x
	if should_face_right != facing_right:
		facing_right = should_face_right
		sprite.flip_h = not facing_right
		hitbox.scale.x = 1 if facing_right else -1


# ---------------------------------------------------------------------------
# Grounded movement / attack input
# ---------------------------------------------------------------------------

func _process_grounded_input(_delta: float) -> void:
	var dir := Input.get_axis(input_prefix + "left", input_prefix + "right")
	var holding_down := Input.is_action_pressed(input_prefix + "down")

	if Input.is_action_just_pressed(input_prefix + "up"):
		_enter_jump()
		return

	if holding_down:
		_enter_state(State.CROUCH)
	elif dir != 0:
		velocity.x = dir * WALK_SPEED
		_enter_state(State.WALK)
	else:
		velocity.x = 0
		_enter_state(State.IDLE)

	_check_attack_buttons()


func _check_attack_buttons() -> void:
	for suffix in ["lp", "mp", "hp", "lk", "mk", "hk"]:
		if Input.is_action_just_pressed(input_prefix + suffix):
			var move_key = _button_to_move_key(suffix)
			if moves.has(move_key):
				_start_attack(moves[move_key])
			return


func _button_to_move_key(suffix: String) -> String:
	var map = {
		"lp": "light_punch", "mp": "medium_punch", "hp": "heavy_punch",
		"lk": "light_kick", "mk": "medium_kick", "hk": "heavy_kick",
	}
	return map.get(suffix, "")


func _enter_jump() -> void:
	velocity.y = JUMP_VELOCITY
	_enter_state(State.JUMP)


func _process_jump(_delta: float) -> void:
	var dir := Input.get_axis(input_prefix + "left", input_prefix + "right")
	velocity.x = dir * WALK_SPEED
	_check_attack_buttons()
	if is_on_floor() and state_frame > 2:
		_enter_state(State.IDLE)


# ---------------------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------------------

func _start_attack(move: MoveData) -> void:
	current_move = move
	velocity.x = 0
	_enter_state(State.ATTACK)
	sprite.play(move.animation)
	AudioManager.play_sfx("whiff", global_position)


func _process_attack(_delta: float) -> void:
	if current_move == null:
		_enter_state(State.IDLE)
		return
	var startup = current_move.startup
	var active_end = startup + current_move.active
	var recovery_end = active_end + current_move.recovery

	if state_frame == startup:
		hitbox.activate(current_move, facing_right)
	elif state_frame == active_end:
		hitbox.deactivate()
	elif state_frame >= recovery_end:
		current_move = null
		_enter_state(State.IDLE)


# ---------------------------------------------------------------------------
# Specials — checked every physics frame against the input buffer
# ---------------------------------------------------------------------------

func _update_input_buffer() -> void:
	var x := 0
	var y := 0
	if Input.is_action_pressed(input_prefix + "left"):
		x = -1
	elif Input.is_action_pressed(input_prefix + "right"):
		x = 1
	if Input.is_action_pressed(input_prefix + "up"):
		y = -1
	elif Input.is_action_pressed(input_prefix + "down"):
		y = 1

	var pressed: Array = []
	for suffix in ["lp", "mp", "hp", "lk", "mk", "hk"]:
		if Input.is_action_just_pressed(input_prefix + suffix):
			pressed.append(suffix)

	input_buffer.push_frame(x, y, facing_right, pressed)


func _check_specials() -> void:
	if state != State.IDLE and state != State.WALK and state != State.CROUCH:
		return
	# Specials are stored under their descriptive key (e.g.
	# "special_1_homing_wave"), so we scan for the "special_" prefix and
	# resolve which numbered slot (1/2/3) each one is.
	for key in moves.keys():
		if not key.begins_with("special_"):
			continue
		var move: MoveData = moves[key]
		var idx = key.substr(9, 1)  # "special_1_..." -> "1"
		var triggered := false
		match idx:
			"1":
				triggered = input_buffer.check_qcf("lp") or input_buffer.check_qcf("hp")
			"2":
				triggered = input_buffer.check_dp("mp") or input_buffer.check_dp("hp")
			"3":
				triggered = input_buffer.check_double_down("lk") or input_buffer.check_qcb("hk")
		if triggered:
			_start_attack(move)
			return


# ---------------------------------------------------------------------------
# Being hit / blocking
# ---------------------------------------------------------------------------

func _on_hurt(hit_data: Dictionary) -> void:
	var move: MoveData = hit_data["move"]
	var attacker: Character = hit_data["attacker"]

	var blocking = _is_blocking(move)
	if blocking:
		_enter_blockstun(move)
		AudioManager.play_sfx("block", global_position)
	else:
		_enter_hitstun(move, attacker)
		health = max(0.0, health - move.damage)
		health_changed.emit(health, MAX_HEALTH)
		hit_landed.emit(attacker, self, move)
		var sfx = "hit_heavy" if move.damage >= 13.0 else ("hit_medium" if move.damage >= 8.0 else "hit_light")
		AudioManager.play_sfx(sfx, global_position)
		if health <= 0.0:
			_enter_ko()


func _is_blocking(move: MoveData) -> bool:
	var holding_back := Input.is_action_pressed(input_prefix + ("right" if not facing_right else "left"))
	if not holding_back:
		return false
	if state == State.CROUCH and move.high_hitting:
		return false  # can't block a high while crouching... (kept simple: high must stand-block)
	if state != State.CROUCH and move.low_hitting:
		return false  # can't block a low while standing
	return state in [State.IDLE, State.WALK, State.CROUCH]


func _enter_blockstun(move: MoveData) -> void:
	is_crouching_block = state == State.CROUCH
	blockstun_timer = move.blockstun
	_enter_state(State.BLOCKSTUN)
	sprite.play("block_crouch" if is_crouching_block else "block")


func _process_blockstun(delta: float) -> void:
	blockstun_timer -= delta
	if blockstun_timer <= 0.0:
		_enter_state(State.IDLE)


func _enter_hitstun(move: MoveData, attacker: Character) -> void:
	hitstun_timer = move.hitstun
	var dir_sign = 1.0 if attacker.facing_right else -1.0
	velocity = Vector2(move.knockback.x * dir_sign, move.knockback.y)
	_enter_state(State.HITSTUN)
	sprite.play("hit_knockdown")


func _process_hitstun(delta: float) -> void:
	hitstun_timer -= delta
	if hitstun_timer <= 0.0:
		if is_on_floor():
			_enter_state(State.IDLE)
		else:
			_enter_state(State.KNOCKDOWN)


func _process_knockdown(_delta: float) -> void:
	if is_on_floor() and state_frame > 20:
		_enter_state(State.IDLE)


func _enter_ko() -> void:
	_enter_state(State.KO)
	sprite.play("hit_knockdown")
	AudioManager.play_sfx("ko_stinger", global_position)
	ko.emit(self)


# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------

func _enter_state(new_state: int) -> void:
	if state == new_state:
		# Still update looping idle/walk animation to match velocity, but
		# don't reset state_frame (avoids re-triggering attacks each frame).
		if new_state == State.IDLE:
			sprite.play("idle")
		elif new_state == State.WALK:
			sprite.play("walk")
		elif new_state == State.CROUCH:
			sprite.play("crouch")
		return
	state = new_state
	state_frame = 0
	match new_state:
		State.IDLE:
			sprite.play("idle")
		State.WALK:
			sprite.play("walk")
		State.JUMP:
			sprite.play("jump")
			AudioManager.play_sfx("jump", global_position)
		State.CROUCH:
			sprite.play("crouch")
		State.HITSTUN, State.KNOCKDOWN, State.KO, State.ATTACK, State.BLOCKSTUN:
			pass  # animation set by caller for these


func reset_for_round() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)
	state = State.IDLE
	current_move = null
	hitbox.deactivate()
	input_buffer.clear()
