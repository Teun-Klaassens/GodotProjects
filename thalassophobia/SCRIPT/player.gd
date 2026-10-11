extends CharacterBody3D
class_name Player

@export_group("Movement")
@export var walk_speed: float = 15.0
@export var sprint_speed: float = 20.0
@export var wade_speed: float = 4.4
@export var acceleration: float = 18.0
@export var jump_velocity: float = 1
@export var gravity: float = 8


@export_group("Look")
@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Flashlight
@onready var interact_ray: RayCast3D = $Head/InteractRay

@export_group("Flashlight Battery")
@export var max_battery: float = 100.0
@export var battery_drain_rate: float = 1.6 # ~60s of flashlight
@export var battery_recharge_rate: float = 2.5 # passive dynamo crank recharge while off
@export var low_battery_threshold: float = 25.0

var battery: float = 100.0
var is_flashlight_dead: bool = false
var _flicker_timer: float = 0.0
var _bob_time: float = 0.0
var default_head_y: float = 1.6

var is_mouse_captured: bool = true
var is_in_water: bool = false
var is_submerged: bool = false
var underwater_quad: MeshInstance3D
var underwater_mat: ShaderMaterial
var current_underwater_blend: float = 0.0

# Footsteps, the underwater loop and the whale song are handled by AudioDirector (SCRIPT/audio_director.gd).

func _ready() -> void:
	add_to_group("player")
	capture_mouse(true)
	if head:
		default_head_y = head.position.y
	battery = max_battery
	_setup_underwater_quad()

func _setup_underwater_quad() -> void:
	underwater_quad = MeshInstance3D.new()
	underwater_quad.name = "UnderwaterPostProcess"
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	underwater_quad.mesh = qm

	var mat_path := "res://MATERIAL/underwater_postprocess.tres"
	if ResourceLoader.exists(mat_path):
		underwater_mat = load(mat_path).duplicate() as ShaderMaterial
		underwater_quad.material_override = underwater_mat

	if camera:
		camera.add_child(underwater_quad)
		underwater_quad.position = Vector3(0, 0, -0.1)


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
			toggle_flashlight()
		elif event.keycode == KEY_E:
			_try_interact()

func toggle_flashlight() -> void:
	if not flashlight:
		return
	if flashlight.visible:
		flashlight.visible = false
	elif battery > 0.0 and not is_flashlight_dead:
		flashlight.visible = true
	else:
		# Play flicker when clicked while dead
		var ha = load("res://SCRIPT/horror_audio.gd")
		if ha:
			ha.play_2d(get_tree(), "flicker", -8.0)

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
	var water_node := get_tree().get_first_node_in_group("water") as Node3D
	var base_water_level: float = water_node.global_position.y if water_node else 0.5

	# Query dynamic wave surface height at the player's exact XZ position
	var surface_y: float = base_water_level
	var displacement = get_tree().get_first_node_in_group("water_displacement")
	if displacement == null and water_node:
		displacement = water_node.find_child("DisplacementController", true, false)
	if displacement and displacement.has_method("get_water_height_at"):
		surface_y = displacement.get_water_height_at(Vector2(global_position.x, global_position.z))

	is_in_water = global_position.y <= (surface_y + 0.3)

	# Submerged check: camera eye position vs dynamic water surface with small lead buffer
	var camera_y: float = camera.global_position.y if camera else (global_position.y + 1.6)
	is_submerged = camera_y <= (surface_y + 0.08)

	# Instant response when crossing waterline + rapid smooth settle
	var target_blend: float = 1.0 if is_submerged else 0.0
	if is_submerged and current_underwater_blend < 0.8:
		# Immediately activate underwater vision to prevent seeing through dry water surface (X-ray)
		current_underwater_blend = maxf(0.85, current_underwater_blend)
	current_underwater_blend = move_toward(current_underwater_blend, target_blend, delta * 12.0)
	if underwater_mat:
		underwater_mat.set_shader_parameter("underwater_blend", current_underwater_blend)

	# --- Flashlight battery drain & low-battery flicker ---
	_process_flashlight_battery(delta)

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

	# --- Ledge Mantle & Climb Check (When swimming next to a platform) ---
	var want_climb := Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_W)
	if is_in_water and want_climb:
		_check_and_perform_ledge_climb(delta)

	if is_submerged:
		# 3D Swimming physics: buoyancy, 3D look-direction swimming
		var look_dir := -camera.global_transform.basis.z if camera else -transform.basis.z
		var right_dir := camera.global_transform.basis.x if camera else transform.basis.x
		var swim_vec := (look_dir * (-input_dir.y) + right_dir * input_dir.x).normalized()

		if Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept"):
			swim_vec.y += 0.9
		if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
			swim_vec.y -= 0.9

		var swim_target := swim_vec * (wade_speed * 1.4)
		velocity = velocity.lerp(swim_target, delta * 5.0)
		# Clamp vertical speed while swimming so momentum doesn't launch player into orbit
		velocity.y = clampf(velocity.y, -wade_speed * 1.5, wade_speed * 1.5)
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta

		# Water surface jump / mantle boost: ONLY on single press, avoiding infinite momentum accumulation
		if Input.is_action_just_pressed("ui_accept"):
			if is_on_floor():
				velocity.y = jump_velocity if not is_in_water else jump_velocity * 0.9
			elif is_in_water:
				# Clean, controlled pop-up onto adjacent walkway
				velocity.y = minf(velocity.y + jump_velocity * 1.2, jump_velocity * 1.4)
				if input_dir.length_squared() > 0.05:
					var forward_f := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
					velocity.x = forward_f.x * 5.0
					velocity.z = forward_f.z * 5.0

		var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and not is_in_water
		var current_speed: float = walk_speed
		if is_sprinting:
			current_speed = sprint_speed
		elif is_in_water:
			current_speed = wade_speed * 1.3

		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if direction.length_squared() > 0.001:
			velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * current_speed * delta)
			velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * current_speed * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * current_speed * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * current_speed * delta)

	move_and_slide()

	# --- Head-bobbing & Movement Roll Tilt ---
	_process_head_bob_and_tilt(input_dir, delta)

	# --- Update HUD prompt based on interact ray ---
	_update_interact_prompt()

