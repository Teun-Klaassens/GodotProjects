extends Node3D

@export var micro_flicker_chance: float = 0.015 # Rare, subtle individual light twitches
var lights: Array[Node] = []
var player: Node3D = null

# Global room-wide blackout surge variables
var surge_timer: float = 0.0
var next_surge_interval: float = 24.0
var is_surge_active: bool = false
var surge_duration: float = 0.0
var surge_elapsed: float = 0.0

func _ready() -> void:
	for child in get_children():
		lights.append(child)
	next_surge_interval = randf_range(20.0, 32.0)

var is_progressive_blackout: bool = false
var progressive_timer: float = 0.0
var progressive_speed: float = 80.0 # meters per second wave towards player
var wave_origin_z: float = -600.0
var target_player_z: float = 900.0

func trigger_progressive_blackout(origin_z: float = -600.0) -> void:
	is_progressive_blackout = true
	progressive_timer = 0.0
	wave_origin_z = origin_z
	var p := get_tree().get_first_node_in_group("player") as Node3D
	target_player_z = p.global_position.z if p else 900.0

func _process(delta: float) -> void:
	if is_progressive_blackout:
		progressive_timer += delta
		var wave_current_z: float = wave_origin_z + progressive_timer * progressive_speed
		var any_lit := false

		for light_node in lights:
			var light: OmniLight3D = light_node.get_node_or_null("Light")
			var mesh: MeshInstance3D = light_node.get_node_or_null("FixtureMesh")
			if light == null:
				continue

			# If the darkness wave has reached or passed this light's Z position, shut it off
			if light_node.global_position.z <= wave_current_z:
				light.visible = false
				if mesh:
					mesh.visible = false
			else:
				light.visible = true
				if mesh:
					mesh.visible = true
				any_lit = true

		if not any_lit or wave_current_z > target_player_z + 40.0:
			# Complete darkness reached! Trigger huge splash and reset after 4s
			if progressive_timer > 3.5:
				is_progressive_blackout = false
				_set_all_lights(true)
		return

	surge_timer += delta


	# Check if it's time for a synchronized full-room blackout surge
	if not is_surge_active and surge_timer >= next_surge_interval:
		surge_timer = 0.0
		next_surge_interval = randf_range(22.0, 35.0)
		is_surge_active = true
		surge_elapsed = 0.0
		surge_duration = randf_range(1.8, 3.2) # Pitch dark for ~2 seconds

	if is_surge_active:
		surge_elapsed += delta
		if surge_elapsed >= surge_duration:
			is_surge_active = false
			# Restore all lights
			_set_all_lights(true)
		else:
			# During global blackout: rapid synchronized sputtering then dead black
			var sputter_phase := surge_elapsed / surge_duration
			if sputter_phase < 0.25 or sputter_phase > 0.85:
				var sputter_on := randf() > 0.65
				_set_all_lights(sputter_on)
			else:
				# Complete pitch-black darkness
				_set_all_lights(false)
		return

	# Normal ambient mode: subtle, infrequent individual flickers
	for light_node in lights:
		var light: OmniLight3D = light_node.get_node_or_null("Light")
		var mesh: MeshInstance3D = light_node.get_node_or_null("FixtureMesh")
		if light == null:
			continue

		if randf() < micro_flicker_chance:
			var turn_off := randf() < 0.4
			light.visible = not turn_off
			if mesh:
				mesh.visible = not turn_off
		else:
			light.visible = true
			if mesh:
				mesh.visible = true

func _set_all_lights(state: bool) -> void:
	for light_node in lights:
		var light: OmniLight3D = light_node.get_node_or_null("Light")
		var mesh: MeshInstance3D = light_node.get_node_or_null("FixtureMesh")
		if light:
			light.visible = state
		if mesh:
			mesh.visible = state
