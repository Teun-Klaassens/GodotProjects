extends Node3D
class_name StatueField
## Spawns and animates the giant half-submerged Roman heads.
##
## Every number you can tune lives in PARAM_DEFS below, and the in-game
## "Model settings" panel (press M) builds its sliders from that list, so a new
## entry here automatically gets a slider.

signal layout_changed(spawned: int, requested: int)

const SAVE_PATH := "user://statue_settings.cfg" # loaded automatically at startup
const SEARCH_ROOT := "res://ASSETS"
# model kind -> text that must appear in the .glb path
const KEYWORDS := {"vespasian": "vespasian", "augustus": "auguste"}

# The first statues use these fixed spots (when "use_preset_positions" is on).
const PRESETS := [
	{"kind": "vespasian", "pos": Vector2(-45.0, 960.0)},
	{"kind": "augustus", "pos": Vector2(65.0, 860.0)},
]
# Walkway centre line (x, z), used to keep random statues away from the path.
const WALKWAY := [
	Vector2(0.0, 1128.0), Vector2(0.0, 1075.0), Vector2(20.0, 1025.0),
	Vector2(40.0, 985.0), Vector2(10.0, 945.0), Vector2(-20.0, 915.0),
	Vector2(-40.0, 885.0), Vector2(-60.0, 848.0), Vector2(-10.0, 848.0),
	Vector2(-10.0, 826.0), Vector2(32.0, 808.0),
]
const FACE_POINT := Vector3(0.0, 0.0, 1000.0) # where statues look at before tracking starts
const MAX_TRIES := 80

# Changing these needs the statues to be placed again; everything else updates live.
const RESPAWN_KEYS := [
	"count", "use_preset_positions", "random_seed", "augustus_share",
	"area_center_x", "area_center_z", "area_half_width", "area_half_length",
	"min_walkway_distance", "min_spacing",
]

