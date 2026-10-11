extends Node3D
class_name EelCreature
## Monster Eel controller:
## - Swims submerged patrolling the water basin, driving water ripples and wake.
## - Features a spectacular "Breach Leap" action when triggered (e.g. by the Big Red Button):
##   The colossal monster eel rockets up out of the dark water in the distance,
##   arcs majestically over the water, roars/splashes, and dives back under.

@export var swim_depth: float = -6.0
@export var is_jumping: bool = false
@export var chase_speed: float = 24.0 # Faster predatory rush
@export var turn_rate: float = 12.0 # Snappy lock-on rotation speed
@export var kill_radius: float = 12.0 # Colossal lethal contact hitbox (12m)

var time: float = 0.0
var model_root: Node3D
var splash_audio: AudioStreamPlayer3D
var audio_playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0

# Leap trajectory state
var leap_timer: float = 0.0
var leap_duration: float = 5.5
var leap_start_pos: Vector3
var leap_apex_pos: Vector3
var leap_end_pos: Vector3
var splash_phase: float = 0.0
var is_splashing: bool = false
var splash_timer: float = 0.0

func _ready() -> void:
	add_to_group("creature")
	_load_eel_model()
	_setup_splash_audio()

func _load_eel_model() -> void:
	var glb_path := "res://ASSETS/Monster_eel/monster_eel.glb"
	if ResourceLoader.exists(glb_path):
		var scene: PackedScene = load(glb_path)
		if scene:
			model_root = scene.instantiate()
			model_root.name = "MonsterEelModel"
			# Scale appropriately for a colossal terrifying leviathan
			model_root.scale = Vector3(0.5, 0.5, 0.5)
			add_child(model_root)
	
	# If GLB failed or has no visual, fallback container
	if model_root == null:
		model_root = Node3D.new()
		model_root.name = "FallbackEel"
		add_child(model_root)

func _setup_splash_audio() -> void:
	splash_audio = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.3
	splash_audio.stream = gen
	splash_audio.unit_size = 75.0
	splash_audio.max_distance = 900.0
	add_child(splash_audio)
	splash_audio.play()
	audio_playback = splash_audio.get_stream_playback() as AudioStreamGeneratorPlayback

func get_head_position() -> Vector3:
	return global_position

## Triggered by the Big Red Button to launch a spectacular breach in the distance
func trigger_breach(custom_start: Vector3 = Vector3.ZERO, custom_end: Vector3 = Vector3.ZERO) -> void:
	is_jumping = true
	leap_timer = 0.0
	var ha = load("res://SCRIPT/horror_audio.gd")
	if ha:
		ha.play_3d(self, "jumpscare", global_position, 6.0, 250.0)
	
	if custom_start != Vector3.ZERO:
		leap_start_pos = custom_start
		leap_end_pos = custom_end
	else:
		# Spectacular breach right in front of the Overlook Platform (platform is at x=32, z=808)
		leap_start_pos = Vector3(-20.0, -6.0, 750.0)
		leap_end_pos = Vector3(65.0, -6.0, 710.0)
		
	var mid := (leap_start_pos + leap_end_pos) * 0.5
	# Leap apex reaches 16m above water level (y=0.5 -> y=16.5) right in front of the player's view
	leap_apex_pos = Vector3(mid.x, 16.5, mid.z)
	
	global_position = leap_start_pos
	_start_splash()

func _start_splash() -> void:
	is_splashing = true
	splash_timer = 0.0
	splash_audio.global_position = global_position

var is_passing_under: bool = false
var pass_start_pos: Vector3
var pass_end_pos: Vector3
var pass_timer: float = 0.0
var pass_duration: float = 8.0

## Causes the eel to slowly, ominously swim directly beneath the player's walkway
func trigger_under_walkway_pass(custom_path_start: Vector3 = Vector3(-60.0, -1.8, 945.0), custom_path_end: Vector3 = Vector3(60.0, -1.8, 945.0)) -> void:
	is_passing_under = true
	pass_timer = 0.0
	var ha = load("res://SCRIPT/horror_audio.gd")
	if ha:
		ha.play_3d(self, "enemy_growl", global_position, 4.0, 180.0)
	pass_start_pos = custom_path_start
	pass_end_pos = custom_path_end
	global_position = pass_start_pos

func _physics_process(delta: float) -> void:
	time += delta

	# Check player submergence and hunting state
	var player = get_tree().get_first_node_in_group("player")
	var is_player_hunting_target: bool = false
	if player and ("is_submerged" in player or "is_in_water" in player):
		var submerged: bool = bool(player.get("is_submerged"))
		var in_water: bool = bool(player.get("is_in_water"))
		# If mostly submerged or deep swimming in water
		if submerged or (in_water and player.global_position.y < 0.2):
			is_player_hunting_target = true

	# Check contact with player (using generous colossal lethal hitbox)
	if player and is_player_hunting_target:
		var dist_to_player := global_position.distance_to(player.global_position)
		if dist_to_player <= kill_radius:
			var director = get_tree().get_first_node_in_group("facility_director")
			if director and director.has_method("trigger_player_death"):
				director.trigger_player_death()

	if is_jumping:
		_process_leap(delta)
	elif is_passing_under:
		_process_under_pass(delta)
	elif is_player_hunting_target and player:
		_process_hunting_swim(player.global_position, delta)
	else:
		_process_ambient_swim(delta)

