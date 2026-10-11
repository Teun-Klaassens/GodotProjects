extends StaticBody3D
class_name PowerSwitch
## Industrial High-Voltage Circuit Breaker Switch.
## Looking at the lever and pressing 'E' throws the switch with heavy electrical spark/clack audio.
## Powers a section of the chamber, escalates facility danger, and triggers scripted events.

signal switch_activated(switch_id: int)

@export var switch_id: int = 1
@export var lever_mesh: Node3D
@export var indicator_light: OmniLight3D
@export var label_text: String = "GRID A"

var is_activated: bool = false
var lever_anim_timer: float = 0.0
var original_lever_rot_x: float = 0.0

var audio_player: AudioStreamPlayer3D
var audio_playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0
var sfx_active: bool = false
var sfx_timer: float = 0.0
var sfx_phase: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("power_switches")
	if lever_mesh:
		original_lever_rot_x = lever_mesh.rotation.x
	_setup_audio()
	_update_indicator()

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.25
	audio_player.stream = gen
	audio_player.unit_size = 20.0
	audio_player.max_distance = 80.0
	add_child(audio_player)
	audio_player.play()
	audio_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _update_indicator() -> void:
	if indicator_light:
		if is_activated:
			indicator_light.light_color = Color(0.1, 1.0, 0.25)
			indicator_light.light_energy = 2.0
		else:
			indicator_light.light_color = Color(1.0, 0.6, 0.05)
			indicator_light.light_energy = 1.0

func get_prompt() -> String:
	return "[E] Throw Grid Breaker " + str(switch_id) if not is_activated else ""

func interact() -> void:
	if is_activated:
		return
	is_activated = true
	lever_anim_timer = 0.0
	sfx_active = true
	sfx_timer = 0.0
	_update_indicator()

	# Notify facility manager
	var director = get_tree().get_first_node_in_group("facility_director")
	if director and director.has_method("activate_switch"):
		director.activate_switch(switch_id)
	switch_activated.emit(switch_id)

func _physics_process(delta: float) -> void:
	if is_activated and lever_mesh and lever_anim_timer < 0.3:
		lever_anim_timer += delta
		var progress := clampf(lever_anim_timer / 0.3, 0.0, 1.0)
		# Pull lever down from -35 deg to +35 deg
		lever_mesh.rotation.x = lerp_angle(original_lever_rot_x, deg_to_rad(35.0), progress)

func _process(delta: float) -> void:
	if audio_playback == null or not sfx_active:
		return

	sfx_timer += delta
	if sfx_timer >= 0.5:
		sfx_active = false
		sfx_timer = 0.0
	else:
		var frames := audio_playback.get_frames_available()
		for i in range(frames):
			sfx_phase += 1.0 / sample_rate
			var env := exp(-sfx_timer * 12.0)
			# Metallic breaker slam + electric 60Hz buzz snap
			var clank := sin(sfx_phase * 95.0 * TAU) * env * 0.7
			var spark := (randf() * 2.0 - 1.0) * env * (0.5 if sfx_timer < 0.15 else 0.1)
			var hum := sin(sfx_phase * 60.0 * TAU) * env * 0.5
			var s := clank + spark + hum
			audio_playback.push_frame(Vector2(s, s))
