extends RefCounted
class_name InputBuffer

## Tracks the last N frames of directional state + button presses for one
## player, and checks that history against classic motion-input patterns
## (quarter-circle, dragon-punch, charge-back) to trigger specials.
##
## Usage: create one per character, call push_frame() once per physics
## frame with the current direction (as -1/0/1 pair) and any buttons
## pressed that frame, then call match_motion() to check for a special.

const BUFFER_SIZE := 20  # ~0.33s at 60fps — standard arcade leniency

# Direction encoding, numpad notation (5 = neutral):
# 7 8 9
# 4 5 6
# 1 2 3
const NEUTRAL := 5

var _history: Array = []  # Array of {dir: int, buttons: Array[String], facing_right: bool}


func _dir_to_numpad(x: int, y: int, facing_right: bool) -> int:
	# x: -1 left, 1 right (world space); y: -1 up, 1 down; convert to
	# numpad relative to which way the character is facing so "forward"
	# always reads as 6 and "back" as 4.
	var fx = x if facing_right else -x
	if fx < 0 and y < 0: return 7
	if fx == 0 and y < 0: return 8
	if fx > 0 and y < 0: return 9
	if fx < 0 and y == 0: return 4
	if fx == 0 and y == 0: return 5
	if fx > 0 and y == 0: return 6
	if fx < 0 and y > 0: return 1
	if fx == 0 and y > 0: return 2
	if fx > 0 and y > 0: return 3
	return NEUTRAL


func push_frame(x: int, y: int, facing_right: bool, buttons_pressed: Array) -> void:
	var numpad = _dir_to_numpad(x, y, facing_right)
	_history.append({"dir": numpad, "buttons": buttons_pressed})
	if _history.size() > BUFFER_SIZE:
		_history.pop_front()


func _recent_dirs(count: int) -> Array:
	var n = _history.size()
	var start = max(0, n - count)
	var out = []
	for i in range(start, n):
		out.append(_history[i]["dir"])
	return out


## Returns true if `sequence` (list of numpad directions) appears in order
## (not necessarily contiguous — some slop frames allowed between) within
## the buffer, ending within `end_window` frames of "now".
func _sequence_matches(sequence: Array, end_window: int) -> bool:
	var dirs = _recent_dirs(BUFFER_SIZE)
	if dirs.is_empty():
		return false
	var seq_idx = 0
	var last_match_frame = -1
	for i in range(dirs.size()):
		if seq_idx >= sequence.size():
			break
		if dirs[i] == sequence[seq_idx]:
			seq_idx += 1
			last_match_frame = i
	if seq_idx < sequence.size():
		return false
	# The final element of the sequence must have landed within the last
	# `end_window` frames (so old completed motions don't fire forever).
	return (dirs.size() - 1 - last_match_frame) <= end_window


func _button_just_pressed_recently(button: String, window: int) -> bool:
	var n = _history.size()
	var start = max(0, n - window)
	for i in range(start, n):
		if _history[i]["buttons"].has(button):
			return true
	return false


## Quarter-circle forward + punch/kick, e.g. Kaion's Homing Wave (236+P).
func check_qcf(button: String) -> bool:
	return _sequence_matches([2, 3, 6], 8) and _button_just_pressed_recently(button, 6)


## Quarter-circle back + punch/kick (charge/retreat specials).
func check_qcb(button: String) -> bool:
	return _sequence_matches([2, 1, 4], 8) and _button_just_pressed_recently(button, 6)


## Dragon-punch motion forward, e.g. an uppercut-style special (623+P).
func check_dp(button: String) -> bool:
	return _sequence_matches([6, 2, 3], 8) and _button_just_pressed_recently(button, 6)


## Double-tap down (fast crouch-crouch), used for e.g. Substitution-style
## teleport/dodge specials.
func check_double_down(button: String) -> bool:
	return _sequence_matches([2, 5, 2], 10) and _button_just_pressed_recently(button, 8)


func clear() -> void:
	_history.clear()
