extends Node
class_name FacilityDirector
## Manages the game's core progression loop:
##   - Tracks the 3 Power Switches around the pool chamber.
##   - Escalates horror effects on each switch activation:
##       Switch 1: Turns on sector lights, eel shadows slowly glide right beneath the walkway!
##       Switch 2: Progressive blackout wave shutting down lights one by one towards the player!
##       Switch 3: Restores full power, sounds the blaring Emergency Klaxon alarm, and unlocks
##                 the Emergency Escape console at the Big Red Button!
##   - Pressing the Big Red Button triggers the timed Emergency Lockdown & rising water sequence
##     followed by the gargantuan eel breach!

signal objective_updated(text: String)

var switches_activated: int = 0
var total_switches: int = 3
var escape_unlocked: bool = false
var escape_sequence_active: bool = false
var escape_timer: float = 0.0

var alarm_audio: AudioStreamPlayer3D
var alarm_playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0
var alarm_phase: float = 0.0

var water_plane: Node3D
var initial_water_y: float = 0.5
var target_water_y: float = 0.5

var objective_label: Label
var hud_layer: CanvasLayer
var prompt_label: Label
var reticle_dot: ColorRect
var note_overlay: PanelContainer
var note_title_label: Label
var note_body_label: Label
var is_reading_note: bool = false

func _ready() -> void:
	add_to_group("facility_director")
	water_plane = get_tree().get_first_node_in_group("water") as Node3D
	if water_plane:
		initial_water_y = water_plane.global_position.y
		target_water_y = initial_water_y
	_setup_alarm_audio()
	_setup_hud()
	_update_objective("OBJECTIVE: Restore power to Grid Breakers (0/3)")

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)

	# 1. Objective Label (Top-Left)
	objective_label = Label.new()
	objective_label.anchor_left = 0.0
	objective_label.anchor_top = 0.0
	objective_label.offset_left = 24.0
	objective_label.offset_top = 24.0
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	objective_label.add_theme_constant_override("shadow_offset_x", 2)
	objective_label.add_theme_constant_override("shadow_offset_y", 2)
	hud_layer.add_child(objective_label)

	# 2. Reticle Dot (Center Screen)
	reticle_dot = ColorRect.new()
	reticle_dot.color = Color(1.0, 1.0, 1.0, 0.65)
	reticle_dot.custom_minimum_size = Vector2(4, 4)
	reticle_dot.set_anchors_preset(Control.PRESET_CENTER)
	reticle_dot.position = Vector2(-2, -2)
	reticle_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(reticle_dot)

	# 3. Dynamic Interaction Tooltip Prompt (Right below crosshair)
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-200, 24)
	prompt_label.size = Vector2(400, 32)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.text = ""
	hud_layer.add_child(prompt_label)

	# 4. Note Reading Overlay
	note_overlay = PanelContainer.new()
	note_overlay.set_anchors_preset(Control.PRESET_CENTER)
	note_overlay.position = Vector2(-260, -180)
	note_overlay.custom_minimum_size = Vector2(520, 360)
	note_overlay.visible = false

	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = Color(0.08, 0.09, 0.1, 0.94)
	bg_box.border_color = Color(0.65, 0.55, 0.35, 0.8)
	bg_box.set_border_width_all(2)
	bg_box.set_corner_radius_all(6)
	bg_box.content_margin_left = 24.0
	bg_box.content_margin_right = 24.0
	bg_box.content_margin_top = 20.0
	bg_box.content_margin_bottom = 20.0
	note_overlay.add_theme_stylebox_override("panel", bg_box)

	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 14)
	note_overlay.add_child(nv)

	note_title_label = Label.new()
	note_title_label.add_theme_font_size_override("font_size", 22)
	note_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	note_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(note_title_label)

	note_body_label = Label.new()
	note_body_label.add_theme_font_size_override("font_size", 14)
	note_body_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	note_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_body_label.custom_minimum_size = Vector2(470, 210)
	nv.add_child(note_body_label)

	var close_hint := Label.new()
	close_hint.text = "[E] or [Esc] to Close Log"
	close_hint.add_theme_font_size_override("font_size", 13)
	close_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(close_hint)

	hud_layer.add_child(note_overlay)

	# 5. Death Screen Overlay
	death_screen = ColorRect.new()
	death_screen.color = Color(0.04, 0.0, 0.01, 0.94)
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_screen.visible = false
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var death_vbox := VBoxContainer.new()
	death_vbox.set_anchors_preset(Control.PRESET_CENTER)
	death_vbox.position = Vector2(-300, -100)
	death_vbox.size = Vector2(600, 200)
	death_vbox.add_theme_constant_override("separation", 16)
	death_screen.add_child(death_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "CONSUMED BY THE DEEP"
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "You submerged into the beast's hunting ground."
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.65))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_vbox.add_child(sub_lbl)

	var restart_lbl := Label.new()
	restart_lbl.text = "Press [ENTER] or [SPACE] to Restart"
	restart_lbl.add_theme_font_size_override("font_size", 18)
	restart_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	restart_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_vbox.add_child(restart_lbl)

	hud_layer.add_child(death_screen)

