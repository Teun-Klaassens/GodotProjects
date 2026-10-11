extends Node3D

@export var speed: float = 6.0
@export var swim_depth: float = -4.5 # Sits a few meters below the water plane (y = 0.5)
@export var wave_frequency: float = 0.5
@export var wave_amplitude: float = 6.0

var time: float = 0.0
var segments: Array[Node3D] = []
var num_segments: int = 14
var segment_spacing: float = 2.8

# Trajectory: patrols back and forth beneath the walkway
var target_z: float = 0.0

func _ready() -> void:
	add_to_group("creature")
	_build_creature_body()

func get_head_position() -> Vector3:
	if segments.size() > 0:
		return segments[0].global_position
	return global_position

func _build_creature_body() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.03, 0.04, 1.0)
	mat.roughness = 0.3
	mat.metallic = 0.1
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL

	for i in range(num_segments):
		var seg := Node3D.new()
		seg.name = "Segment_%d" % i
		add_child(seg)

		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		# Taper body from head to tail
		var factor: float = 1.0 - (float(i) / float(num_segments)) * 0.6
		if i == 0:
			sphere.radius = 2.2
			sphere.height = 4.5
		else:
			sphere.radius = 1.8 * factor
			sphere.height = 3.5 * factor

		mesh_instance.mesh = sphere
		mesh_instance.material_override = mat
		seg.add_child(mesh_instance)
		segments.append(seg)

func _physics_process(delta: float) -> void:
	time += delta

	# Head position oscillates and moves across the water basin
	var head_x: float = sin(time * 0.25) * 45.0
	var head_z: float = cos(time * 0.18) * 90.0
	var head_y: float = swim_depth + sin(time * 0.6) * 1.5

	if segments.size() > 0:
		segments[0].global_position = Vector3(head_x, head_y, head_z)

		# Kinematic snake-like follow for trailing segments
		for i in range(1, segments.size()):
			var prev := segments[i - 1].global_position
			var curr := segments[i].global_position
			var dir := (curr - prev).normalized()
			if dir.length_squared() < 0.001:
				dir = Vector3.FORWARD

			# Natural sinusoidal body undulating wave
			var lateral := Vector3(-dir.z, 0, dir.x).normalized()
			var wave_offset := lateral * sin(time * 2.5 - float(i) * 0.5) * 0.8

			segments[i].global_position = prev + dir * segment_spacing + wave_offset
			segments[i].look_at(prev, Vector3.UP)
