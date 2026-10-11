extends CharacterBody3D
class_name Player

@export_group("Movement")
@export var walk_speed: float = 3.5
@export var sprint_speed: float = 6.0
@export var wade_speed: float = 2.2
@export var acceleration: float = 10.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 14.0

@export_group("Look")
@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Flashlight
@onready var interact_ray: RayCast3D = $Head/InteractRay

var is_mouse_captured: bool = true
var is_in_water: bool = false

# Real recorded audio streams from SOUND folder
var step_audio_player: AudioStreamPlayer
var water_wade_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("player")
	capture_mouse(true)
	_setup_audio()

func _setup_audio() -> void:
	# Real human echoing footsteps track
	step_audio_player = AudioStreamPlayer.new()
	var step_stream = load("res://SOUND/pwlpl-echoing-footsteps-377259.mp3")
	step_audio_player.stream = step_stream
	step_audio_player.volume_db = 0.0
	add_child(step_audio_player)
	step_audio_player.finished.connect(func():
		var h_speed := Vector2(velocity.x, velocity.z).length()
		if is_on_floor() and h_speed > 0.2 and not is_in_water:
			step_audio_player.play()
	)

	# Water wading audio
	water_wade_player = AudioStreamPlayer.new()
	var water_stream = load("res://SOUND/tanweraman-under-water-sound-effect-for-movies-and-videos-343060.mp3")
	water_wade_player.stream = water_stream
	water_wade_player.volume_db = -4.0
	add_child(water_wade_player)
	water_wade_player.finished.connect(func():
		if is_on_floor() and is_in_water and Vector2(velocity.x, velocity.z).length() > 0.2:
			water_wade_player.play()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		capture_mouse(not is_mouse_captured)

	if is_mouse_captured and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(
			head.rotation.x,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and flashlight:
			flashlight.visible = not flashlight.visible
		elif event.keycode == KEY_E:
			_try_interact()

func _try_interact() -> void:
	if interact_ray and interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider:
			if collider.has_method("interact"):
				collider.interact()
			elif collider.get_parent() and collider.get_parent().has_method("interact"):
				collider.get_parent().interact()

func capture_mouse(capture: bool) -> void:
	is_mouse_captured = capture
	if capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	is_in_water = global_position.y <= 0.65

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity if not is_in_water else jump_velocity * 0.7

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		input_dir.x += 1.0

	input_dir = input_dir.normalized()
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and not is_in_water

	var current_speed: float = walk_speed
	if is_in_water:
		current_speed = wade_speed
	elif is_sprinting:
		current_speed = sprint_speed

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * current_speed * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * current_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * current_speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * current_speed * delta)

	move_and_slide()

	# Footstep audio control
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving_on_ground := is_on_floor() and horizontal_speed > 0.4

	if is_moving_on_ground:
		if is_in_water:
			# Stop dry footsteps, play underwater sloshing
			if step_audio_player.playing:
				step_audio_player.stop()
			if not water_wade_player.playing:
				water_wade_player.play()
		else:
			# Stop water sloshing, play echoing human footsteps
			if water_wade_player.playing:
				water_wade_player.stop()
			step_audio_player.pitch_scale = 1.25 if is_sprinting else 1.0
			if not step_audio_player.playing:
				step_audio_player.play()
	else:
		# Player stopped or in air: stop footsteps
		if step_audio_player.playing:
			step_audio_player.stop()
		if water_wade_player.playing:
			water_wade_player.stop()