var death_screen: ColorRect
var is_player_dead: bool = false

func trigger_player_death() -> void:
	if is_player_dead:
		return
	is_player_dead = true

	# Play jumpscare sting
	var ha = load("res://SCRIPT/horror_audio.gd")
	if ha:
		ha.play_2d(get_tree(), "jumpscare", 6.0)

	if death_screen:
		death_screen.visible = true
		death_screen.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(death_screen, "modulate:a", 1.0, 0.8)

	# Disable player movement
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_prompt(text: String) -> void:
	if prompt_label and not is_reading_note and not is_player_dead:
		prompt_label.text = text

func display_note(title: String, body: String) -> void:
	if note_title_label and note_body_label and note_overlay and not is_player_dead:
		note_title_label.text = title
		note_body_label.text = body
		note_overlay.visible = true
		is_reading_note = true
		if prompt_label:
			prompt_label.text = ""

func close_note() -> void:
	if note_overlay:
		note_overlay.visible = false
	is_reading_note = false

func _unhandled_input(event: InputEvent) -> void:
	if is_player_dead:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				var vp := get_viewport()
				if vp:
					vp.set_input_as_handled()
				get_tree().reload_current_scene()
		return

	if is_reading_note:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_E or event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				close_note()
				var vp := get_viewport()
				if vp:
					vp.set_input_as_handled()

func _update_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text
	objective_updated.emit(text)

func _setup_alarm_audio() -> void:
	alarm_audio = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.3
	alarm_audio.stream = gen
	alarm_audio.unit_size = 80.0
	alarm_audio.max_distance = 1200.0
	add_child(alarm_audio)
	alarm_audio.play()
	alarm_playback = alarm_audio.get_stream_playback() as AudioStreamGeneratorPlayback

func activate_switch(switch_id: int) -> void:
	switches_activated += 1
	var eel = get_tree().get_first_node_in_group("creature")
	var flicker = get_tree().get_first_node_in_group("ceiling_lights")
	if flicker == null:
		var scene := get_tree().current_scene
		if scene:
			flicker = scene.find_child("CeilingLights", true, false)

	match switches_activated:
		1:
			_update_objective("OBJECTIVE: Power Restored to Sector 1. Locate Breakers (1/3)")
			# Scare 1: The colossal creature shadow slowly swims directly beneath the walkway!
			if eel and eel.has_method("trigger_under_walkway_pass"):
				eel.trigger_under_walkway_pass()
		2:
			_update_objective("OBJECTIVE: Power Surging. Locate Final Breaker (2/3)")
			# Scare 2: Progressive blackout wave plunging lights into darkness towards the player!
			if flicker and flicker.has_method("trigger_progressive_blackout"):
				flicker.trigger_progressive_blackout()
		3:
			escape_unlocked = true
			_update_objective("WARNING: FACILITY OVERLOAD! Proceed to Overlook Emergency Console!")
			# Scare 3: Emergency Klaxon sirens spin up, water begins churning
			var displacement = get_tree().get_first_node_in_group("water_displacement")
			if displacement and displacement.has_method("trigger_sonic_displacement"):
				displacement.trigger_sonic_displacement()

func start_escape_sequence() -> void:
	if escape_sequence_active:
		return
	escape_sequence_active = true
	escape_timer = 0.0
	target_water_y = initial_water_y + 1.2 # Water rises by 1.2m, flooding walkways!
	_update_objective("EMERGENCY LOCKDOWN: EVACUATE TO THE ENTRANCE DOOR!")

	# Trigger colossal creature breach!
	var eel = get_tree().get_first_node_in_group("creature")
	if eel and eel.has_method("trigger_breach"):
		eel.trigger_breach()

func _physics_process(delta: float) -> void:
	# Water rising animation during emergency escape
	if escape_sequence_active and water_plane:
		water_plane.global_position.y = move_toward(water_plane.global_position.y, target_water_y, delta * 0.12)
		escape_timer += delta

func _process(delta: float) -> void:
	if alarm_playback == null or not escape_unlocked:
		return

	# Generate realistic echoing industrial klaxon wail
	var frames := alarm_playback.get_frames_available()
	for i in range(frames):
		alarm_phase += 1.0 / sample_rate
		var cycle := fmod(alarm_phase * 0.6, 1.0)
		# Siren sweeps from 480Hz up to 880Hz then drops
		var freq := 480.0 + sin(cycle * PI) * 400.0
		var tone := sin(alarm_phase * freq * TAU)
		var sample := tone * 0.45
		alarm_playback.push_frame(Vector2(sample, sample))
