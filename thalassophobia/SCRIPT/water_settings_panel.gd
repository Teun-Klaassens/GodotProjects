extends CanvasLayer
## In-game water tuning panel.
## Press TAB to open/close (Esc also closes). Sliders edit the water shader
## live. "Copy values" puts the current settings on the clipboard as
## shader_parameter lines you can paste into MATERIAL/water_material.tres.

const TOGGLE_KEY := KEY_TAB
const SAVE_PATH := "user://water_settings.cfg" # loaded automatically at startup

# name -> [label, min, max, step]. Anything not listed here still gets a
# slider with an automatic range, so new shader uniforms show up on their own.
const RANGES := {
	# Waves
	"wave_height": ["Wave strength (height)", 0.0, 8.0, 0.01],
	"wave_time_scale": ["Wave speed (time scale)", 0.0, 4.0, 0.01],
	"base_wavelength": ["Wavelength", 2.0, 150.0, 0.5],
	"base_speed": ["Swell travel speed", 0.0, 10.0, 0.05],
	"octaves": ["Detail layers (octaves)", 1.0, 16.0, 1.0],
	"lacunarity": ["Detail frequency growth", 1.0, 2.5, 0.01],
	"persistence": ["Detail amplitude falloff", 0.1, 1.0, 0.01],
	"peak_sharpness": ["Crest sharpness", 0.0, 8.0, 0.05],
	"domain_warp": ["Wave warping", 0.0, 3.0, 0.01],
	"wave_lean": ["Wave lean (sideways push)", 0.0, 2.0, 0.01],
	"wave_direction": ["Wave direction (deg)", 0.0, 360.0, 1.0],
	# Surface look
	"roughness": ["Roughness", 0.0, 1.0, 0.005],
	"specular_strength": ["Highlight strength", 0.0, 4.0, 0.01],
	"diffuse_strength": ["Diffuse strength", 0.0, 2.0, 0.01],
	"reflection_strength": ["Reflection strength", 0.0, 1.0, 0.01],
	"fresnel_f0": ["Fresnel base reflectivity", 0.0, 1.0, 0.005],
	"sheen_strength": ["Oil sheen strength", 0.0, 3.0, 0.01],
	"refraction_strength": ["Refraction strength", 0.0, 0.2, 0.001],
	"surface_opacity": ["Surface opacity", 0.0, 1.0, 0.01],
	"sun_direction": ["Light direction", -1.0, 1.0, 0.01],
	# Depth
	"visible_depth": ["Visible depth", 0.05, 30.0, 0.05],
	"depth_falloff_steepness": ["Depth falloff steepness", 0.1, 4.0, 0.01],
	# Foam
	"foam_amount": ["Foam amount", 0.0, 3.0, 0.01],
	"foam_distance": ["Shore foam distance", 0.0, 8.0, 0.01],
	"foam_scale": ["Foam pattern scale", 0.01, 1.0, 0.005],
	# Caustics
	"caustic_scale": ["Caustic scale", 0.01, 1.0, 0.005],
	"caustic_speed": ["Caustic speed", 0.0, 3.0, 0.01],
	"caustic_strength": ["Caustic strength", 0.0, 1.5, 0.01],
	# Creature wake
	"creature_disturbance_radius": ["Creature wake radius", 0.0, 200.0, 0.5],
}

# Display order and grouping.
const GROUPS := [
	["Water level", ["__water_level"]],
	["Waves", ["wave_height", "wave_time_scale", "base_wavelength", "base_speed", "octaves",
			"lacunarity", "persistence", "peak_sharpness", "domain_warp", "wave_lean", "wave_direction"]],
	["Surface", ["roughness", "specular_strength", "diffuse_strength", "reflection_strength",
			"fresnel_f0", "sheen_strength", "refraction_strength", "surface_opacity", "sun_direction"]],
	["Depth", ["visible_depth", "depth_falloff_steepness"]],
	["Foam", ["foam_amount", "foam_distance", "foam_scale"]],
	["Caustics", ["caustic_scale", "caustic_speed", "caustic_strength"]],
	["Colors", ["shallow_color", "deep_abyss_color", "foam_color", "ambient_color",
			"diffuse_color", "specular_color", "sun_color", "oil_sheen_color"]],
	["Creature wake", ["creature_disturbance_radius"]],
]

const COLOR_LABELS := {
	"shallow_color": "Shallow water color",
	"deep_abyss_color": "Deep abyss color",
	"foam_color": "Foam color",
	"ambient_color": "Ambient color",
	"diffuse_color": "Diffuse color",
	"specular_color": "Highlight color",
	"sun_color": "Lamp reflection color",
	"oil_sheen_color": "Oil sheen color",
}

# Uniforms driven by scripts or by the engine; no sliders for these.
const HIDDEN := ["creature_position", "creature_velocity", "creature_surge_intensity"]

const WATER_LEVEL_RANGE := [-5.0, 20.0, 0.05]