# type: "int" | "float" | "bool" | "color"
const PARAM_DEFS := [
	# ---- Layout
	{"name": "count", "label": "Number of statues", "group": "Layout", "type": "int", "min": 0, "max": 40, "step": 1, "default": 2},
	{"name": "use_preset_positions", "label": "First two use hand-placed spots", "group": "Layout", "type": "bool", "default": true},
	{"name": "random_seed", "label": "Layout seed", "group": "Layout", "type": "int", "min": 0, "max": 9999, "step": 1, "default": 1},
	{"name": "augustus_share", "label": "Share that are Augustus (heavy model)", "group": "Layout", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.5},
	{"name": "area_center_x", "label": "Spawn area center X", "group": "Layout", "type": "float", "min": -550.0, "max": 550.0, "step": 5.0, "default": 0.0},
	{"name": "area_center_z", "label": "Spawn area center Z", "group": "Layout", "type": "float", "min": -1050.0, "max": 1050.0, "step": 5.0, "default": 900.0},
	{"name": "area_half_width", "label": "Spawn area half-width (X)", "group": "Layout", "type": "float", "min": 10.0, "max": 590.0, "step": 5.0, "default": 180.0},
	{"name": "area_half_length", "label": "Spawn area half-length (Z)", "group": "Layout", "type": "float", "min": 10.0, "max": 1050.0, "step": 5.0, "default": 200.0},

	{"name": "min_walkway_distance", "label": "Min distance from walkway", "group": "Layout", "type": "float", "min": 0.0, "max": 250.0, "step": 1.0, "default": 50.0},
	{"name": "min_spacing", "label": "Min spacing between statues", "group": "Layout", "type": "float", "min": 0.0, "max": 400.0, "step": 1.0, "default": 90.0},
	# ---- Size
	{"name": "height", "label": "Statue height (m)", "group": "Size", "type": "float", "min": 5.0, "max": 150.0, "step": 0.5, "default": 40.0},
	{"name": "augustus_height_scale", "label": "Augustus size multiplier", "group": "Size", "type": "float", "min": 0.3, "max": 3.0, "step": 0.01, "default": 1.15},
	{"name": "size_variation", "label": "Size randomness", "group": "Size", "type": "float", "min": 0.0, "max": 0.9, "step": 0.01, "default": 0.25},
	# ---- Pose
	{"name": "submerged_fraction", "label": "Submerged (0 = none, 1 = all)", "group": "Pose", "type": "float", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.6},
	{"name": "submerged_variation", "label": "Submersion randomness", "group": "Pose", "type": "float", "min": 0.0, "max": 0.4, "step": 0.005, "default": 0.05},
	{"name": "tilt_x", "label": "Tilt forward/back (deg, - = face up)", "group": "Pose", "type": "float", "min": -60.0, "max": 60.0, "step": 0.5, "default": -12.0},
	{"name": "tilt_z", "label": "Tilt sideways (deg)", "group": "Pose", "type": "float", "min": -60.0, "max": 60.0, "step": 0.5, "default": 0.0},
	{"name": "tilt_randomness", "label": "Tilt randomness (deg)", "group": "Pose", "type": "float", "min": 0.0, "max": 45.0, "step": 0.5, "default": 4.0},
	{"name": "yaw_randomness", "label": "Turn randomness (deg off-center)", "group": "Pose", "type": "float", "min": 0.0, "max": 180.0, "step": 1.0, "default": 0.0},
	{"name": "waterline_y", "label": "Waterline height (Y)", "group": "Pose", "type": "float", "min": -5.0, "max": 20.0, "step": 0.05, "default": 0.5},
	{"name": "follow_water", "label": "Follow the water plane's height", "group": "Pose", "type": "bool", "default": false},
	# ---- Watching the player
	{"name": "track_player", "label": "Turn to watch the player", "group": "Watching the player", "type": "bool", "default": true},
	{"name": "turn_speed", "label": "Turn speed (deg/sec)", "group": "Watching the player", "type": "float", "min": 0.0, "max": 360.0, "step": 1.0, "default": 30.0},
	{"name": "lead_seconds", "label": "Look ahead of player (sec)", "group": "Watching the player", "type": "float", "min": 0.0, "max": 3.0, "step": 0.05, "default": 0.0},
	{"name": "track_range", "label": "Only watch within (m, 0 = always)", "group": "Watching the player", "type": "float", "min": 0.0, "max": 2500.0, "step": 10.0, "default": 0.0},
	{"name": "idle_spin_speed", "label": "Idle spin when not watching (deg/sec)", "group": "Watching the player", "type": "float", "min": -90.0, "max": 90.0, "step": 0.5, "default": 0.0},
	# ---- Spotlight
	{"name": "spotlight_enabled", "label": "Spotlight on", "group": "Spotlight", "type": "bool", "default": true},
	{"name": "spotlight_energy", "label": "Spotlight brightness", "group": "Spotlight", "type": "float", "min": 0.0, "max": 80.0, "step": 0.5, "default": 18.0},
	{"name": "spotlight_color", "label": "Spotlight color", "group": "Spotlight", "type": "color", "default": Color(0.62, 0.8, 1.0)},
	{"name": "spotlight_side_offset", "label": "Spotlight sideways offset", "group": "Spotlight", "type": "float", "min": -1.0, "max": 1.0, "step": 0.01, "default": 0.35},
	{"name": "spotlight_range_scale", "label": "Spotlight range (x height)", "group": "Spotlight", "type": "float", "min": 1.0, "max": 8.0, "step": 0.1, "default": 3.5},
	{"name": "spotlight_angle", "label": "Spotlight cone angle", "group": "Spotlight", "type": "float", "min": 10.0, "max": 80.0, "step": 1.0, "default": 30.0},
	{"name": "spotlight_shadows", "label": "Spotlight casts shadows (slower)", "group": "Spotlight", "type": "bool", "default": false},
	# ---- Misc
	{"name": "show_statues", "label": "Show statues", "group": "Misc", "type": "bool", "default": true},
	{"name": "cast_shadows", "label": "Statues cast shadows", "group": "Misc", "type": "bool", "default": true},
]


class StatueRec:
	var root: Node3D
	var pivot: Node3D
	var model: Node3D
	var light: SpotLight3D
	var meshes: Array[MeshInstance3D] = []
	var kind: String = ""
	var r_size: float = 0.0
	var r_subm: float = 0.0
	var r_tilt: Vector2 = Vector2.ZERO
	var r_yaw: float = 0.0


var params: Dictionary = {}
var defaults: Dictionary = {}
var kinds: Dictionary = {} # kind -> {"scene": PackedScene, "aabb": AABB}
var recs: Array[StatueRec] = []
var _rebuild_timer: Timer
var _water: Node3D


func _ready() -> void:
	add_to_group("statue_field")
	for d in PARAM_DEFS:
		defaults[d["name"]] = d["default"]
	params = defaults.duplicate()
	_load_saved()

	_rebuild_timer = Timer.new()
	_rebuild_timer.one_shot = true
	_rebuild_timer.wait_time = 0.35
	_rebuild_timer.timeout.connect(_rebuild)
	add_child(_rebuild_timer)

	for kind in KEYWORDS:
		var path := _search(SEARCH_ROOT, KEYWORDS[kind])
		if path == "":
			push_warning("StatueField: no model found for '%s' (looking for '%s' under %s)." % [kind, KEYWORDS[kind], SEARCH_ROOT])
			continue
		var scene := load(path) as PackedScene
		if scene:
			kinds[kind] = {"scene": scene, "aabb": _measure(scene)}
	_rebuild()


