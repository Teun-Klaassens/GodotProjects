extends Node3D

@export var water_mesh: MeshInstance3D
var creature: Node3D = null
var last_creature_pos: Vector3 = Vector3.ZERO
var creature_velocity: Vector3 = Vector3.ZERO
var has_last_pos: bool = false

var timer: float = 0.0
var surge_interval: float = 24.0
var surge_active: bool = false
var surge_time: float = 0.0

var audio_player: AudioStreamPlayer3D
var audio_playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0
var surge_phase: float = 0.0

func _ready() -> void:
	audio_player = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.3
	audio_player.stream = gen
	audio_player.unit_size = 50.0
	audio_player.max_distance = 400.0
	add_child(audio_player)
	audio_player.play()
	audio_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _creature_head() -> Vector3:
	if creature and creature.has_method("get_head_position"):
		return creature.get_head_position()
	if creature:
		return creature.global_position
	return Vector3.ZERO

func _shader_material() -> ShaderMaterial:
	if water_mesh == null:
		return null
	if water_mesh.material_override is ShaderMaterial:
		return water_mesh.material_override as ShaderMaterial
	if water_mesh.mesh and water_mesh.mesh.material is ShaderMaterial:
		return water_mesh.mesh.material as ShaderMaterial
	return null

func _physics_process(delta: float) -> void:
	if creature == null:
		creature = get_tree().get_first_node_in_group("creature") as Node3D
		if creature == null:
			var scene := get_tree().current_scene
			if scene:
				creature = scene.get_node_or_null("EelCreature") as Node3D

	var mat := _shader_material()
	if creature and mat:
		var head_pos := _creature_head()
		if has_last_pos and delta > 0.0:
			creature_velocity = creature_velocity.lerp((head_pos - last_creature_pos) / delta, 0.35)
		last_creature_pos = head_pos
		has_last_pos = true
		mat.set_shader_parameter("creature_position", head_pos)
		mat.set_shader_parameter("creature_velocity", creature_velocity)

	timer += delta
	if timer >= surge_interval:
		timer = 0.0
		surge_interval = randf_range(20.0, 32.0)
		trigger_sonic_displacement()

	if surge_active:
		surge_time += delta
		if surge_time >= 4.5:
			surge_active = false
			_reset_surge_intensity()
		else:
			# Surge intensity spikes locally at the creature
			if mat:
				var intensity := sin((surge_time / 4.5) * PI)
				mat.set_shader_parameter("creature_surge_intensity", intensity)

func trigger_sonic_displacement() -> void:
	surge_active = true
	surge_time = 0.0
	# Move 3D audio directly to the creature's location
	if creature:
		audio_player.global_position = _creature_head()

func _reset_surge_intensity() -> void:
	var mat := _shader_material()
	if mat:
		mat.set_shader_parameter("creature_surge_intensity", 0.0)

func _process(_delta: float) -> void:
	if audio_playback == null or not surge_active:
		return

	var frames := audio_playback.get_frames_available()
	for i in range(frames):
		surge_phase += 1.0 / sample_rate
		var progress: float = clamp(surge_time / 4.5, 0.0, 1.0)
		var env: float = sin(progress * PI)

		var freq := 24.0 + progress * 18.0
		var sub := sin(surge_phase * freq * TAU) * env * 0.75
		var churn := (randf() * 2.0 - 1.0) * env * 0.35

		var s := (sub + churn) * 0.8
		audio_playback.push_frame(Vector2(s, s))
