extends CanvasLayer
## In-game statue ("model") settings panel. Press M to open/close (Esc also closes).
## It builds its controls from StatueField.PARAM_DEFS, so any setting added
## there shows up here automatically.

const TOGGLE_KEY := KEY_M

var field: Node # the StatueField
var panel: PanelContainer
var status_label: Label
var controls: Dictionary = {} # param name -> Callable(value) that updates only the UI


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_panel")
	field = get_tree().get_first_node_in_group("statue_field")
	if field == null:
		push_warning("ModelSettingsPanel: no StatueField found.")
		return
	_build_ui()
	panel.visible = false
	field.layout_changed.connect(_on_layout_changed)


func is_open() -> bool:
	return panel != null and panel.visible


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


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 10.0
	panel.offset_right = 440.0
	panel.offset_top = 10.0
	panel.offset_bottom = -10.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.92)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Model settings   (M / Esc to close)"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	var buttons := HFlowContainer.new()
	root.add_child(buttons)
	_add_button(buttons, "Save", "Saves these settings; they load automatically next launch", _on_save)
	_add_button(buttons, "Reset", "Back to the original shipped values", _on_reset)
	_add_button(buttons, "Delete save", "Removes the saved settings file", _on_delete)
	_add_button(buttons, "Re-roll layout", "Picks a new random layout seed", _on_reroll)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
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

	var last_group := ""
	for d in field.get_param_defs():
		if d["group"] != last_group:
			last_group = d["group"]
			_add_header(list, last_group)
		match d["type"]:
			"int", "float":
				_add_slider(list, d)
			"bool":
				_add_check(list, d)
			"color":
				_add_color(list, d)


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
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	parent.add_child(l)


func _add_slider(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var step := float(d["step"])
	var is_int: bool = d["type"] == "int"

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
	slider.value = float(field.get_param(pname))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	box.add_child(slider)
	value_label.text = _fmt(slider.value, step)

	slider.value_changed.connect(func(v: float):
		field.set_param(pname, int(v) if is_int else v)
		value_label.text = _fmt(v, step))
	controls[pname] = func(v: Variant) -> void:
		slider.set_value_no_signal(float(v))
		value_label.text = _fmt(float(v), step)


func _add_check(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var cb := CheckButton.new()
	cb.text = d["label"]
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(field.get_param(pname))
	cb.toggled.connect(func(on: bool): field.set_param(pname, on))
	parent.add_child(cb)
	controls[pname] = func(v: Variant) -> void:
		cb.set_pressed_no_signal(bool(v))


func _add_color(parent: Control, d: Dictionary) -> void:
	var pname: String = d["name"]
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = d["label"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(120, 26)
	picker.edit_alpha = false
	picker.color = field.get_param(pname)
	picker.color_changed.connect(func(c: Color): field.set_param(pname, c))
	row.add_child(picker)
	controls[pname] = func(v: Variant) -> void:
		picker.color = v


func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(v)))
	var decimals := clampi(int(ceil(-log(step) / log(10.0))), 1, 4)
	return ("%." + str(decimals) + "f") % v


func _refresh_controls() -> void:
	for pname in controls:
		controls[pname].call(field.get_param(pname))


# ---------------------------------------------------------------- actions

func _status(text: String) -> void:
	if status_label:
		status_label.text = text


func _on_layout_changed(spawned: int, requested: int) -> void:
	if spawned < requested:
		_status("Placed %d of %d statues. No room left: widen the area or lower spacing / walkway distance." % [spawned, requested])
	else:
		_status("%d statue(s) in the pool." % spawned)


func _on_save() -> void:
	var err: int = field.save_params()
	_status("Saved. Loads automatically next launch." if err == OK else "Save failed (error %d)" % err)


func _on_reset() -> void:
	field.reset_params()
	_refresh_controls()
	_status("Reset to original values (saved file untouched)")


func _on_delete() -> void:
	_status("Saved settings deleted" if field.delete_saved() else "No saved settings to delete")


func _on_reroll() -> void:
	field.set_param("random_seed", randi() % 10000)
	_refresh_controls()