var water: MeshInstance3D
var mat: ShaderMaterial
var defaults: Dictionary = {}
var default_water_level: float = 0.0
var controls: Dictionary = {} # param name -> Callable(value) that updates the control AND the water
var status_label: Label
var panel: PanelContainer
var level_slider: HSlider
var level_label: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_panel")
	water = _find_water()
	if water == null:
		push_warning("WaterSettingsPanel: no node in group 'water' found.")
		return
	mat = _find_material(water)
	if mat == null:
		push_warning("WaterSettingsPanel: water has no ShaderMaterial.")
		return
	default_water_level = water.global_position.y
	_build_ui()
	panel.visible = false
	_load_saved()


func _find_water() -> MeshInstance3D:
	var n := get_tree().get_first_node_in_group("water")
	if n is MeshInstance3D:
		return n
	var scene := get_tree().current_scene
	if scene:
		return scene.get_node_or_null("WaterPlane") as MeshInstance3D
	return null


func _find_material(m: MeshInstance3D) -> ShaderMaterial:
	if m.material_override is ShaderMaterial:
		return m.material_override
	if m.mesh and m.mesh.material is ShaderMaterial:
		return m.mesh.material
	return null


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if panel == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == TOGGLE_KEY:
			_set_open(not panel.visible)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and panel.visible:
			_set_open(false)
			get_viewport().set_input_as_handled()


func is_open() -> bool:
	return panel != null and panel.visible


func _set_open(open: bool) -> void:
	panel.visible = open
	# Only give the mouse back to the game when no settings panel is left open.
	var any_open := false
	for n in get_tree().get_nodes_in_group("settings_panel"):
		if n.has_method("is_open") and n.is_open():
			any_open = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("capture_mouse"):
		player.capture_mouse(not any_open)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if any_open else Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -430.0
	panel.offset_right = -10.0
	panel.offset_top = 10.0
	panel.offset_bottom = -10.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.09, 0.92)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Water settings   (Tab / Esc to close)"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	var buttons := HFlowContainer.new()
	root.add_child(buttons)
	_add_button(buttons, "Save", "Saves these settings; they load automatically next launch", _save_settings)
	_add_button(buttons, "Reset", "Back to the original shipped values", _reset_all)
	_add_button(buttons, "Delete save", "Removes the saved settings file", _delete_saved)
	_add_button(buttons, "Copy values", "Copies shader_parameter lines to the clipboard", _copy_values)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	root.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var uniforms := _uniform_info()
	var placed := {}

	for group in GROUPS:
		var rows: Array = []
		for pname in group[1]:
			if pname == "__water_level" or uniforms.has(pname):
				rows.append(pname)
		if rows.is_empty():
			continue
		_add_header(list, group[0])
		for pname in rows:
			placed[pname] = true
			if pname == "__water_level":
				_add_water_level(list)
			else:
				_add_param(list, pname, uniforms[pname])

	# Anything new in the shader that isn't listed above still gets a control.
	var extras: Array = []
	for pname in uniforms:
		if not placed.has(pname) and not HIDDEN.has(pname):
			extras.append(pname)
	if not extras.is_empty():
		_add_header(list, "Other")
		for pname in extras:
			_add_param(list, pname, uniforms[pname])


func _add_button(parent: Control, text: String, tip: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)


func _uniform_info() -> Dictionary:
	var out := {}
	for u in mat.shader.get_shader_uniform_list():
		var pname: String = u["name"]
		var hint_string: String = u.get("hint_string", "")
		if u["type"] == TYPE_OBJECT:
			continue # textures (depth / screen)
		if hint_string.contains("texture"):
			continue
		out[pname] = u
	return out


