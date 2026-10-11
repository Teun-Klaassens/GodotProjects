extends CanvasLayer
## Unified In-Game Dashboard.
## Press TAB to open/close (Esc also closes).
## Features a top navigation bar to switch between:
##   1. Water Settings
##   2. Statue Manager
##   3. Options & Audio

const TOGGLE_KEY := KEY_TAB

# Nodes & references
var water_mesh: MeshInstance3D
var water_material: ShaderMaterial
var statue_field: Node
var audio_director: Node

# UI containers
var panel: PanelContainer
var nav_buttons: Array[Button] = []
var tab_containers: Array[Control] = []

# Status labels per tab
var water_status_label: Label
var statue_status_label: Label
var audio_status_label: Label
var audio_readout_label: Label

# UI control storage for values
var water_controls: Dictionary = {}
var statue_controls: Dictionary = {}
var audio_controls: Dictionary = {}

# Water parameter ranges & definitions
const WATER_SAVE_PATH := "user://water_settings.cfg"
const WATER_RANGES := {
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
	"roughness": ["Roughness", 0.0, 1.0, 0.005],
	"specular_strength": ["Highlight strength", 0.0, 4.0, 0.01],
	"diffuse_strength": ["Diffuse strength", 0.0, 2.0, 0.01],
	"reflection_strength": ["Reflection strength", 0.0, 1.0, 0.01],
	"fresnel_f0": ["Fresnel base reflectivity", 0.0, 1.0, 0.005],
	"sheen_strength": ["Oil sheen strength", 0.0, 3.0, 0.01],
	"refraction_strength": ["Refraction strength", 0.0, 0.2, 0.001],
	"surface_opacity": ["Surface opacity", 0.0, 1.0, 0.01],
	"sun_direction": ["Light direction", -1.0, 1.0, 0.01],
	"visible_depth": ["Visible depth", 0.05, 30.0, 0.05],
	"depth_falloff_steepness": ["Depth falloff steepness", 0.1, 4.0, 0.01],
	"foam_amount": ["Foam amount", 0.0, 3.0, 0.01],
	"foam_distance": ["Shore foam distance", 0.0, 8.0, 0.01],
	"foam_scale": ["Foam pattern scale", 0.01, 1.0, 0.005],
	"caustic_scale": ["Caustic scale", 0.01, 1.0, 0.005],
	"caustic_speed": ["Caustic speed", 0.0, 3.0, 0.01],
	"caustic_strength": ["Caustic strength", 0.0, 1.5, 0.01],
	"creature_disturbance_radius": ["Creature wake radius", 0.0, 200.0, 0.5],
}

const WATER_GROUPS := [
	["Water level", ["__water_level"]],
	["Waves", ["wave_height", "wave_time_scale", "base_wavelength", "base_speed", "octaves",
			"lacunarity", "persistence", "peak_sharpness", "domain_warp", "wave_lean", "wave_direction"]],
	["Surface", ["roughness", "specular_strength", "diffuse_strength", "reflection_strength",
			"fresnel_f0", "sheen_strength", "refraction_strength", "surface_opacity", "sun_direction"]],
	["Depth", ["visible_depth", "depth_falloff_steepness"]],
	["Foam", ["foam_amount", "foam_distance", "foam_scale"]],
	["Caustics", ["caustic_scale", "caustic_speed", "caustic_strength"]],
	["Colors", ["shallow_color", "deep_abyss_color", "foam_color", "ambient_color",
			"subsurface_color", "sheen_color", "highlight_color", "caustic_color"]],
	["Creature wake", ["creature_disturbance_radius"]],
]

const WATER_HIDDEN := {
	"creature_position": true,
	"creature_velocity": true,
}

var water_defaults: Dictionary = {}
var initial_water_height: float = 0.5


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_panel")

	water_mesh = _find_water()
	if water_mesh:
		initial_water_height = water_mesh.position.y
		water_material = _find_material(water_mesh)
		if water_material:
			_snapshot_water_defaults()
			_load_water_settings()

	statue_field = get_tree().get_first_node_in_group("statue_field")
	audio_director = get_tree().get_first_node_in_group("audio_director")

	_build_ui()
	panel.visible = false

	if statue_field and statue_field.has_signal("layout_changed"):
		statue_field.layout_changed.connect(_on_statue_layout_changed)