## Detects when swimming adjacent to a platform ledge and lifts the player onto it
func _check_and_perform_ledge_climb(delta: float) -> void:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return

	# Cast forward from waist height to find the platform wall
	var waist_pos := global_position + Vector3(0, 0.6, 0)
	var forward_dir := -transform.basis.z
	var wall_query := PhysicsRayQueryParameters3D.create(waist_pos, waist_pos + forward_dir * 1.5)
	wall_query.exclude = [get_rid()]
	var wall_hit := space_state.intersect_ray(wall_query)

	if wall_hit.is_empty():
		return

	var wall_pos: Vector3 = wall_hit["position"]
	# Cast downward from above the platform to find the top surface
	var ledge_top_start: Vector3 = wall_pos + Vector3(0, 1.8, 0) + forward_dir * 0.4
	var ledge_top_end: Vector3 = ledge_top_start + Vector3(0, -2.5, 0)
	var ledge_query := PhysicsRayQueryParameters3D.create(ledge_top_start, ledge_top_end)
	ledge_query.exclude = [get_rid()]
	var ledge_hit := space_state.intersect_ray(ledge_query)

	if not ledge_hit.is_empty():
		var normal: Vector3 = ledge_hit["normal"]
		var hit_pos: Vector3 = ledge_hit["position"]
		if normal.y > 0.6:
			var target_foot_y: float = hit_pos.y
			# If the ledge top is within climbable height (up to 2.5m above current feet)
			if target_foot_y > global_position.y and (target_foot_y - global_position.y) < 2.5:
				# Hoist player up onto platform surface
				velocity.y = maxf(velocity.y, 8.5)
				velocity.x = forward_dir.x * 5.0
				velocity.z = forward_dir.z * 5.0
				global_position.y = move_toward(global_position.y, target_foot_y + 0.1, delta * 9.0)
				global_position.x = move_toward(global_position.x, hit_pos.x, delta * 5.0)
				global_position.z = move_toward(global_position.z, hit_pos.z, delta * 5.0)

func _process_flashlight_battery(delta: float) -> void:
	if not flashlight:
		return

	if flashlight.visible:
		battery = maxf(0.0, battery - battery_drain_rate * delta)
		if battery <= 0.0:
			is_flashlight_dead = true
			flashlight.visible = false
			var ha = load("res://SCRIPT/horror_audio.gd")
			if ha:
				ha.play_2d(get_tree(), "flicker", -6.0)
		elif battery <= low_battery_threshold:
			_flicker_timer -= delta
			if _flicker_timer <= 0.0:
				_flicker_timer = randf_range(0.06, 0.28)
				if randf() < 0.35:
					flashlight.light_energy = randf_range(0.3, 1.2)
					var ha = load("res://SCRIPT/horror_audio.gd")
					if ha:
						ha.play_2d(get_tree(), "flicker", -14.0)
				else:
					flashlight.light_energy = randf_range(3.0, 5.0)
		else:
			# Normal base energy
			if is_submerged:
				flashlight.spot_range = 14.0
				flashlight.spot_attenuation = 2.2
				flashlight.light_energy = 3.5
			else:
				flashlight.spot_range = 120.0
				flashlight.spot_attenuation = 0.9
				flashlight.light_energy = 5.0
	else:
		# Passive dynamo recharge when light is off
		if battery < max_battery:
			battery = minf(max_battery, battery + battery_recharge_rate * delta)
			if is_flashlight_dead and battery >= 15.0:
				is_flashlight_dead = false

func _process_head_bob_and_tilt(input_dir: Vector2, delta: float) -> void:
	if not head or not camera:
		return

	var h_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and not is_submerged and h_speed > 0.4:
		_bob_time += delta * h_speed * 0.9
		var bob_y := default_head_y + sin(_bob_time * 2.0) * 0.04
		var bob_x := sin(_bob_time) * 0.02
		head.position.y = lerpf(head.position.y, bob_y, delta * 12.0)
		head.position.x = lerpf(head.position.x, bob_x, delta * 12.0)
	else:
		head.position.y = lerpf(head.position.y, default_head_y, delta * 8.0)
		head.position.x = lerpf(head.position.x, 0.0, delta * 8.0)

	# Subtle camera roll tilt when strafing left / right
	var target_roll := -input_dir.x * 0.025
	camera.rotation.z = lerp_angle(camera.rotation.z, target_roll, delta * 10.0)

func _update_interact_prompt() -> void:
	var prompt_text := ""
	if interact_ray and interact_ray.is_colliding():
		var col = interact_ray.get_collider()
		if col:
			if col.has_method("get_prompt"):
				prompt_text = col.get_prompt()
			elif col.get_parent() and col.get_parent().has_method("get_prompt"):
				prompt_text = col.get_parent().get_prompt()

	var director = get_tree().get_first_node_in_group("facility_director")
	if director and director.has_method("set_prompt"):
		director.set_prompt(prompt_text)
