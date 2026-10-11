extends CanvasLayer
## Options / Debug screen for development. Press O to open/close (Esc also closes).
## Controls for the sound behaviour (underwater loop, footsteps, whale song) are built
## from AudioDirector.PARAM_DEFS. There are also test buttons, a live readout, and
## shortcuts to the Water and Model settings panels.

const TOGGLE_KEY := KEY_O

var director: Node # the AudioDirector
var panel: PanelContainer
var status_label: Label
var readout_label: Label
var controls: Dictionary = {} # param name -> Callable(value) that updates only the UI


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_panel")
	director = get_tree().get_first_node_in_group("audio_director")
	if director == null:
		push_warning("OptionsMenu: no AudioDirector found.")
		return
	_build_ui()
	panel.visible = false


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


func _process(_delta: float) -> void:
	if panel and panel.visible and readout_label:
		readout_label.text = director.get_debug_text()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -230.0
	panel.offset_right = 230.0
	panel.offset_top = 10.0
	panel.offset_bottom = -10.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.05, 0.94)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Options / Debug   (O / Esc to close)"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	var buttons := HFlowContainer.new()
	root.add_child(buttons)
	_add_button(buttons, "Save", "Saves these settings; they load automatically next launch", _on_save)
	_add_button(buttons, "Reset", "Back to the original shipped values", _on_reset)
	_add_button(buttons, "Delete save", "Removes the saved settings file", _on_delete)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	# --- Debug tools
	_add_header(list, "Debug tools")
	var tools := HFlowContainer.new()
	list.add_child(tools)
	_add_button(tools, "Play whale song now", "Plays the whale song immediately, ignoring distance and cooldown", func(): director.debug_play_whale())
	_add_button(tools, "Stop whale song", "", func(): director.debug_stop_whale())
	_add_button(tools, "Restart underwater loop", "", func(): director.debug_restart_underwater())

	readout_label = Label.new()
	readout_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	readout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(readout_label)

	# --- Other panels
	_add_header(list, "Other settings screens")
	var others := HFlowContainer.new()
	list.add_child(others)
	_add_button(others, "Water settings (Tab)", "", func(): _open_other("WaterSettings"))
	_add_button(others, "Model settings (M)", "", func(): _open_other("ModelSettings"))

	# --- Sound settings (generated)
	var last_group := ""
	for d in director.get_param_defs():
		if d["group"] != last_group:
			last_group = d["group"]
			_add_header(list, last_group)
		match d["type"]:
			"float":
				_add_slider(list, d)
			"bool":
				_add_check(list, d)


func _open_other(node_name: String) -> void:
	var scene := get_tree().current_scene
	var n := scene.get_node_or_null(node_name) if scene else null
	if n and n.has_method("show_panel"):
		n.show_panel()


func _add_button(parent: Control, text: String, tip: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_header(parent: Control, text: String) -> void:
	parent.add_child(HSeparator.new())
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	parent.add_child(l)


func _add_slider(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var step := float(d["step"])

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var name_label := Label.new()
	name_label.text = d["label"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(70, 0)
	top.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = float(d["min"])
	slider.max_value = float(d["max"])
	slider.step = step
	slider.value = float(director.get_param(pname))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	box.add_child(slider)
	value_label.text = _fmt(slider.value, step)

	slider.value_changed.connect(func(v: float):
		director.set_param(pname, v)
		value_label.text = _fmt(v, step))
	controls[pname] = func(v: Variant) -> void:
		slider.set_value_no_signal(float(v))
		value_label.text = _fmt(float(v), step)


func _add_check(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var cb := CheckButton.new()
	cb.text = d["label"]
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(director.get_param(pname))
	cb.toggled.connect(func(on: bool): director.set_param(pname, on))
	parent.add_child(cb)
	controls[pname] = func(v: Variant) -> void:
		cb.set_pressed_no_signal(bool(v))


func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(v)))
	var decimals := clampi(int(ceil(-log(step) / log(10.0))), 1, 4)
	return ("%." + str(decimals) + "f") % v


# ---------------------------------------------------------------- actions

func _status(text: String) -> void:
	if status_label:
		status_label.text = text


func _on_save() -> void:
	var err: int = director.save_params()
	_status("Saved. Loads automatically next launch." if err == OK else "Save failed (error %d)" % err)


func _on_reset() -> void:
	director.reset_params()
	for pname in controls:
		controls[pname].call(director.get_param(pname))
	_status("Reset to original values (saved file untouched)")


func _on_delete() -> void:
	_status("Saved settings deleted" if director.delete_saved() else "No saved settings to delete")