func _process(_delta: float) -> void:
	if is_open() and audio_readout_label and audio_director and audio_director.has_method("get_debug_readout"):
		audio_readout_label.text = audio_director.get_debug_readout()


func is_open() -> bool:
	return panel != null and panel.visible


func show_panel() -> void:
	if panel:
		_set_open(true)


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


func _set_open(open: bool) -> void:
	panel.visible = open
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("capture_mouse"):
		player.capture_mouse(not open)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


# ==============================================================================
# UI BUILDING
# ==============================================================================

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -480.0
	panel.offset_right = -10.0
	panel.offset_top = 10.0
	panel.offset_bottom = -10.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.94)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.18, 0.28, 0.38, 0.6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	# --- Top Header Bar ---
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	var title := Label.new()
	title.text = "SETTINGS & DEV CONSOLE"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Close menu (Tab / Esc)"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): _set_open(false))
	top_bar.add_child(close_btn)

	# --- Navigation Tab Bar ---
	var nav_bar := HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 6)
	root.add_child(nav_bar)

	var tab_names := ["🌊 Water", "🗿 Statues", "⚙️ Audio", "🎮 Gameplay & World"]
	for i in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_switch_tab.bind(i))
		nav_bar.add_child(btn)
		nav_buttons.append(btn)

	root.add_child(HSeparator.new())

	# --- Tab Containers ---
	var pages_container := PanelContainer.new()
	pages_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pages_style := StyleBoxEmpty.new()
	pages_container.add_theme_stylebox_override("panel", pages_style)
	root.add_child(pages_container)

	# Page 0: Water
	var water_page := _build_water_page()
	pages_container.add_child(water_page)
	tab_containers.append(water_page)

	# Page 1: Statues
	var statue_page := _build_statue_page()
	pages_container.add_child(statue_page)
	tab_containers.append(statue_page)

	# Page 2: Audio
	var options_page := _build_options_page()
	pages_container.add_child(options_page)
	tab_containers.append(options_page)

	# Page 3: Gameplay & Entities (Player, Creature, Lighting, Doors)
	var gameplay_page := _build_gameplay_page()
	pages_container.add_child(gameplay_page)
	tab_containers.append(gameplay_page)

	_switch_tab(0)


func _switch_tab(index: int) -> void:
	for i in range(tab_containers.size()):
		tab_containers[i].visible = (i == index)
		if i == index:
			nav_buttons[i].modulate = Color(1.2, 1.2, 1.3)
		else:
			nav_buttons[i].modulate = Color(0.7, 0.7, 0.7)


# ==============================================================================
# TAB 1: WATER SETTINGS
# ==============================================================================