# ------------------------------------------------------------ parameters

func get_param_defs() -> Array:
	return PARAM_DEFS


func get_param(pname: String) -> Variant:
	return params.get(pname)


func set_param(pname: String, value: Variant) -> void:
	if not params.has(pname):
		return
	params[pname] = value
	if RESPAWN_KEYS.has(pname):
		request_rebuild()
	else:
		_apply_all()


func reset_params() -> void:
	params = defaults.duplicate()
	request_rebuild()


func save_params() -> int:
	var cfg := ConfigFile.new()
	for k in params:
		cfg.set_value("statues", k, params[k])
	return cfg.save(SAVE_PATH)


func delete_saved() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return true
	return false


func _load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for d in PARAM_DEFS:
		var k: String = d["name"]
		if not cfg.has_section_key("statues", k):
			continue
		var v: Variant = cfg.get_value("statues", k)
		match d["type"]:
			"int":
				if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
					params[k] = int(v)
			"float":
				if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
					params[k] = float(v)
			"bool":
				if typeof(v) == TYPE_BOOL:
					params[k] = v
			"color":
				if typeof(v) == TYPE_COLOR:
					params[k] = v


# ------------------------------------------------------------ model loading

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


func _measure(scene: PackedScene) -> AABB:
	var m := scene.instantiate() as Node3D
	add_child(m)
	var box := _model_aabb(m)
	remove_child(m)
	m.free()
	return box


# ------------------------------------------------------------ spawning

func request_rebuild() -> void:
	if _rebuild_timer:
		_rebuild_timer.start() # restarts, so dragging a slider only rebuilds once it settles


func _rebuild() -> void:
	for r in recs:
		if is_instance_valid(r.root):
			r.root.queue_free()
	recs.clear()

	var requested := int(params["count"])
	if kinds.is_empty():
		layout_changed.emit(0, requested)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = int(params["random_seed"])
	var placed: Array[Vector2] = []
	var spawned := 0

	for i in requested:
		var kind := ""
		var pos := Vector2.ZERO
		var ok := false

		if params["use_preset_positions"] and i < PRESETS.size():
			kind = PRESETS[i]["kind"]
			pos = PRESETS[i]["pos"]
			ok = true
		else:
			kind = "augustus" if rng.randf() < float(params["augustus_share"]) else "vespasian"
			for t in MAX_TRIES:
				var c := Vector2(
					float(params["area_center_x"]) + rng.randf_range(-1.0, 1.0) * float(params["area_half_width"]),
					float(params["area_center_z"]) + rng.randf_range(-1.0, 1.0) * float(params["area_half_length"]))
				if _spot_is_free(c, placed):
					pos = c
					ok = true
					break

		# Always draw the same random numbers so earlier statues stay put when the count changes.
		var r_size := rng.randf_range(-1.0, 1.0)
		var r_subm := rng.randf_range(-1.0, 1.0)
		var r_tilt := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		var r_yaw := rng.randf_range(-1.0, 1.0)

		if not ok:
			continue
		if not kinds.has(kind):
			kind = kinds.keys()[0] # the other model is missing; use what we have
		placed.append(pos)
		_spawn(kind, pos, r_size, r_subm, r_tilt, r_yaw)
		spawned += 1

	_apply_all()
	layout_changed.emit(spawned, requested)


func _spot_is_free(c: Vector2, placed: Array[Vector2]) -> bool:
	if _distance_to_walkway(c) < float(params["min_walkway_distance"]):
		return false
	for p in placed:
		if c.distance_to(p) < float(params["min_spacing"]):
			return false
	return true


func _distance_to_walkway(c: Vector2) -> float:
	var best := INF
	for i in range(WALKWAY.size() - 1):
		var a: Vector2 = WALKWAY[i]
		var b: Vector2 = WALKWAY[i + 1]
		var ab := b - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, c.distance_to(a + ab * t))
	return best


