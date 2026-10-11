extends AnimatableBody3D
class_name HeavyDoor

@export var open_height: float = 3.2
@export var transition_duration: float = 1.8 # Smooth natural 1.8s hydraulic slide

var is_open: bool = false
var is_moving: bool = false
var anim_progress: float = 0.0

var closed_pos: Vector3
var opened_pos: Vector3

var audio_player: AudioStreamPlayer3D
var audio_playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0

var sound_timer: float = 0.0
var motor_sound_active: bool = false

func _ready() -> void:
	add_to_group("interactable")
	closed_pos = position
	opened_pos = closed_pos + Vector3(0, open_height, 0)
	_setup_door_audio()

func _setup_door_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.3
	audio_player.stream = gen
	audio_player.unit_size = 20.0
	audio_player.max_distance = 80.0
	add_child(audio_player)
	audio_player.play()
	audio_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func get_prompt() -> String:
	return "[E] " + ("Close Heavy Door" if is_open else "Open Heavy Door")

func interact() -> void:
	if is_moving:
		return
	is_moving = true
	is_open = not is_open
	motor_sound_active = true
	sound_timer = 0.0
	_play_latch_clunk()
	var ha = load("res://SCRIPT/horror_audio.gd")
	if ha:
		ha.play_3d(self, "door_creak", global_position, -2.0)

func _physics_process(delta: float) -> void:
	if not is_moving:
		return

	# Progress calculation with natural smooth step easing
	var step_rate := delta / transition_duration
	if is_open:
		anim_progress = min(1.0, anim_progress + step_rate)
	else:
		anim_progress = max(0.0, anim_progress - step_rate)

	# Smooth S-curve (cubic hermite) interpolation for realistic heavy mechanical inertia
	var eased: float = smoothstep(0.0, 1.0, anim_progress)
	position = closed_pos.lerp(opened_pos, eased)

	# Check arrival
	if (is_open and anim_progress >= 1.0) or (not is_open and anim_progress <= 0.0):
		is_moving = false
		motor_sound_active = false
		_play_lock_impact()

func _play_latch_clunk() -> void:
	if audio_playback == null:
		return
	var frames := int(sample_rate * 0.15)
	for i in range(frames):
		var t := float(i) / sample_rate
		var clunk := sin(t * 120.0 * TAU) * exp(-35.0 * t) * 0.6
		var snap := (randf() * 2.0 - 1.0) * exp(-120.0 * t) * 0.4
		var s := (clunk + snap) * 0.8
		audio_playback.push_frame(Vector2(s, s))

func _play_lock_impact() -> void:
	if audio_playback == null:
		return
	var frames := int(sample_rate * 0.25)
	for i in range(frames):
		var t := float(i) / sample_rate
		var thud := sin(t * 70.0 * TAU) * exp(-20.0 * t) * 0.7
		var metal_ring := sin(t * 450.0 * TAU) * exp(-30.0 * t) * 0.35
		var s := (thud + metal_ring) * 0.8
		audio_playback.push_frame(Vector2(s, s))

func _process(delta: float) -> void:
	if audio_playback == null or not motor_sound_active:
		return

	var frames := audio_playback.get_frames_available()
	for i in range(frames):
		sound_timer += 1.0 / sample_rate
		# Continuous hydraulic motor hum & track friction
		var motor := sin(sound_timer * 95.0 * TAU) * 0.2
		var hiss := (randf() * 2.0 - 1.0) * 0.12
		var s := (motor + hiss) * 0.5
		audio_playback.push_frame(Vector2(s, s))