func _build_water_page() -> Control:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)

	var buttons := HFlowContainer.new()
	page.add_child(buttons)
	_add_button(buttons, "Save", "Saves water settings; they load automatically next launch", _save_water_settings)
	_add_button(buttons, "Reset", "Back to original values", _reset_water_all)
	_add_button(buttons, "Delete save", "Removes the saved settings file", _delete_water_saved)
	_add_button(buttons, "Copy values", "Copies shader_parameter lines to clipboard", _copy_water_values)

	water_status_label = Label.new()
	water_status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	page.add_child(water_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	if water_material == null:
		var err := Label.new()
		err.text = "No WaterPlane or water ShaderMaterial found."
		err.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		list.add_child(err)
		return page

	var uniforms := _water_uniform_info()
	var placed := {}

	for group in WATER_GROUPS:
		var rows: Array = []
		for pname in group[1]:
			if pname == "__water_level" or uniforms.has(pname):
				rows.append(pname)
		if rows.is_empty():
			continue
		_add_header(list, group[0], Color(0.5, 0.8, 1.0))
		for pname in rows:
			placed[pname] = true
			if pname == "__water_level":
				_add_water_level(list)
			else:
				_add_water_param(list, pname, uniforms[pname])

	var extras: Array = []
	for pname in uniforms:
		if not placed.has(pname) and not WATER_HIDDEN.has(pname):
			extras.append(pname)
	if not extras.is_empty():
		_add_header(list, "Other", Color(0.5, 0.8, 1.0))
		for pname in extras:
			_add_water_param(list, pname, uniforms[pname])

	return page


func _add_water_level(parent: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "Water level (height)"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = -5.0
	slider.max_value = 10.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)

	var update_val := func(v: float):
		val_lbl.text = "%.2f" % v
		slider.value = v

	var current_y: float = water_mesh.position.y if water_mesh else initial_water_height
	update_val.call(current_y)

	slider.value_changed.connect(func(v: float):
		if water_mesh:
			water_mesh.position.y = v
		val_lbl.text = "%.2f" % v
	)
	water_controls["__water_level"] = update_val


func _add_water_param(parent: Control, pname: String, uinfo: Dictionary) -> void:
	var cur = water_material.get_shader_parameter(pname)
	if cur == null:
		cur = RenderingServer.shader_get_parameter_default(water_material.shader.get_rid(), pname)

	var title: String = WATER_RANGES.get(pname, [pname.capitalize()])[0]
	match uinfo.get("type", TYPE_FLOAT):
		TYPE_FLOAT:
			_add_water_float_slider(parent, pname, title, cur if cur != null else 0.0)
		TYPE_INT:
			_add_water_int_slider(parent, pname, title, cur if cur != null else 0)
		TYPE_BOOL:
			_add_water_bool_check(parent, pname, title, cur if cur != null else false)
		TYPE_COLOR:
			_add_water_color_picker(parent, pname, title, cur if cur != null else Color.WHITE)



func _add_water_float_slider(parent: Control, pname: String, title: String, cur) -> void:
	var min_v := 0.0
	var max_v := 1.0
	var step_v := 0.01
	if WATER_RANGES.has(pname):
		var r = WATER_RANGES[pname]
		min_v = r[1]
		max_v = r[2]
		step_v = r[3]

	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)

	var update_val := func(v: float):
		val_lbl.text = "%.2f" % v
		slider.value = v

	update_val.call(float(cur))
	slider.value_changed.connect(func(v: float):
		water_material.set_shader_parameter(pname, v)
		val_lbl.text = "%.2f" % v
	)
	water_controls[pname] = update_val


func _add_water_int_slider(parent: Control, pname: String, title: String, cur) -> void:
	var min_v := 0
	var max_v := 16
	if WATER_RANGES.has(pname):
		min_v = int(WATER_RANGES[pname][1])
		max_v = int(WATER_RANGES[pname][2])

	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(40, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)

	var update_val := func(v: int):
		val_lbl.text = str(v)
		slider.value = v

	update_val.call(int(cur))
	slider.value_changed.connect(func(v: float):
		water_material.set_shader_parameter(pname, int(v))
		val_lbl.text = str(int(v))
	)
	water_controls[pname] = update_val


func _add_water_bool_check(parent: Control, pname: String, title: String, cur) -> void:
	var check := CheckBox.new()
	check.text = title
	check.button_pressed = bool(cur)
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(t: bool):
		water_material.set_shader_parameter(pname, t)
	)
	parent.add_child(check)
	water_controls[pname] = func(v: bool): check.button_pressed = v


func _add_water_color_picker(parent: Control, pname: String, title: String, cur) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(60, 24)
	picker.color = cur if cur is Color else Color.BLACK
	picker.edit_alpha = true
	picker.focus_mode = Control.FOCUS_NONE
	picker.color_changed.connect(func(c: Color):
		water_material.set_shader_parameter(pname, c)
	)
	row.add_child(picker)
	water_controls[pname] = func(c: Color): picker.color = c


