extends Node
## Autoload singleton. Handles looping stage music and a pool of
## AudioStreamPlayer2D nodes for overlapping SFX (hits, jumps, KO stingers,
## voice barks, etc.) without instancing a new player per sound.

@export var sfx_pool_size: int = 8
@export var music_volume_db: float = -6.0
@export var sfx_volume_db: float = 0.0

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer2D] = []
var _sfx_next: int = 0

const SFX := {
	"hit_light": "res://assets/audio/sfx/hit_light.wav",
	"hit_medium": "res://assets/audio/sfx/hit_medium.wav",
	"hit_heavy": "res://assets/audio/sfx/hit_heavy.wav",
	"whiff": "res://assets/audio/sfx/whiff.wav",
	"jump": "res://assets/audio/sfx/jump.wav",
	"block": "res://assets/audio/sfx/block.wav",
	"menu_blip": "res://assets/audio/sfx/menu_blip.wav",
	"special_charge": "res://assets/audio/sfx/special_charge.wav",
	"special_release": "res://assets/audio/sfx/special_release.wav",
	"ko_stinger": "res://assets/audio/sfx/ko_stinger.wav",
}

const MUSIC := {
	"stage_theme": "res://assets/audio/music/stage_theme.ogg",
}

# cache loaded streams so repeated play_sfx calls don't re-hit the disk
var _stream_cache: Dictionary = {}


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = music_volume_db
	_music_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

	for i in range(sfx_pool_size):
		var p := AudioStreamPlayer2D.new()
		p.name = "SFXPlayer%d" % i
		p.volume_db = sfx_volume_db
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(p)
		_sfx_pool.append(p)


func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream: AudioStream = load(path)
	_stream_cache[path] = stream
	return stream


## Play a looping music track by key (see MUSIC dict above).
func play_music(key: String, fade_in_sec: float = 0.0) -> void:
	if not MUSIC.has(key):
		push_warning("AudioManager: unknown music key '%s'" % key)
		return
	var stream := _load_stream(MUSIC[key])
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_music_player.stream = stream
	if fade_in_sec > 0.0:
		_music_player.volume_db = -40.0
		_music_player.play()
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", music_volume_db, fade_in_sec)
	else:
		_music_player.volume_db = music_volume_db
		_music_player.play()


func stop_music(fade_out_sec: float = 0.0) -> void:
	if fade_out_sec > 0.0:
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", -40.0, fade_out_sec)
		tw.tween_callback(_music_player.stop)
	else:
		_music_player.stop()


func _on_music_finished() -> void:
	# stream.loop should keep it going, but as a safety net for non-looping
	# streams, just replay from the top.
	if _music_player.stream != null:
		_music_player.play()


## Play a one-shot SFX by key at an optional world position (for panning).
## Cycles through a fixed pool so overlapping hits don't cut each other off.
func play_sfx(key: String, position: Vector2 = Vector2.ZERO) -> void:
	if not SFX.has(key):
		push_warning("AudioManager: unknown sfx key '%s'" % key)
		return
	var stream := _load_stream(SFX[key])
	var player := _get_free_sfx_player()
	player.stream = stream
	player.global_position = position
	player.play()


func _get_free_sfx_player() -> AudioStreamPlayer2D:
	# prefer an idle player if one exists
	for p in _sfx_pool:
		if not p.playing:
			return p
	# otherwise round-robin steal the oldest-assigned player
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	return p