## Chases and homes in directly on the player when they submerge in the deep pool
func _process_hunting_swim(target_pos: Vector3, delta: float) -> void:
	# Eel heads straight for player's swimming location
	var forward := (target_pos - global_position).normalized()
	# Fast pursuit speed
	global_position = global_position.move_toward(target_pos, delta * chase_speed)

	if forward.length_squared() > 0.001:
		var target_quat := Quaternion(Basis.looking_at(forward, Vector3.UP))
		var current_quat := Quaternion(global_basis.orthonormalized())
		# Fast lock-on rotation towards the player
		global_basis = Basis(current_quat.slerp(target_quat, clampf(delta * turn_rate, 0.0, 1.0)))
		# Furious predatory undulation
		if model_root:
			model_root.rotation.z = sin(time * 6.5) * 0.45

func _process_under_pass(delta: float) -> void:
	pass_timer += delta
	var t: float = clampf(pass_timer / pass_duration, 0.0, 1.0)
	var pos := pass_start_pos.lerp(pass_end_pos, t)
	# Submerged just 1.8m down right beneath the water surface/walkway
	pos.y = -1.8 + sin(time * 1.5) * 0.3
	global_position = pos

	var forward := (pass_end_pos - pass_start_pos).normalized()
	if forward.length_squared() > 0.001:
		var target_quat := Quaternion(Basis.looking_at(forward, Vector3.UP))
		var current_quat := Quaternion(global_basis.orthonormalized())
		global_basis = Basis(current_quat.slerp(target_quat, clampf(delta * 4.0, 0.0, 1.0)))
		if model_root:
			model_root.rotation.z = sin(time * 1.8) * 0.25

	if t >= 1.0:
		is_passing_under = false


func _process_ambient_swim(delta: float) -> void:
	# Patrol an undulating path close to the walkway and overlook
	var patrol_x: float = sin(time * 0.25) * 45.0 + 10.0
	var patrol_z: float = cos(time * 0.2) * 80.0 + 820.0
	var patrol_y: float = swim_depth + sin(time * 0.5) * 1.5

	
	var target_pos := Vector3(patrol_x, patrol_y, patrol_z)
	var forward := (target_pos - global_position).normalized()
	
	global_position = global_position.lerp(target_pos, delta * 2.0)
	
	if forward.length_squared() > 0.001:
		var target_quat := Quaternion(Basis.looking_at(forward, Vector3.UP))
		var current_quat := Quaternion(global_basis.orthonormalized())
		global_basis = Basis(current_quat.slerp(target_quat, clampf(delta * 3.0, 0.0, 1.0)))
		# Serpentine body undulation on the child mesh node
		if model_root:
			model_root.rotation.z = sin(time * 2.2) * 0.15

func _process_leap(delta: float) -> void:
	leap_timer += delta
	var t: float = clamp(leap_timer / leap_duration, 0.0, 1.0)
	
	# Parabolic arc using quadratic Bézier interpolation
	var p0 := leap_start_pos
	var p1 := Vector3(leap_apex_pos.x, leap_apex_pos.y + 15.0, leap_apex_pos.z)
	var p2 := leap_end_pos
	
	var one_minus_t := 1.0 - t
	var pos := (one_minus_t * one_minus_t) * p0 + 2.0 * one_minus_t * t * p1 + (t * t) * p2
	
	# Velocity tangent derivative for orientation
	var tangent := 2.0 * one_minus_t * (p1 - p0) + 2.0 * t * (p2 - p1)
	
	global_position = pos
	
	if tangent.length_squared() > 0.01:
		look_at(global_position + tangent.normalized(), Vector3.UP)
		if model_root:
			model_root.rotation.z = sin(t * PI) * 0.4
			model_root.rotation.y = sin(time * 3.5) * 0.1


	# Trigger re-entry splash when plunging back down
	if t >= 0.88 and not is_splashing and pos.y < 2.0:
		_start_splash()

	if t >= 1.0:
		is_jumping = false
		_start_splash()

func _process(delta: float) -> void:
	if audio_playback == null:
		return

	if is_splashing:
		splash_timer += delta
		if splash_timer >= 2.5:
			is_splashing = false
			splash_timer = 0.0
		else:
			_generate_splash_audio()

func _generate_splash_audio() -> void:
	var frames := audio_playback.get_frames_available()
	for i in range(frames):
		splash_phase += 1.0 / sample_rate
		var progress: float = clamp(splash_timer / 2.5, 0.0, 1.0)
		var env: float = sin(progress * PI)

		# Deep bass impact rumble + foaming rush noise
		var rumble := sin(splash_phase * 38.0 * TAU) * env * 0.7
		var hiss := (randf() * 2.0 - 1.0) * env * 0.4
		var sample := (rumble + hiss) * 0.85
		audio_playback.push_frame(Vector2(sample, sample))
