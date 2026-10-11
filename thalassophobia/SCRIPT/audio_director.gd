extends Node
class_name AudioDirector
## Owns the game's audio design:
##   1. Underwater ambiance loop, playing smoothly.
##   2. Echoing footsteps when moving on walkways or wading in water.
##   3. Haunting whale song, triggering halfway along the walkway or when the eel draws close.
##   4. Tension Heartbeat: fades in and beats faster/louder as the monster eel draws closer.
##   5. Sprinting Heavy Breathing: smoothly fades in after sprinting for > 1.0 second, fades out on rest.
##
## All sound effects gradually fade in and fade out without harsh abrupt cuts.

const SAVE_PATH := "user://audio_settings.cfg"
const SOUND_ROOTS := ["res://SOUND", "res://"]

const KEY_UNDERWATER := "under-water-sound"
const KEY_FOOTSTEPS := "echoing-footsteps"
const KEY_DEEP_WATER_FOOTSTEPS := "deep-water-footsteps"
const KEY_WHALE := "whale"
const KEY_HEARTBEAT := "heartbeat"
const KEY_BREATHING := "breathing"

const PARAM_DEFS := [
	# ---- Underwater loop
	{"name": "underwater_loop_enabled", "label": "Underwater sound loops constantly", "group": "Underwater loop", "type": "bool", "default": true},
	{"name": "underwater_loop_volume_db", "label": "Volume (dB)", "group": "Underwater loop", "type": "float", "min": -60.0, "max": 6.0, "step": 0.5, "default": -4.0},
	# ---- Footsteps
	{"name": "footsteps_enabled", "label": "Walkway footsteps on", "group": "Footsteps", "type": "bool", "default": true},
	{"name": "footsteps_volume_db", "label": "Volume (dB)", "group": "Footsteps", "type": "float", "min": -40.0, "max": 6.0, "step": 0.5, "default": 2.0},
	# ---- Whale song
	{"name": "whale_enabled", "label": "Whale song when the eel gets close / halfway", "group": "Whale song", "type": "bool", "default": true},
	{"name": "whale_trigger_distance", "label": "Trigger distance (m)", "group": "Whale song", "type": "float", "min": 5.0, "max": 600.0, "step": 1.0, "default": 80.0},
	{"name": "whale_cooldown", "label": "Cooldown between plays (sec)", "group": "Whale song", "type": "float", "min": 0.0, "max": 300.0, "step": 1.0, "default": 45.0},
	{"name": "whale_volume_db", "label": "Volume (dB)", "group": "Whale song", "type": "float", "min": -40.0, "max": 6.0, "step": 0.5, "default": 0.0},
	{"name": "whale_positional", "label": "Sound comes from the eel (off = centered)", "group": "Whale song", "type": "bool", "default": true},
	# ---- Heartbeat (Monster Proximity)
	{"name": "heartbeat_enabled", "label": "Heartbeat proximity sensor", "group": "Heartbeat", "type": "bool", "default": true},
	{"name": "heartbeat_range", "label": "Heartbeat detection range (m)", "group": "Heartbeat", "type": "float", "min": 20.0, "max": 400.0, "step": 5.0, "default": 180.0},
	{"name": "heartbeat_volume_db", "label": "Max Heartbeat Volume (dB)", "group": "Heartbeat", "type": "float", "min": -40.0, "max": 24.0, "step": 0.5, "default": 18.0},
	# ---- Breathing (Exertion)
	{"name": "breathing_enabled", "label": "Heavy breathing after sprinting", "group": "Breathing", "type": "bool", "default": true},
	{"name": "breathing_volume_db", "label": "Max Breathing Volume (dB)", "group": "Breathing", "type": "float", "min": -40.0, "max": 18.0, "step": 0.5, "default": 6.0},

]

var params: Dictionary = {}
var defaults: Dictionary = {}

# Audio Players
var underwater_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var whale_player: AudioStreamPlayer3D
var heartbeat_player: AudioStreamPlayer
var breathing_player: AudioStreamPlayer

var has_underwater := false
var has_footsteps := false
var has_whale := false
var has_heartbeat := false
var has_breathing := false

# Tracking & Runtime States
var eel_distance: float = -1.0
var whale_cooldown_left: float = 0.0
var whale_armed: bool = true
var halfway_triggered: bool = false

# Smooth fade volumes (linear 0.0 to 1.0 multipliers)
var footstep_fade: float = 0.0
var underwater_fade: float = 0.0
var heartbeat_fade: float = 0.0
var breathing_fade: float = 0.0