func _water_uniform_info() -> Dictionary:
	var out := {}
	if water_material == null or water_material.shader == null:
		return out
	for u in water_material.shader.get_shader_uniform_list():
		var pname: String = u["name"]
		var hint_string: String = u.get("hint_string", "")
		if u["type"] == TYPE_OBJECT:
			continue
		if hint_string.contains("texture"):
			continue
		out[pname] = u
	return out



func _snapshot_water_defaults() -> void:
	water_defaults.clear()
	water_defaults["__water_level"] = initial_water_height
	for u in _water_uniform_info().values():
		var val = water_material.get_shader_parameter(u.name)
		if val != null:
			water_defaults[u.name] = val


func _save_water_settings() -> void:
	if water_material == null:
		return
	var cfg := ConfigFile.new()
	if water_mesh:
		cfg.set_value("water", "__water_level", water_mesh.position.y)
	for pname in _water_uniform_info():
		if WATER_HIDDEN.has(pname):
			continue
		var val = water_material.get_shader_parameter(pname)
		if val != null:
			cfg.set_value("water", pname, val)
	var err := cfg.save(WATER_SAVE_PATH)
	if err == OK:
		water_status_label.text = "Saved water settings to %s" % WATER_SAVE_PATH
	else:
		water_status_label.text = "Failed to save: error %d" % err


func _load_water_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(WATER_SAVE_PATH) != OK:
		return
	if cfg.has_section_key("water", "__water_level") and water_mesh:
		water_mesh.position.y = cfg.get_value("water", "__water_level")
	for pname in cfg.get_section_keys("water"):
		if pname == "__water_level":
			continue
		water_material.set_shader_parameter(pname, cfg.get_value("water", pname))


func _reset_water_all() -> void:
	for pname in water_defaults:
		var v = water_defaults[pname]
		if pname == "__water_level" and water_mesh:
			water_mesh.position.y = v
		else:
			water_material.set_shader_parameter(pname, v)
		if water_controls.has(pname):
			water_controls[pname].call(v)
	water_status_label.text = "Reset water to shipped defaults."


func _delete_water_saved() -> void:
	if DirAccess.remove_absolute(WATER_SAVE_PATH) == OK:
		water_status_label.text = "Deleted %s." % WATER_SAVE_PATH
	else:
		water_status_label.text = "No saved file to delete."


func _copy_water_values() -> void:
	if water_material == null:
		return
	var lines: Array[String] = []
	for pname in _water_uniform_info():
		if WATER_HIDDEN.has(pname):
			continue
		var val = water_material.get_shader_parameter(pname)
		if val == null:
			continue
		if val is Color:
			lines.append('shader_parameter/%s = Color(%g, %g, %g, %g)' % [pname, val.r, val.g, val.b, val.a])
		elif val is float:
			lines.append('shader_parameter/%s = %g' % [pname, val])
		elif val is int:
			lines.append('shader_parameter/%s = %d' % [pname, val])
		elif val is bool:
			lines.append('shader_parameter/%s = %s' % [pname, "true" if val else "false"])
	DisplayServer.clipboard_set("\n".join(lines))
	water_status_label.text = "Copied %d parameters to clipboard." % lines.size()


# ==============================================================================
# TAB 2: STATUE MANAGER
# ==============================================================================

