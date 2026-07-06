extends Node

## Autoload — registers the full P1/P2 input map at runtime (_ready, before
## anything else needs it). Keeping this in code instead of hand-written
## InputEventKey blocks in project.godot avoids a single typo corrupting the
## whole project file, and it's easy to read/extend.
##
## Action names: p{1|2}_{left,right,up,down,jump,punch,light,punch_medium,
## punch_heavy,kick_light,kick_medium,kick_heavy}
## Simplified to: p{n}_left/right/up/down, p{n}_lp/mp/hp, p{n}_lk/mk/hk

const P1_KEYS = {
	"p1_left": KEY_A,
	"p1_right": KEY_D,
	"p1_up": KEY_W,
	"p1_down": KEY_S,
	"p1_lp": KEY_U,
	"p1_mp": KEY_I,
	"p1_hp": KEY_O,
	"p1_lk": KEY_J,
	"p1_mk": KEY_K,
	"p1_hk": KEY_L,
}

const P2_KEYS = {
	"p2_left": KEY_LEFT,
	"p2_right": KEY_RIGHT,
	"p2_up": KEY_UP,
	"p2_down": KEY_DOWN,
	"p2_lp": KEY_KP_7,
	"p2_mp": KEY_KP_8,
	"p2_hp": KEY_KP_9,
	"p2_lk": KEY_KP_4,
	"p2_mk": KEY_KP_5,
	"p2_hk": KEY_KP_6,
}

# Gamepad buttons mirrored onto the same actions (device index 0 = P1, 1 = P2).
const PAD_BUTTONS = {
	"lp": JOY_BUTTON_X,
	"mp": JOY_BUTTON_Y,
	"hp": JOY_BUTTON_RIGHT_SHOULDER,
	"lk": JOY_BUTTON_A,
	"mk": JOY_BUTTON_B,
	"hk": JOY_BUTTON_LEFT_SHOULDER, # remap freely to taste
}


func _ready() -> void:
	_register_player(P1_KEYS, 0)
	_register_player(P2_KEYS, 1)


func _register_player(key_map: Dictionary, device: int) -> void:
	for action in key_map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = key_map[action]
		InputMap.action_add_event(action, ev)

	# Directional analog stick as a fallback/addition for gamepad play.
	var prefix = "p1_" if device == 0 else "p2_"
	for suffix in ["left", "right", "up", "down"]:
		var action = prefix + suffix
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	var axis_map = {
		"left": [JOY_AXIS_LEFT_X, -1.0],
		"right": [JOY_AXIS_LEFT_X, 1.0],
		"up": [JOY_AXIS_LEFT_Y, -1.0],
		"down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for suffix in axis_map.keys():
		var action = prefix + suffix
		var ev := InputEventJoypadMotion.new()
		ev.device = device
		ev.axis = axis_map[suffix][0]
		ev.axis_value = axis_map[suffix][1]
		InputMap.action_add_event(action, ev)

	for suffix in ["lp", "mp", "hp", "lk", "mk", "hk"]:
		var action = prefix + suffix
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = PAD_BUTTONS[suffix]
		InputMap.action_add_event(action, ev)