# Sprint timer
var sprint_duration: float = 0.0


func _ready() -> void:
	add_to_group("audio_director")
	for d in PARAM_DEFS:
		defaults[d["name"]] = d["default"]
	params = defaults.duplicate()
	_load_saved()

	# 1. Underwater Loop
	underwater_player = AudioStreamPlayer.new()
	underwater_player.name = "UnderwaterLoop"
	add_child(underwater_player)
	var uw := _load_stream(KEY_UNDERWATER)
	if uw:
		_make_loop(uw)
		underwater_player.stream = uw
		has_underwater = true
		underwater_player.finished.connect(func():
			if params["underwater_loop_enabled"]:
				underwater_player.play()
		)
	else:
		push_warning("AudioDirector: underwater sound not found.")

	# 2. Walkway Deep Water Footsteps
	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "Footsteps"
	add_child(footstep_player)
	var fs := _load_stream(KEY_DEEP_WATER_FOOTSTEPS)
	if fs == null:
		fs = _load_stream(KEY_FOOTSTEPS)
	if fs:
		_make_loop(fs)
		footstep_player.stream = fs
		has_footsteps = true
		footstep_player.finished.connect(func():
			if footstep_fade > 0.01:
				footstep_player.play()
		)
	else:
		push_warning("AudioDirector: footsteps sound not found.")

	# 3. Whale Song
	whale_player = AudioStreamPlayer3D.new()
	whale_player.name = "WhaleSong"
	whale_player.unit_size = 60.0
	whale_player.max_distance = 800.0
	add_child(whale_player)
	var wh := _load_stream(KEY_WHALE)
	if wh:
		whale_player.stream = wh
		has_whale = true
	else:
		push_warning("AudioDirector: whale song not found.")

	# 4. Heartbeat Loop
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.name = "Heartbeat"
	add_child(heartbeat_player)
	var hb := _load_stream(KEY_HEARTBEAT)
	if hb:
		_make_loop(hb)
		heartbeat_player.stream = hb
		has_heartbeat = true
		heartbeat_player.finished.connect(func():
			if heartbeat_fade > 0.01:
				heartbeat_player.play()
		)
	else:
		push_warning("AudioDirector: heartbeat sound not found.")

	# 5. Heavy Breathing Loop
	breathing_player = AudioStreamPlayer.new()
	breathing_player.name = "Breathing"
	add_child(breathing_player)
	var br := _load_stream(KEY_BREATHING)
	if br:
		_make_loop(br)
		breathing_player.stream = br
		has_breathing = true
		breathing_player.finished.connect(func():
			if breathing_fade > 0.01:
				breathing_player.play()
		)
	else:
		push_warning("AudioDirector: breathing sound not found.")

	_apply()


# ------------------------------------------------------------ parameters

func get_param_defs() -> Array:
	return PARAM_DEFS


func get_param(pname: String) -> Variant:
	return params.get(pname)


func set_param(pname: String, value: Variant) -> void:
	if params.has(pname):
		params[pname] = value
		_apply()


func reset_params() -> void:
	params = defaults.duplicate()
	_apply()


func save_params() -> int:
	var cfg := ConfigFile.new()
	for k in params:
		cfg.set_value("audio", k, params[k])
	return cfg.save(SAVE_PATH)


func delete_saved() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return true
	return false


func _load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for d in PARAM_DEFS:
		var k: String = d["name"]
		if not cfg.has_section_key("audio", k):
			continue
		var v: Variant = cfg.get_value("audio", k)
		if d["type"] == "bool" and typeof(v) == TYPE_BOOL:
			params[k] = v
		elif d["type"] == "float" and typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			params[k] = float(v)


func _apply() -> void:
	whale_player.volume_db = float(params["whale_volume_db"])
	if params["underwater_loop_enabled"] and has_underwater:
		if not underwater_player.playing:
			underwater_player.play()
	elif underwater_player.playing:
		underwater_player.stop()


# ------------------------------------------------------------ debug actions

func debug_play_whale() -> void:
	_play_whale()


func debug_stop_whale() -> void:
	whale_player.stop()


func debug_restart_underwater() -> void:
	underwater_player.stop()
	_apply()


func get_debug_text() -> String:
	return get_debug_readout()