func _build_statue_page() -> Control:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)

	var buttons := HFlowContainer.new()
	page.add_child(buttons)
	_add_button(buttons, "Save", "Saves statue settings; they load automatically next launch", _on_statue_save)
	_add_button(buttons, "Reset", "Back to original values", _on_statue_reset)
	_add_button(buttons, "Delete save", "Removes saved settings file", _on_statue_delete)
	_add_button(buttons, "Re-roll layout", "Picks a new random layout seed", _on_statue_reroll)

	statue_status_label = Label.new()
	statue_status_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	statue_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(statue_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	if statue_field == null or not statue_field.has_method("get_param_defs"):
		var err := Label.new()
		err.text = "No StatueField found in scene."
		err.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		list.add_child(err)
		return page

	var last_group := ""
	for d in statue_field.get_param_defs():
		if d["group"] != last_group:
			last_group = d["group"]
			_add_header(list, last_group, Color(1.0, 0.8, 0.5))
		match d["type"]:
			"int", "float":
				_add_statue_slider(list, d)
			"bool":
				_add_statue_check(list, d)
			"color":
				_add_statue_color(list, d)

	return page


func _add_statue_slider(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var step := float(d["step"])
	var is_int: bool = (d["type"] == "int")
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = d["label"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(55, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = float(d["min"])
	slider.max_value = float(d["max"])
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)

	var update_val := func(v: Variant) -> void:
		val_lbl.text = _fmt_val(float(v), step, is_int)
		slider.set_value_no_signal(float(v))

	var initial_val = statue_field.get_param(pname)
	if initial_val != null:
		update_val.call(initial_val)

	slider.value_changed.connect(func(v: float):
		statue_field.set_param(pname, int(v) if is_int else v)
		val_lbl.text = _fmt_val(v, step, is_int)
	)
	statue_controls[pname] = update_val


func _add_statue_check(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var check := CheckBox.new()
	check.text = d["label"]
	check.button_pressed = bool(statue_field.get_param(pname))
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(t: bool):
		statue_field.set_param(pname, t)
	)
	parent.add_child(check)
	statue_controls[pname] = func(v: Variant) -> void: check.button_pressed = bool(v)


func _add_statue_color(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = d["label"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(60, 24)
	var cur_col = statue_field.get_param(pname)
	picker.color = cur_col if cur_col is Color else Color.WHITE
	picker.edit_alpha = false
	picker.focus_mode = Control.FOCUS_NONE
	picker.color_changed.connect(func(c: Color):
		statue_field.set_param(pname, c)
	)
	row.add_child(picker)
	statue_controls[pname] = func(c: Variant) -> void: picker.color = c if c is Color else Color.WHITE


func _on_statue_layout_changed(_spawned: int = 0, _requested: int = 0) -> void:
	for pname in statue_controls:
		if statue_field and statue_field.has_method("get_param"):
			var val = statue_field.get_param(pname)
			if val != null:
				statue_controls[pname].call(val)


func _on_statue_save() -> void:
	if statue_field and statue_field.has_method("save_params"):
		var err: int = statue_field.save_params()
		statue_status_label.text = "Saved statue settings." if err == OK else "Failed to save statue settings."


func _on_statue_reset() -> void:
	if statue_field and statue_field.has_method("reset_params"):
		statue_field.reset_params()
		_on_statue_layout_changed()
		statue_status_label.text = "Reset statues to shipped defaults."


func _on_statue_delete() -> void:
	if statue_field and statue_field.has_method("delete_saved"):
		var ok: bool = statue_field.delete_saved()
		statue_status_label.text = "Deleted saved statue settings." if ok else "No saved statue settings to delete."


func _on_statue_reroll() -> void:
	if statue_field and statue_field.has_method("set_param"):
		statue_field.set_param("random_seed", randi() % 10000)
		_on_statue_layout_changed()
		statue_status_label.text = "Re-rolled layout seed."



# ==============================================================================
# TAB 3: OPTIONS & AUDIO
# ==============================================================================

func _build_options_page() -> Control:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)

	var buttons := HFlowContainer.new()
	page.add_child(buttons)
	_add_button(buttons, "Save", "Saves audio & options settings", _on_audio_save)
	_add_button(buttons, "Reset", "Back to original values", _on_audio_reset)
	_add_button(buttons, "Delete save", "Removes saved settings file", _on_audio_delete)

	audio_status_label = Label.new()
	audio_status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	audio_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(audio_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	if audio_director == null or not audio_director.has_method("get_param_defs"):
		var err := Label.new()
		err.text = "No AudioDirector found in scene."
		err.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		list.add_child(err)
		return page

	# --- Debug tools ---
	_add_header(list, "Audio Debug Tools", Color(0.7, 0.9, 0.7))
	var tools := HFlowContainer.new()
	list.add_child(tools)
	_add_button(tools, "Play whale song now", "Plays whale song immediately", func(): audio_director.debug_play_whale())
	_add_button(tools, "Stop whale song", "", func(): audio_director.debug_stop_whale())
	_add_button(tools, "Restart underwater loop", "", func(): audio_director.debug_restart_underwater())

	audio_readout_label = Label.new()
	audio_readout_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	audio_readout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(audio_readout_label)

	# --- Dynamic param defs ---
	var last_group := ""
	for d in audio_director.get_param_defs():
		if d["group"] != last_group:
			last_group = d["group"]
			_add_header(list, last_group, Color(0.7, 0.9, 0.7))
		match d["type"]:
			"int", "float":
				_add_audio_slider(list, d)
			"bool":
				_add_audio_check(list, d)

	return page


func _add_audio_slider(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var step := float(d["step"])
	var is_int: bool = (d["type"] == "int")
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = d["label"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(55, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = float(d["min"])
	slider.max_value = float(d["max"])
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)

	var update_val := func(v: Variant) -> void:
		val_lbl.text = _fmt_val(float(v), step, is_int)
		slider.set_value_no_signal(float(v))

	var initial_val = audio_director.get_param(pname)
	if initial_val != null:
		update_val.call(initial_val)

	slider.value_changed.connect(func(v: float):
		audio_director.set_param(pname, int(v) if is_int else v)
		val_lbl.text = _fmt_val(v, step, is_int)
	)
	audio_controls[pname] = update_val


func _add_audio_check(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var check := CheckBox.new()
	check.text = d["label"]
	check.button_pressed = bool(audio_director.get_param(pname))
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(t: bool):
		audio_director.set_param(pname, t)
	)
	parent.add_child(check)
	audio_controls[pname] = func(v: Variant) -> void: check.button_pressed = bool(v)


func _on_audio_save() -> void:
	if audio_director and audio_director.has_method("save_params"):
		var err: int = audio_director.save_params()
		audio_status_label.text = "Saved audio settings." if err == OK else "Failed to save audio settings."


func _on_audio_reset() -> void:
	if audio_director and audio_director.has_method("reset_params"):
		audio_director.reset_params()
		for pname in audio_controls:
			if audio_director.has_method("get_param"):
				var val = audio_director.get_param(pname)
				if val != null:
					audio_controls[pname].call(val)
		audio_status_label.text = "Reset audio settings to defaults."


func _on_audio_delete() -> void:
	if audio_director and audio_director.has_method("delete_saved"):
		var ok: bool = audio_director.delete_saved()
		audio_status_label.text = "Deleted saved audio settings." if ok else "No saved settings to delete."


const GAMEPLAY_SAVE_PATH := "user://gameplay_settings.cfg"

var gameplay_status_label: Label
var gameplay_controls: Dictionary = {}

func _build_gameplay_page() -> Control:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)

	var buttons := HFlowContainer.new()
	page.add_child(buttons)
	_add_button(buttons, "Save", "Saves all gameplay & world settings to user config", _on_gameplay_save)
	_add_button(buttons, "Reset", "Resets to initial defaults", _on_gameplay_reset)
	_add_button(buttons, "Delete save", "Deletes saved configuration file", _on_gameplay_delete)

	gameplay_status_label = Label.new()
	gameplay_status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	gameplay_status_label.text = "Tune player movement, flashlight, monster speed, and lighting live."
	gameplay_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(gameplay_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# --- Load any previously saved gameplay settings ---
	_load_gameplay_settings()

	# --- 1. Player Movement & Look Exports ---
	var player = get_tree().get_first_node_in_group("player")
	_add_header(list, "🏃 Player Movement & Locomotion", Color(0.4, 0.8, 1.0))
	if player:
		_add_prop_slider(list, player, "walk_speed", "Walk Speed (m/s)", 1.0, 40.0, 0.5)
		_add_prop_slider(list, player, "sprint_speed", "Sprint Speed (m/s)", 2.0, 50.0, 0.5)
		_add_prop_slider(list, player, "wade_speed", "Wade / Swim Speed (m/s)", 1.0, 20.0, 0.2)
		_add_prop_slider(list, player, "acceleration", "Acceleration", 2.0, 50.0, 0.5)
		_add_prop_slider(list, player, "jump_velocity", "Jump Velocity", 1.0, 20.0, 0.5)
		_add_prop_slider(list, player, "gravity", "Gravity", 1.0, 40.0, 0.5)

		_add_header(list, "👀 Mouse & Look Sensitivity", Color(0.4, 0.8, 1.0))
		_add_prop_slider(list, player, "mouse_sensitivity", "Mouse Sensitivity", 0.0005, 0.01, 0.0002)
		_add_prop_slider(list, player, "min_pitch", "Min Pitch Look Angle", -89.0, 0.0, 1.0)
		_add_prop_slider(list, player, "max_pitch", "Max Pitch Look Angle", 0.0, 89.0, 1.0)

		_add_header(list, "🔦 Flashlight & Battery System", Color(1.0, 0.9, 0.4))
		_add_prop_slider(list, player, "max_battery", "Max Battery Capacity", 10.0, 200.0, 5.0)
		_add_prop_slider(list, player, "battery_drain_rate", "Battery Drain Rate (/sec)", 0.1, 10.0, 0.1)
		_add_prop_slider(list, player, "battery_recharge_rate", "Dynamo Recharge Rate (/sec)", 0.2, 10.0, 0.1)
		_add_prop_slider(list, player, "low_battery_threshold", "Low Battery Threshold (%)", 5.0, 50.0, 1.0)
	else:
		var no_p := Label.new()
		no_p.text = "Player node not found."
		no_p.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		list.add_child(no_p)

	# --- 2. Monster Eel Creature Exports ---
	var eel = get_tree().get_first_node_in_group("creature")
	_add_header(list, "🐉 Leviathan Eel Creature", Color(0.9, 0.3, 0.3))
	if eel:
		_add_prop_slider(list, eel, "swim_depth", "Patrol Swim Depth (m)", -25.0, -1.0, 0.5)
		_add_prop_slider(list, eel, "chase_speed", "Pursuit Speed (m/s)", 10.0, 50.0, 1.0)
		_add_prop_slider(list, eel, "turn_rate", "Lock-on Turn Rate", 2.0, 30.0, 1.0)
		_add_prop_slider(list, eel, "kill_radius", "Kill Radius Hitbox (m)", 3.0, 25.0, 0.5)
		_add_button(list, "Trigger Breach Leap Now", "Commands eel to launch into the air", func():
			if eel and eel.has_method("trigger_breach"):
				eel.trigger_breach()
		)
		_add_button(list, "Trigger Under-Walkway Pass", "Sends eel under the walkway", func():
			if eel and eel.has_method("trigger_under_walkway_pass"):
				eel.trigger_under_walkway_pass()
		)
	else:
		var no_e := Label.new()
		no_e.text = "Creature node not found."
		no_e.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		list.add_child(no_e)

	# --- 3. Ceiling Lights & Micro-Flicker ---
	var flicker = get_tree().get_first_node_in_group("ceiling_lights")
	if flicker == null:
		var scene := get_tree().current_scene
		if scene:
			flicker = scene.find_child("CeilingLights", true, false)
	_add_header(list, "💡 Ceiling Lights & Blackout Waves", Color(1.0, 0.8, 0.3))
	if flicker:
		_add_prop_slider(list, flicker, "micro_flicker_chance", "Micro-Flicker Twitch Chance", 0.0, 0.1, 0.002)
		_add_button(list, "Trigger Progressive Blackout", "Sweeps lights off towards player", func():
			if flicker and flicker.has_method("trigger_progressive_blackout"):
				flicker.trigger_progressive_blackout()
		)

	# --- 4. Heavy Doors ---
	_add_header(list, "🚪 Facility Airlocks & Doors", Color(0.7, 0.7, 0.8))
	var doors := get_tree().get_nodes_in_group("interactable")
	var found_door: Node = null
	for d in doors:
		if d is AnimatableBody3D and d.has_method("interact"):
			found_door = d
			break
	if found_door:
		_add_prop_slider(list, found_door, "open_height", "Door Opening Height (m)", 1.0, 8.0, 0.2)
		_add_prop_slider(list, found_door, "transition_duration", "Slide Transition Duration (s)", 0.5, 6.0, 0.1)

	return page


func _add_prop_slider(parent: Control, target_obj: Object, prop_name: String, label_text: String, min_v: float, max_v: float, step_v: float) -> void:
	if not (prop_name in target_obj):
		return

	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var cur_val: float = float(target_obj.get(prop_name))

	var val_lbl := Label.new()
	val_lbl.text = _fmt_val(cur_val, step_v, step_v >= 1.0)
	val_lbl.custom_minimum_size = Vector2(55, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = cur_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)

	slider.value_changed.connect(func(v: float):
		target_obj.set(prop_name, v)
		val_lbl.text = _fmt_val(v, step_v, step_v >= 1.0)
	)

	gameplay_controls[prop_name] = {
		"target": target_obj,
		"prop": prop_name,
		"slider": slider,
		"label": val_lbl,
		"step": step_v,
		"default": cur_val
	}


func _on_gameplay_save() -> void:
	var cfg := ConfigFile.new()
	for key in gameplay_controls:
		var item: Dictionary = gameplay_controls[key]
		var obj = item["target"]
		var prop: String = item["prop"]
		if is_instance_valid(obj) and prop in obj:
			cfg.set_value("gameplay", prop, obj.get(prop))

	var err := cfg.save(GAMEPLAY_SAVE_PATH)
	if err == OK:
		gameplay_status_label.text = "Saved all gameplay settings."
	else:
		gameplay_status_label.text = "Failed to save settings."


func _load_gameplay_settings() -> void:
	if not FileAccess.file_exists(GAMEPLAY_SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(GAMEPLAY_SAVE_PATH) != OK:
		return

	for key in cfg.get_section_keys("gameplay"):
		var val = cfg.get_value("gameplay", key)
		if gameplay_controls.has(key):
			var item: Dictionary = gameplay_controls[key]
			var obj = item["target"]
			if is_instance_valid(obj) and key in obj:
				obj.set(key, val)
				if item.has("slider") and item.has("label"):
					var sl: HSlider = item["slider"]
					var lb: Label = item["label"]
					sl.set_value_no_signal(float(val))
					lb.text = _fmt_val(float(val), item["step"], item["step"] >= 1.0)


func _on_gameplay_reset() -> void:
	for key in gameplay_controls:
		var item: Dictionary = gameplay_controls[key]
		var obj = item["target"]
		var prop: String = item["prop"]
		var def_val = item["default"]
		if is_instance_valid(obj) and prop in obj:
			obj.set(prop, def_val)
			var sl: HSlider = item["slider"]
			var lb: Label = item["label"]
			sl.set_value_no_signal(float(def_val))
			lb.text = _fmt_val(float(def_val), item["step"], item["step"] >= 1.0)
	gameplay_status_label.text = "Reset all gameplay settings to defaults."


func _on_gameplay_delete() -> void:
	if FileAccess.file_exists(GAMEPLAY_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GAMEPLAY_SAVE_PATH))
		gameplay_status_label.text = "Deleted saved gameplay configuration."
	else:
		gameplay_status_label.text = "No saved configuration file found."



# ==============================================================================
# HELPERS
# ==============================================================================

func _add_button(parent: Control, text: String, tip: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_header(parent: Control, text: String, color: Color) -> void:
	parent.add_child(HSeparator.new())
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)


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


func _fmt_val(v: float, step: float, is_int: bool) -> String:
	if is_int:
		return str(int(round(v)))
	if step <= 0.0:
		return "%.2f" % v
	var decimals := clampi(int(ceil(-log(step) / log(10.0))), 1, 4)
	return ("%." + str(decimals) + "f") % v