func _add_header(parent: Control, text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	parent.add_child(l)


func _add_water_level(parent: Control) -> void:
	var r := WATER_LEVEL_RANGE
	var res := _slider_row(parent, "Water height (Y)", r[0], r[1], r[2], default_water_level)
	level_slider = res[0]
	level_label = res[1]
	level_slider.value_changed.connect(func(v: float):
		water.global_position.y = v
		level_label.text = _fmt(v, r[2]))
	controls["__water_level"] = func(v: Variant) -> void:
		level_slider.value = float(v)
		water.global_position.y = float(v)
		level_label.text = _fmt(float(v), r[2])


func _add_param(parent: Control, pname: String, info: Dictionary) -> void:
	var current: Variant = mat.get_shader_parameter(pname)
	if current == null:
		current = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), pname)
	defaults[pname] = current
	var cfg: Array = RANGES.get(pname, [])
	var label_text: String = cfg[0] if cfg.size() > 0 else pname.capitalize()

	match info["type"]:
		TYPE_FLOAT, TYPE_INT:
			var lo := 0.0
			var hi := 1.0
			var step := 0.01
			if cfg.size() >= 4:
				lo = cfg[1]; hi = cfg[2]; step = cfg[3]
			else:
				var cur := float(current)
				hi = maxf(absf(cur) * 3.0, 1.0)
				if cur < 0.0:
					lo = -hi
				if info["type"] == TYPE_INT:
					step = 1.0
			var is_int: bool = info["type"] == TYPE_INT
			var res := _slider_row(parent, label_text, lo, hi, step, float(current))
			var slider: HSlider = res[0]
			var value_label: Label = res[1]
			slider.value_changed.connect(func(v: float):
				mat.set_shader_parameter(pname, int(v) if is_int else v)
				value_label.text = _fmt(v, step))
			controls[pname] = func(v: Variant) -> void:
				slider.value = float(v)
				mat.set_shader_parameter(pname, int(v) if is_int else float(v))
				value_label.text = _fmt(float(v), step)

		TYPE_VECTOR3:
			var lo3 := -1.0
			var hi3 := 1.0
			var step3 := 0.01
			if cfg.size() >= 4:
				lo3 = cfg[1]; hi3 = cfg[2]; step3 = cfg[3]
			var v3: Vector3 = current
			var axis_names := ["x", "y", "z"]
			var sliders: Array = []
			for i in 3:
				var res3 := _slider_row(parent, "%s %s" % [label_text, axis_names[i]], lo3, hi3, step3, v3[i])
				var s3: HSlider = res3[0]
				var l3: Label = res3[1]
				var idx := i
				s3.value_changed.connect(func(v: float):
					var cur3: Vector3 = mat.get_shader_parameter(pname)
					cur3[idx] = v
					mat.set_shader_parameter(pname, cur3)
					l3.text = _fmt(v, step3))
				sliders.append(s3)
			controls[pname] = func(v: Variant) -> void:
				var d: Vector3 = v
				for k in 3:
					(sliders[k] as HSlider).value = d[k]
				mat.set_shader_parameter(pname, d)

		TYPE_COLOR:
			var row := HBoxContainer.new()
			parent.add_child(row)
			var lbl := Label.new()
			lbl.text = COLOR_LABELS.get(pname, label_text)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
			var picker := ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(120, 26)
			picker.edit_alpha = false
			picker.color = current
			picker.color_changed.connect(func(c: Color): mat.set_shader_parameter(pname, c))
			row.add_child(picker)
			controls[pname] = func(v: Variant) -> void:
				picker.color = v
				mat.set_shader_parameter(pname, v)


## Returns [HSlider, value Label]
func _slider_row(parent: Control, text: String, lo: float, hi: float, step: float, value: float) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var name_label := Label.new()
	name_label.text = text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var value_label := Label.new()
	value_label.text = _fmt(value, step)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(70, 0)
	top.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = clampf(value, lo, hi)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE # keep keyboard (WASD) away from sliders
	box.add_child(slider)
	return [slider, value_label]


func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(v)))
	var decimals := clampi(int(ceil(-log(step) / log(10.0))), 1, 4)
	return ("%." + str(decimals) + "f") % v


# ---------------------------------------------------------------- actions

func _reset_all() -> void:
	for pname in controls:
		var d: Variant = default_water_level if pname == "__water_level" else defaults[pname]
		controls[pname].call(d)
	_status("Reset to original values (saved file untouched)")


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("water", "__water_level", water.global_position.y)
	for pname in defaults:
		cfg.set_value("water", pname, mat.get_shader_parameter(pname))
	var err := cfg.save(SAVE_PATH)
	if err == OK:
		_status("Saved. Loads automatically next launch.")
	else:
		_status("Save failed (error %d)" % err)


func _load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for pname in cfg.get_section_keys("water"):
		if not controls.has(pname):
			continue # shader changed since the save; skip unknown names
		var v: Variant = cfg.get_value("water", pname)
		if pname == "__water_level":
			controls[pname].call(v)
		elif typeof(v) == typeof(defaults[pname]) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and typeof(defaults[pname]) in [TYPE_INT, TYPE_FLOAT]):
			controls[pname].call(v)


func _delete_saved() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		_status("Saved settings deleted")
	else:
		_status("No saved settings to delete")


func _status(text: String) -> void:
	if status_label:
		status_label.text = text


func _copy_values() -> void:
	var lines: PackedStringArray = []
	lines.append("; water height (WaterPlane position.y) = %s" % str(snappedf(water.global_position.y, 0.001)))
	var names := defaults.keys()
	names.sort()
	for pname in names:
		var v: Variant = mat.get_shader_parameter(pname)
		lines.append("shader_parameter/%s = %s" % [pname, _to_tres(v)])
	DisplayServer.clipboard_set("\n".join(lines))
	_status("Copied to clipboard")


func _to_tres(v: Variant) -> String:
	match typeof(v):
		TYPE_COLOR:
			var c: Color = v
			return "Color(%s, %s, %s, %s)" % [snappedf(c.r, 0.0001), snappedf(c.g, 0.0001), snappedf(c.b, 0.0001), snappedf(c.a, 0.0001)]
		TYPE_VECTOR3:
			var vv: Vector3 = v
			return "Vector3(%s, %s, %s)" % [snappedf(vv.x, 0.0001), snappedf(vv.y, 0.0001), snappedf(vv.z, 0.0001)]
		TYPE_FLOAT:
			var f: float = v
			var s := str(snappedf(f, 0.0001))
			return s if (s.contains(".") or s.contains("e")) else s + ".0"
		_:
			return str(v)