func get_debug_readout() -> String:
	var lines: PackedStringArray = []
	var missing: PackedStringArray = []
	if not has_underwater: missing.append("underwater loop")
	if not has_footsteps: missing.append("footsteps")
	if not has_whale: missing.append("whale song")
	if not has_heartbeat: missing.append("heartbeat")
	if not has_breathing: missing.append("breathing")
	if not missing.is_empty():
		lines.append("MISSING SOUND FILES: " + ", ".join(missing))

	if eel_distance >= 0.0:
		lines.append("Eel distance: %.1f m  (Heartbeat range: %.0f m)" % [eel_distance, float(params["heartbeat_range"])])
	else:
		lines.append("Eel distance: no eel / player detected")

	var whale_state := "playing" if whale_player.playing else ("cooling down %.0f s" % whale_cooldown_left if whale_cooldown_left > 0.0 else ("ready" if whale_armed else "armed"))
	lines.append("Whale song: " + whale_state)
	lines.append("Heartbeat: " + ("audible (fade %.2f)" % heartbeat_fade if heartbeat_fade > 0.01 else "silent"))
	lines.append("Breathing: " + ("audible (sprint %.1fs)" % sprint_duration if breathing_fade > 0.01 else "rested"))
	lines.append("Footsteps: " + ("playing" if footstep_fade > 0.05 else "silent"))
	return "\n".join(lines)


# ------------------------------------------------------------ audio files

func _find_audio(keyword: String) -> String:
	for root in SOUND_ROOTS:
		var found := _search(root, keyword)
		if found != "":
			return found
	return ""


