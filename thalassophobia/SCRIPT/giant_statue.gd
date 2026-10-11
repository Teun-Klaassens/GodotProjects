extends Node3D
class_name GiantStatue
## A colossal statue head rising out of the water.
##
## Put this node at the WATER SURFACE height (y = 0.5 with the default water
## plane). The script loads the model, measures it, scales it to `target_height`,
## sinks `submerged_fraction` of it below this node's Y, tilts it, turns it to face
## `face_point`, and adds a cold spotlight so it can be seen in the dark.
##
## The model is found automatically by searching `search_root` for a .glb whose
## path contains `model_keyword`, so it works wherever you put the files.
## You can also drag a scene into `model_scene` to override the search.

@export_group("Model")
@export var model_scene: PackedScene
@export var model_keyword: String = ""
@export var search_root: String = "res://ASSETS"

@export_group("Size and pose")
## Height of the WHOLE model (most of it is underwater), in meters.
@export var target_height: float = 40.0
## 0 = sitting on the water line, 0.6 = submerged up to about the mouth, 1 = fully hidden.
@export_range(0.0, 1.0, 0.01) var submerged_fraction: float = 0.6
## Extra tilt in degrees. Negative X tips the face upward.
@export var tilt_degrees: Vector3 = Vector3(-12.0, 0.0, 5.0)
## Turn the face toward this world position (the model faces +Z by default).
@export var face_toward_point: bool = true
@export var face_point: Vector3 = Vector3(0.0, 0.0, 900.0)
@export var yaw_offset_degrees: float = 0.0
## Give the statue collision (a simplified convex shape). Off by default.
@export var solid: bool = false

@export_group("Spotlight")
@export var spotlight_enabled: bool = true
@export var spotlight_color: Color = Color(0.62, 0.8, 1.0)
@export var spotlight_energy: float = 18.0
## Sideways offset of the light as a fraction of target_height (puts one side of the face in shadow).
@export var spotlight_side_offset: float = 0.35
@export var spotlight_shadows: bool = false

var pivot: Node3D
var model: Node3D


func _ready() -> void:
	var scene := _find_model_scene()
	if scene == null:
		push_warning("GiantStatue '%s': no model found (keyword '%s' under %s). Assign model_scene or check the file name." % [name, model_keyword, search_root])
		return

	if face_toward_point:
		var d := face_point - global_position
		rotation.y = atan2(d.x, d.z) + deg_to_rad(yaw_offset_degrees)
	else:
		rotation.y = deg_to_rad(yaw_offset_degrees)

	pivot = Node3D.new()
	pivot.name = "TiltPivot"
	pivot.rotation = Vector3(deg_to_rad(tilt_degrees.x), deg_to_rad(tilt_degrees.y), deg_to_rad(tilt_degrees.z))
	add_child(pivot)

	model = scene.instantiate() as Node3D
	pivot.add_child(model)

	var aabb := _model_aabb(model)
	if aabb.size.y <= 0.0001:
		push_warning("GiantStatue '%s': model has no measurable mesh." % name)
		return

	var s := target_height / aabb.size.y
	model.scale = Vector3.ONE * s
	var center_x := aabb.position.x + aabb.size.x * 0.5
	var center_z := aabb.position.z + aabb.size.z * 0.5
	model.position = Vector3(
		-center_x * s,
		-submerged_fraction * target_height - aabb.position.y * s,
		-center_z * s
	)

	if solid:
		for mi in _mesh_instances(model):
			mi.create_convex_collision(true, true)

	if spotlight_enabled:
		_add_spotlight()


func _find_model_scene() -> PackedScene:
	if model_scene:
		return model_scene
	var path := _search(search_root, model_keyword.to_lower())
	if path == "":
		return null
	return load(path) as PackedScene


func _search(dir_path: String, keyword: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	for f in dir.get_files():
		var fname := f.trim_suffix(".remap") # exported builds list imported files as *.remap
		var full := dir_path.path_join(fname)
		var lower := full.to_lower()
		if (lower.ends_with(".glb") or lower.ends_with(".gltf")) and lower.contains(keyword):
			return full
	for sub in dir.get_directories():
		var found := _search(dir_path.path_join(sub), keyword)
		if found != "":
			return found
	return ""


func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_mesh_instances(c))
	return out


## Combined bounding box of every mesh in the model, in the model root's own space.
func _model_aabb(root: Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var have := false
	var result := AABB()
	for mi in _mesh_instances(root):
		var box: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if not have:
			result = box
			have = true
		else:
			result = result.merge(box)
	return result


func _add_spotlight() -> void:
	var light := SpotLight3D.new()
	light.name = "StatueSpot"
	light.light_color = spotlight_color
	light.light_energy = spotlight_energy
	light.light_volumetric_fog_energy = 1.5
	light.spot_range = target_height * 3.5
	light.spot_angle = 30.0
	light.spot_attenuation = 0.8
	light.shadow_enabled = spotlight_shadows
	add_child(light)
	# In front of the face (+Z), above it, and off to one side.
	light.position = Vector3(target_height * spotlight_side_offset, target_height * 0.55, target_height * 0.9)
	var face_height := (1.0 - submerged_fraction) * target_height * 0.55
	light.look_at(to_global(Vector3(0.0, face_height, 0.0)), Vector3.UP)
