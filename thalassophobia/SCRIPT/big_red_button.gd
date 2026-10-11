extends StaticBody3D
class_name BigRedButton
## Interactive pedestal with a large red emergency button.
## Looking at it and pressing E pushes the plunger down with metallic clunk audio
## and commands the monster eel to leap out of the water in the distance.

@export var eel_node: Node3D
@export var button_plunger: Node3D

var is_pressed: bool = false
var anim_timer: float = 0.0
var original_plunger_y: float = 0.0

var audio_player: AudioStreamPlayer3D
var audio_playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0
var sfx_timer: float = 0.0
var sfx_active: bool = false
var sfx_phase: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	if button_plunger:
		original_plunger_y = button_plunger.position.y
	_setup_audio()

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.2
	audio_player.stream = gen
	audio_player.unit_size = 15.0
	audio_player.max_distance = 60.0
	add_child(audio_player)
	audio_player.play()
	audio_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func get_prompt() -> String:
	return "[E] Press Emergency Lockdown" if not is_pressed else ""

func interact() -> void:
	if is_pressed:
		return
	is_pressed = true
	anim_timer = 0.0
	sfx_active = true
	sfx_timer = 0.0

	# Find eel creature if not linked
	if eel_node == null:
		eel_node = get_tree().get_first_node_in_group("creature")
		if eel_node == null:
			var scene := get_tree().current_scene
			if scene:
				eel_node = scene.get_node_or_null("EelCreature")

	# Notify FacilityDirector to start the emergency escape sequence
	var director = get_tree().get_first_node_in_group("facility_director")
	if director and director.has_method("start_escape_sequence"):
		director.start_escape_sequence()
	elif eel_node and eel_node.has_method("trigger_breach"):
		eel_node.trigger_breach()

	# Also trigger water displacement surge
	var displacement = get_tree().get_first_node_in_group("water_displacement")
	if displacement == null:
		var scene := get_tree().current_scene
		if scene:
			displacement = scene.find_child("DisplacementController", true, false)
	if displacement and displacement.has_method("trigger_sonic_displacement"):
		displacement.trigger_sonic_displacement()


func _physics_process(delta: float) -> void:
	if is_pressed and button_plunger:
		anim_timer += delta
		if anim_timer < 0.2:
			# Depress plunger by 0.08m
			var progress := anim_timer / 0.2
			button_plunger.position.y = original_plunger_y - 0.08 * progress
		elif anim_timer < 1.5:
			button_plunger.position.y = original_plunger_y - 0.08
		elif anim_timer < 2.0:
			# Spring back up
			var progress := (anim_timer - 1.5) / 0.5
			button_plunger.position.y = original_plunger_y - 0.08 * (1.0 - progress)
		else:
			button_plunger.position.y = original_plunger_y
			is_pressed = false

func _process(delta: float) -> void:
	if audio_playback == null or not sfx_active:
		return

	sfx_timer += delta
	if sfx_timer >= 0.4:
		sfx_active = false
		sfx_timer = 0.0
	else:
		var frames := audio_playback.get_frames_available()
		for i in range(frames):
			sfx_phase += 1.0 / sample_rate
			var env := exp(-sfx_timer * 18.0)
			# Heavy mechanical switch click & clang
			var click := sin(sfx_phase * 220.0 * TAU) * env * 0.8
			var thud := sin(sfx_phase * 65.0 * TAU) * env * 0.6
			var sample := click + thud
			audio_playback.push_frame(Vector2(sample, sample))