func _search(dir_path: String, keyword: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	for f in dir.get_files():
		var fname := f.trim_suffix(".remap")
		var lower := fname.to_lower()
		if (lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav")) and lower.contains(keyword):
			return dir_path.path_join(fname)
	for sub in dir.get_directories():
		var found := _search(dir_path.path_join(sub), keyword)
		if found != "":
			return found
	return ""


func _load_stream(keyword: String) -> AudioStream:
	var path := _find_audio(keyword)
	if path == "":
		return null
	var s := load(path) as AudioStream
	if s == null:
		return null
	return s.duplicate() as AudioStream


func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true


# ------------------------------------------------------------ per-frame logic

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return

	_update_footsteps(player, delta)
	_update_whale(player, delta)
	_update_heartbeat(player, delta)
	_update_breathing(player, delta)
	_update_underwater_loop(delta)


func _update_footsteps(player: CharacterBody3D, delta: float) -> void:
	if not has_footsteps:
		return

	var h_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var want: bool = (
		params["footsteps_enabled"]
		and player.is_on_floor() and h_speed > 0.4
	)

	# Smoothly fade footsteps in / out (fast 8.0/s fade response)
	var target_fade := 1.0 if want else 0.0
	footstep_fade = move_toward(footstep_fade, target_fade, delta * 8.0)

	if footstep_fade > 0.01:
		if not footstep_player.playing:
			footstep_player.play()
		var sprinting := Input.is_key_pressed(KEY_SHIFT)
		var pitch := 1.25 if sprinting else 1.0
		footstep_player.pitch_scale = pitch

		var base_db := float(params["footsteps_volume_db"])
		footstep_player.volume_db = base_db + linear_to_db(clampf(footstep_fade, 0.001, 1.0))
	elif footstep_player.playing:
		footstep_player.stop()


func _update_whale(player: CharacterBody3D, delta: float) -> void:
	whale_cooldown_left = maxf(0.0, whale_cooldown_left - delta)

	var eel = get_tree().get_first_node_in_group("creature")
	var head := Vector3.ZERO
	if eel:
		head = eel.get_head_position() if eel.has_method("get_head_position") else eel.global_position
		eel_distance = head.distance_to(player.global_position)
	else:
		eel_distance = -1.0

	if whale_player.playing:
		whale_player.global_position = head if (eel and params["whale_positional"]) else player.global_position

	if not params["whale_enabled"]:
		return

	# Halfway trigger: player walks past z <= 960 (halfway between entrance z=1125 and red button z=808)
	var player_z := player.global_position.z
	if not halfway_triggered and player_z <= 960.0 and player_z > 700.0:
		halfway_triggered = true
		if has_whale and not whale_player.playing:
			_play_whale()
			return

	# Creature proximity trigger
	if eel != null:
		var trigger := float(params["whale_trigger_distance"])
		if eel_distance <= trigger:
			if whale_armed and whale_cooldown_left <= 0.0 and not whale_player.playing:
				_play_whale()
		elif eel_distance > trigger * 1.3:
			whale_armed = true


func _play_whale() -> void:
	if not has_whale:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var eel = get_tree().get_first_node_in_group("creature")
	if params["whale_positional"] and eel:
		whale_player.global_position = eel.get_head_position() if eel.has_method("get_head_position") else eel.global_position
	elif player:
		whale_player.global_position = player.global_position
	whale_player.play()
	whale_armed = false
	whale_cooldown_left = float(params["whale_cooldown"])


## Heartbeat gets louder and beats faster as the monster eel draws closer
func _update_heartbeat(_player: CharacterBody3D, delta: float) -> void:
	if not has_heartbeat or not params["heartbeat_enabled"]:
		if heartbeat_player.playing:
			heartbeat_fade = move_toward(heartbeat_fade, 0.0, delta * 3.0)
			if heartbeat_fade <= 0.01:
				heartbeat_player.stop()
		return

	var max_range := float(params["heartbeat_range"])
	var target_fade := 0.0
	var speed_multiplier := 1.0

	if eel_distance >= 0.0 and eel_distance <= max_range:
		# Normalized closeness from 0.0 (at max_range) to 1.0 (right on top)
		var closeness := 1.0 - clampf(eel_distance / max_range, 0.0, 1.0)
		target_fade = pow(closeness, 0.75) # Quicker rise in volume
		# Heartbeat speeds up dramatically: from 1.0x up to 3.8x frantic pounding
		speed_multiplier = 1.0 + (pow(closeness, 0.9) * 2.8)
	else:
		target_fade = 0.0

	# Smooth gradual volume fade in / out
	heartbeat_fade = move_toward(heartbeat_fade, target_fade, delta * 3.0)

	if heartbeat_fade > 0.01:
		if not heartbeat_player.playing:
			heartbeat_player.play()
		heartbeat_player.pitch_scale = speed_multiplier
		var base_db := float(params["heartbeat_volume_db"])
		# Louder presence even at mid-range
		heartbeat_player.volume_db = base_db + linear_to_db(clampf(heartbeat_fade, 0.01, 1.0))
	elif heartbeat_player.playing:
		heartbeat_player.stop()



## Breathing plays after sprinting for > 1.0 second, fading in smoothly and fading out when resting
func _update_breathing(player: CharacterBody3D, delta: float) -> void:
	if not has_breathing or not params["breathing_enabled"]:
		if breathing_player.playing:
			breathing_fade = move_toward(breathing_fade, 0.0, delta * 2.0)
			if breathing_fade <= 0.01:
				breathing_player.stop()
		return

	var is_sprinting := (
		Input.is_key_pressed(KEY_SHIFT)
		and player.is_on_floor()
		and Vector2(player.velocity.x, player.velocity.z).length() > 5.0
	)

	if is_sprinting:
		sprint_duration += delta
	else:
		# Gradually recover stamina
		sprint_duration = maxf(0.0, sprint_duration - delta * 0.8)

	# Trigger breathing when sprinted for > 1.0s
	var target_fade: float = 0.0
	if sprint_duration > 1.0:
		target_fade = clampf((sprint_duration - 1.0) / 1.5, 0.3, 1.0)
	else:
		target_fade = 0.0

	# Gradual smooth fade in and fade out
	breathing_fade = move_toward(breathing_fade, target_fade, delta * 1.8)

	if breathing_fade > 0.01:
		if not breathing_player.playing:
			breathing_player.play()
		# Slight breathing pitch increase with heavy exertion
		breathing_player.pitch_scale = 1.0 + clampf(sprint_duration * 0.04, 0.0, 0.35)
		var base_db := float(params["breathing_volume_db"])
		breathing_player.volume_db = base_db + linear_to_db(clampf(breathing_fade, 0.001, 1.0))
	elif breathing_player.playing:
		breathing_player.stop()


func _update_underwater_loop(delta: float) -> void:
	if not has_underwater:
		return
	var want := bool(params["underwater_loop_enabled"])
	var target_fade := 1.0 if want else 0.0
	underwater_fade = move_toward(underwater_fade, target_fade, delta * 2.0)

	if underwater_fade > 0.01:
		if not underwater_player.playing:
			underwater_player.play()
		var base_db := float(params["underwater_loop_volume_db"])
		underwater_player.volume_db = base_db + linear_to_db(clampf(underwater_fade, 0.001, 1.0))
	elif underwater_player.playing:
		underwater_player.stop()