func _spawn(kind: String, pos: Vector2, r_size: float, r_subm: float, r_tilt: Vector2, r_yaw: float) -> void:
	var rec := StatueRec.new()
	rec.kind = kind
	rec.r_size = r_size
	rec.r_subm = r_subm
	rec.r_tilt = r_tilt
	rec.r_yaw = r_yaw # -1..1, scaled by the yaw_randomness setting when used

	rec.root = Node3D.new()
	rec.root.name = "Statue_%s_%d" % [kind, recs.size()]
	add_child(rec.root)
	rec.root.position = Vector3(pos.x, _waterline(), pos.y)
	var d := FACE_POINT - rec.root.position
	rec.root.rotation.y = atan2(d.x, d.z) + deg_to_rad(rec.r_yaw * float(params["yaw_randomness"]))

	rec.pivot = Node3D.new()
	rec.pivot.name = "TiltPivot"
	rec.root.add_child(rec.pivot)

	rec.model = (kinds[kind]["scene"] as PackedScene).instantiate() as Node3D
	rec.pivot.add_child(rec.model)
	rec.meshes = _mesh_instances(rec.model)

	rec.light = SpotLight3D.new()
	rec.light.name = "StatueSpot"
	rec.light.light_volumetric_fog_energy = 1.5
	rec.light.spot_attenuation = 0.8
	rec.root.add_child(rec.light)

	recs.append(rec)


func _waterline() -> float:
	if params["follow_water"]:
		if _water == null or not is_instance_valid(_water):
			_water = get_tree().get_first_node_in_group("water") as Node3D
		if _water:
			return _water.global_position.y
	return float(params["waterline_y"])


# ------------------------------------------------------------ live updates

func _apply_all() -> void:
	for rec in recs:
		_apply_pose(rec)


func _apply_pose(rec: StatueRec) -> void:
	var box: AABB = kinds[rec.kind]["aabb"]
	if box.size.y <= 0.0001:
		return

	var h := float(params["height"])
	if rec.kind == "augustus":
		h *= float(params["augustus_height_scale"])
	h *= maxf(0.05, 1.0 + rec.r_size * float(params["size_variation"]))
	var subm := clampf(float(params["submerged_fraction"]) + rec.r_subm * float(params["submerged_variation"]), 0.0, 1.0)

	var s := h / box.size.y
	rec.model.scale = Vector3.ONE * s
	var cx := box.position.x + box.size.x * 0.5
	var cz := box.position.z + box.size.z * 0.5
	rec.model.position = Vector3(-cx * s, -subm * h - box.position.y * s, -cz * s)

	var tilt_r := float(params["tilt_randomness"])
	rec.pivot.rotation = Vector3(
		deg_to_rad(float(params["tilt_x"]) + rec.r_tilt.x * tilt_r),
		0.0,
		deg_to_rad(float(params["tilt_z"]) + rec.r_tilt.y * tilt_r))

	rec.root.visible = bool(params["show_statues"])
	var shadow_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if params["cast_shadows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in rec.meshes:
		mi.cast_shadow = shadow_mode

	var light := rec.light
	light.visible = bool(params["spotlight_enabled"])
	light.light_color = params["spotlight_color"]
	light.light_energy = float(params["spotlight_energy"])
	light.spot_range = h * float(params["spotlight_range_scale"])
	light.spot_angle = float(params["spotlight_angle"])
	light.shadow_enabled = bool(params["spotlight_shadows"])
	var light_pos := Vector3(h * float(params["spotlight_side_offset"]), h * 0.55, h * 0.9)
	var face_target := Vector3(0.0, (1.0 - subm) * h * 0.55, 0.0)
	light.transform = Transform3D(Basis(), light_pos).looking_at(face_target, Vector3.UP)


func _process(delta: float) -> void:
	if recs.is_empty():
		return

	var follow: bool = params["follow_water"]
	var y := _waterline() if follow else float(params["waterline_y"])

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var tracking: bool = params["track_player"] and player != null
	var max_step := deg_to_rad(float(params["turn_speed"])) * delta
	var idle_step := deg_to_rad(float(params["idle_spin_speed"])) * delta
	var range_limit := float(params["track_range"])
	var lead := float(params["lead_seconds"])
	var yaw_rand := float(params["yaw_randomness"])

	var target_pos := Vector3.ZERO
	if tracking:
		target_pos = player.global_position
		if player is CharacterBody3D:
			target_pos += (player as CharacterBody3D).velocity * lead

	for rec in recs:
		var root := rec.root
		root.position.y = y
		if tracking:
			var d := target_pos - root.global_position
			var flat := Vector2(d.x, d.z)
			if flat.length() < 0.01:
				continue
			if range_limit > 0.0 and flat.length() > range_limit:
				continue
			var target_yaw := atan2(d.x, d.z) + deg_to_rad(rec.r_yaw * yaw_rand)
			var diff := angle_difference(root.rotation.y, target_yaw)
			root.rotation.y += clampf(diff, -max_step, max_step)
		elif idle_step != 0.0:
			root.rotation.y += idle_step
