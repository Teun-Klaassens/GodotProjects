extends Node2D

const BuildGrid = preload("res://scripts/components/build_grid.gd")
const FactoryData = preload("res://scripts/components/factory_data.gd")
const FactorySimulation = preload("res://scripts/components/factory_simulation.gd")
const MilestoneProgress = preload("res://scripts/components/milestone_progress.gd")
const SaveManager = preload("res://scripts/components/save_manager.gd")
const HistoryChart = preload("res://scripts/components/history_chart.gd")
const BeltVisuals = preload("res://scripts/components/belt_visuals.gd")
const BuildCatalog = preload("res://scripts/ui/build_catalog.gd")
const PowerWires = preload("res://scripts/components/power_wires.gd")

const TILE: int = BuildGrid.TILE_SIZE
const TOOLS: Array[int] = [1,2,3,4,7,8,9,10,11,6,5]
const BUILD_COLORS: Dictionary = {
 2: Color("d6aa6a"), 3: Color("a8a2cf"), 4: Color("76c4ba"),
 6: Color("a78bea"), 7: Color("ce966e"), 8: Color("d3ad71"),
 9: Color("8cbfe4"), 10: Color("678dce"), 11: Color("8fcbd1")}

@onready var camera: Camera2D = $Camera2D
@onready var canvas: CanvasLayer = $CanvasLayer

var grid: BuildGrid = BuildGrid.new()
var sim: FactorySimulation
var milestones: MilestoneProgress = MilestoneProgress.new()
var visuals: BeltVisuals
var inv: Dictionary = FactoryData.STARTER_INVENTORY.duplicate(true)
var machine_sprites: Dictionary = {}
var item_sprites: Dictionary = {}
var selected_tool: int = 1
var rotation_index: int = 0
var selected_machine: Vector2i = Vector2i(-1,-1)
var dragging_belt: bool = false
var belt_start: Vector2i = Vector2i.ZERO
var belt_end: Vector2i = Vector2i.ZERO
var dragging_camera: bool = false
var show_grid: bool = true
var paused: bool = false
var inventory_open: bool = false
var stats_open: bool = false
var music_enabled: bool = false
var notice: String = "Welcome! Use DEMO to try a working production line."
var notice_seconds: float = 9.0
var clock: float = 0.0
var autosave_clock: float = 0.0
var ui_clock: float = 0.0
var hud_root: Control
var build_catalog: BuildCatalog
var wire_layer: PowerWires
var status_panel: PanelContainer
var actions_panel: PanelContainer
var toolbar_panel: PanelContainer
var toolbar_row: HBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var hotbar_slots: Array[int] = [1,2,3,4,11,9,8,6,7,5]
var selected_slot: int = 0
var top_label: Label
var inventory_label: Label
var inspector_label: Label
var inspect_panel: PanelContainer
var inventory_panel: PanelContainer
var stats_panel: PanelContainer
var stats_label: Label
var chart: HistoryChart
var recipe_choice: OptionButton
var tool_buttons: Dictionary = {}
var music: AudioStreamPlayer
var click_audio: AudioStreamPlayer

func _ready() -> void:
 visuals = BeltVisuals.new()
 sim = FactorySimulation.new(grid)
 sim.delivery_callback = Callable(self,"_on_delivered")
 camera.position = Vector2(13, 11) * float(TILE)
 for kind in BUILD_COLORS.keys():
  var filename: String = str({2:"miner",3:"smelter",4:"constructor",6:"hub",7:"assembler",8:"storage",9:"generator",10:"coal_generator",11:"power_pole"}[kind])
  machine_sprites[kind] = load("res://assets/sprites/" + filename + ".png")
 for item in ["iron_ore","copper_ore","limestone","coal","iron_ingot","copper_ingot","iron_plate","iron_rod","copper_wire","concrete","reinforced_plate","circuit"]:
  item_sprites[item] = load("res://assets/sprites/item_" + item + ".png")
 wire_layer = PowerWires.new()
 add_child(wire_layer)
 wire_layer.configure(grid, sim.power)
 _load_hotbar_config()
 _create_ui()
 _create_audio()
 _update_ui()

func _create_audio() -> void:
 music = AudioStreamPlayer.new()
 add_child(music)
 music.stream = load("res://assets/audio/ambient_loop.wav")
 music.volume_db = -21.0
 music.finished.connect(_restart_music)
 click_audio = AudioStreamPlayer.new()
 add_child(click_audio)
 click_audio.stream = load("res://assets/audio/place.wav")
 click_audio.volume_db = -18.0

func _restart_music() -> void:
 if music_enabled:
  music.play()

func _toggle_music() -> void:
 music_enabled = not music_enabled
 if music_enabled:
  music.play()
 else:
  music.stop()
 _say("Music " + ("ON" if music_enabled else "OFF"))

func _label(text: String, font_size: int = 14) -> Label:
 var node: Label = Label.new()
 node.text = text
 node.add_theme_font_size_override("font_size",font_size)
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 return node

func _button(label_text: String, callable: Callable) -> Button:
 return BuildCatalog.btn(label_text,callable)

func _panel(x: float, y: float, w: float, h: float) -> PanelContainer:
 var p: PanelContainer = PanelContainer.new()
 p.position = Vector2(x,y)
 p.custom_minimum_size = Vector2(w,h)
 p.size = Vector2(w,h)
 p.add_theme_stylebox_override("panel",BuildCatalog.flat(Color("152533",0.96),Color("415565",0.85),10))
 hud_root.add_child(p)
 return p

func _create_ui() -> void:
 hud_root = Control.new()
 canvas.add_child(hud_root)
 hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 # A compact always-visible status strip instead of a full-height build list.
 status_panel = _panel(10,10,745,77)
 var status_v: VBoxContainer = VBoxContainer.new()
 status_v.add_theme_constant_override("separation",3)
 status_panel.add_child(status_v)
 status_v.add_child(_label("OVERCLOCKED     /     FACTORY STATUS",17))
 top_label = _label("",12)
 status_v.add_child(top_label)
 actions_panel = _panel(767,10,503,77)
 var actions: HBoxContainer = HBoxContainer.new()
 actions.add_theme_constant_override("separation",5)
 actions_panel.add_child(actions)
 var controls: Array = [
  ["B  BUILD",Callable(self,"_toggle_build_catalog")],
  ["DEMO",Callable(self,"_load_demo")],
  ["SAVE",Callable(self,"_save")],
  ["LOAD",Callable(self,"_load")],
  ["I  BAG",Callable(self,"_toggle_inventory")],
  ["TAB",Callable(self,"_toggle_stats")],
  ["M",Callable(self,"_toggle_music")]
 ]
 for pair in controls:
  var action_button: Button = BuildCatalog.btn(str(pair[0]),pair[1])
  action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  actions.add_child(action_button)
 toolbar_panel = _panel(185,645,910,66)
 toolbar_row = HBoxContainer.new()
 toolbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
 toolbar_row.add_theme_constant_override("separation",5)
 toolbar_panel.add_child(toolbar_row)
 _rebuild_hotbar()
 toast_panel = _panel(315,591,650,44)
 toast_label = _label("",13)
 toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 toast_panel.add_child(toast_label)
 # Collapsible right-side drawers, never shown on top of the build catalog.
 inspect_panel = _panel(977,101,293,345)
 var inspect_v: VBoxContainer = VBoxContainer.new()
 inspect_v.add_theme_constant_override("separation",11)
 inspect_panel.add_child(inspect_v)
 inspect_v.add_child(_label("MACHINE INSPECTOR",18))
 inspector_label = _label("Right-click a machine to inspect it.",13)
 inspect_v.add_child(inspector_label)
 recipe_choice = OptionButton.new()
 recipe_choice.item_selected.connect(_recipe_changed)
 inspect_v.add_child(recipe_choice)
 inspect_v.add_child(_button("Collect output",_collect_output))
 inspect_v.add_child(_button("Toggle machine [E]",_toggle_machine))
 inspect_v.add_child(_button("Close",_close_inspector))
 inspect_panel.visible = false
 inventory_panel = _panel(978,101,291,443)
 var inventory_v: VBoxContainer = VBoxContainer.new()
 inventory_panel.add_child(inventory_v)
 inventory_v.add_child(_label("INVENTORY  [I]",18))
 inventory_label = _label("",12)
 inventory_v.add_child(inventory_label)
 inventory_panel.visible = false
 stats_panel = _panel(244,168,792,385)
 var stat_v: VBoxContainer = VBoxContainer.new()
 stats_panel.add_child(stat_v)
 stat_v.add_child(_label("FACTORY ANALYTICS  [TAB]",19))
 chart = HistoryChart.new()
 chart.custom_minimum_size = Vector2(710,250)
 stat_v.add_child(chart)
 stats_label = _label("Production  •  Consumption  •  Deliveries  •  Power demand / supply",12)
 stat_v.add_child(stats_label)
 stats_panel.visible = false
 build_catalog = BuildCatalog.new()
 hud_root.add_child(build_catalog)
 build_catalog.build_requested.connect(_catalog_build_selected)
 build_catalog.hotbar_requested.connect(_catalog_hotbar_selected)
 get_viewport().size_changed.connect(_layout_ui)
 _layout_ui()

func _layout_ui() -> void:
 if status_panel == null:
  return
 var vp: Vector2 = get_viewport_rect().size
 status_panel.position = Vector2(10,10)
 status_panel.size = Vector2(maxf(420,vp.x*0.58),77)
 actions_panel.position = Vector2(status_panel.position.x + status_panel.size.x + 9,10)
 actions_panel.size = Vector2(maxf(350,vp.x-actions_panel.position.x-10),77)
 toolbar_panel.position = Vector2((vp.x-910)*0.5,vp.y-75)
 toast_panel.position = Vector2((vp.x-650)*0.5,vp.y-129)
 inspect_panel.position = Vector2(vp.x-303,99)
 inventory_panel.position = Vector2(vp.x-303,99)
 stats_panel.position = Vector2((vp.x-792)*0.5,(vp.y-385)*0.5)

func _load_hotbar_config() -> void:
 var settings: ConfigFile = ConfigFile.new()
 if settings.load("user://overclocked_hud.cfg") != OK:
  return
 var saved: Array = settings.get_value("hotbar","slots",[])
 if saved.size() != hotbar_slots.size():
  return
 for i in range(saved.size()):
  var kind: int = int(saved[i])
  if FactoryData.NAMES.has(kind):
   hotbar_slots[i] = kind

func _save_hotbar_config() -> void:
 var settings: ConfigFile = ConfigFile.new()
 settings.set_value("hotbar","slots",hotbar_slots)
 settings.save("user://overclocked_hud.cfg")

func _rebuild_hotbar() -> void:
 for child in toolbar_row.get_children():
  toolbar_row.remove_child(child)
  child.queue_free()
 tool_buttons.clear()
 for slot in range(hotbar_slots.size()):
  var kind: int = hotbar_slots[slot]
  var button: Button = BuildCatalog.btn("",_hotbar_clicked.bind(slot))
  button.custom_minimum_size = Vector2(81,51)
  button.tooltip_text = "%d: %s — %s" % [((slot+1)%10),str(FactoryData.NAMES.get(kind,"Unknown")),FactoryData.format_items(FactoryData.COSTS.get(kind,{}))]
  toolbar_row.add_child(button)
  tool_buttons[slot] = button
  var content: VBoxContainer = VBoxContainer.new()
  content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  content.mouse_filter = Control.MOUSE_FILTER_IGNORE
  button.add_child(content)
  var icon: TextureRect = TextureRect.new()
  icon.texture = BuildCatalog.picture(kind)
  icon.custom_minimum_size.y = 31
  icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  content.add_child(icon)
  var label: Label = _label("%d  %s" % [((slot+1)%10),str(FactoryData.NAMES.get(kind,"?") )],9)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  content.add_child(label)

func _hotbar_clicked(slot: int) -> void:
 _select_tool(hotbar_slots[slot])
 selected_slot = slot

func _toggle_build_catalog() -> void:
 if build_catalog.visible:
  build_catalog.hide_catalog()
 else:
  dragging_belt = false
  _close_inspector()
  inventory_panel.visible = false
  inventory_open = false
  stats_panel.visible = false
  stats_open = false
  build_catalog.open_catalog(inv,milestones.stage,selected_slot)

func _catalog_build_selected(kind: int) -> void:
 _select_tool(kind)
 _say("Selected %s — left-click the grass to build" % FactoryData.NAMES[kind],3.0)

func _catalog_hotbar_selected(kind: int) -> void:
 var slot: int = selected_slot
 hotbar_slots[slot] = kind
 _save_hotbar_config()
 _rebuild_hotbar()
 _select_tool(kind)
 selected_slot = slot
 _say("Assigned %s to hotbar slot %d" % [FactoryData.NAMES[kind],((selected_slot+1)%10)],3.0)

func _select_tool(tool: int) -> void:
 selected_tool = tool
 for i in range(hotbar_slots.size()):
  if hotbar_slots[i] == tool:
   selected_slot = i
   break
 selected_machine = Vector2i(-1,-1)
 inspect_panel.visible = false
 _say("Selected " + str(FactoryData.NAMES.get(tool,"Unknown")),1.8)

func _toggle_inventory() -> void:
 inventory_open = not inventory_open
 inventory_panel.visible = inventory_open
 if inventory_open:
  _close_inspector()

func _toggle_stats() -> void:
 stats_open = not stats_open
 stats_panel.visible = stats_open

func _close_inspector() -> void:
 inspect_panel.visible = false
 selected_machine = Vector2i(-1,-1)

func _on_delivered(item: String) -> void:
 milestones.receive_item(item)
 inv[item] = int(inv.get(item,0)) + 1
 if milestones.unlock_notice != "":
  _say(milestones.unlock_notice,7.0)
  milestones.unlock_notice = ""

func _say(message: String, seconds: float = 3.0) -> void:
 notice = message
 notice_seconds = seconds

func _process(delta: float) -> void:
 var axis: Vector2 = Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
 if axis.length_squared() > 0 and not build_catalog.visible:
  camera.position += axis.normalized() * 650.0 * delta / camera.zoom.x
 camera.position.x = clampf(camera.position.x,0.0,BuildGrid.WIDTH * float(TILE))
 camera.position.y = clampf(camera.position.y,0.0,BuildGrid.HEIGHT * float(TILE))
 clock += delta
 if not paused:
  sim.tick(delta)
  autosave_clock += delta
  if autosave_clock >= 60.0:
   autosave_clock = 0.0
   SaveManager.save_game(grid,sim,milestones,inv,camera)
 notice_seconds -= delta
 ui_clock -= delta
 if ui_clock <= 0:
  ui_clock = 0.2
  _update_ui()
 queue_redraw()
 wire_layer.queue_redraw()

func _update_ui() -> void:
 var message: String = notice if notice_seconds > 0 else "B: Build catalog  •  V: Wires  •  Shift: Ports  •  Right-click: Inspect  •  R: Rotate"
 toast_label.text = message
 var pause_text: String = "PAUSED   •   " if paused else ""
 top_label.text = "%s%s\n%s     •     Produced %d  /  Delivered %d" % [pause_text,milestones.summary(),sim.power.summary(),sim.produced_total,sim.delivered_total]
 for slot in tool_buttons.keys():
  var button: Button = tool_buttons[slot]
  var kind: int = hotbar_slots[slot]
  var chosen: bool = selected_tool == kind and selected_slot == slot
  button.add_theme_stylebox_override("normal",BuildCatalog.flat(Color("ffae5e") if chosen else Color("2b4050"),Color("ffcd8d") if chosen else Color("506577"),7))
  button.disabled = not FactoryData.tool_unlocked(kind,milestones.stage)
 if inventory_panel.visible:
  var parts: Array[String] = []
  for kind in inv.keys():
   parts.append("%s   ×%d" % [str(kind).replace("_"," ").capitalize(),int(inv[kind])])
  inventory_label.text = "\n".join(PackedStringArray(parts))
 if inspect_panel.visible and grid.buildings.has(selected_machine):
  var kind: int = int(grid.buildings[selected_machine]["type"])
  inspector_label.text = "%s at %s\n%s" % [str(FactoryData.NAMES.get(kind,"?")),str(selected_machine),sim.status_for(selected_machine)]
 if stats_panel.visible:
  chart.samples = sim.history
  chart.queue_redraw()
 build_catalog.update_context(inv,milestones.stage,selected_slot)

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  _key_pressed(event)
 elif event is InputEventMouseButton:
  _mouse_button(event)
 elif event is InputEventMouseMotion:
  if dragging_camera:
   camera.position -= event.relative / camera.zoom
  if dragging_belt:
   belt_end = mouse_tile()

func _key_pressed(e: InputEventKey) -> void:
 if e.keycode == KEY_B:
  _toggle_build_catalog()
  return
 if e.keycode == KEY_ESCAPE and build_catalog.visible:
  build_catalog.hide_catalog()
  return
 if build_catalog.visible:
  return
 if e.keycode >= KEY_1 and e.keycode <= KEY_9:
  _hotbar_clicked(int(e.keycode-KEY_1))
 elif e.keycode == KEY_0:
  _hotbar_clicked(9)
 elif e.keycode == KEY_P:
  _select_tool(11)
 elif e.keycode == KEY_H:
  _select_tool(6)
 elif e.keycode == KEY_X:
  _select_tool(5)
 elif e.keycode == KEY_R:
  rotation_index = (rotation_index+1)%4
  _say("Rotation: %d°" % (rotation_index*90),1.5)
 elif e.keycode == KEY_G:
  show_grid = not show_grid
 elif e.keycode == KEY_I:
  _toggle_inventory()
 elif e.keycode == KEY_TAB:
  _toggle_stats()
 elif e.keycode == KEY_M:
  _toggle_music()
 elif e.keycode == KEY_V:
  wire_layer.enabled = not wire_layer.enabled
  _say("Power wires %s" % ("shown" if wire_layer.enabled else "hidden"))
 elif e.keycode == KEY_SPACE:
  paused = not paused
 elif e.keycode == KEY_F5:
  _save()
 elif e.keycode == KEY_F9:
  _load()
 elif e.keycode == KEY_E:
  _toggle_machine()
 elif e.keycode == KEY_ESCAPE:
  dragging_belt = false
  _close_inspector()
 elif e.keycode == KEY_BACKSPACE or e.keycode == KEY_DELETE:
  _demolish(mouse_tile())

func _mouse_button(e: InputEventMouseButton) -> void:
 if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
  camera.zoom = (camera.zoom * 1.12).clamp(Vector2(0.5,0.5),Vector2(3.0,3.0))
 elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
  camera.zoom = (camera.zoom / 1.12).clamp(Vector2(0.5,0.5),Vector2(3.0,3.0))
 elif e.button_index == MOUSE_BUTTON_MIDDLE:
  dragging_camera = e.pressed
 elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
  if dragging_belt:
   dragging_belt = false
  else:
   _inspect(mouse_tile())
 elif e.button_index == MOUSE_BUTTON_LEFT:
  if e.pressed:
   if selected_tool == 1:
    dragging_belt = true
    belt_start = mouse_tile()
    belt_end = belt_start
   elif selected_tool == 5:
    _demolish(mouse_tile())
   else:
    _place_building(mouse_tile())
  elif dragging_belt:
   dragging_belt = false
   _place_belt(belt_start, belt_end)


func mouse_tile() -> Vector2i:
 var p: Vector2 = get_global_mouse_position()
 return Vector2i(floori(p.x/float(TILE)),floori(p.y/float(TILE)))

func _can_afford(cost: Dictionary) -> bool:
 for key in cost.keys():
  if int(inv.get(key,0)) < int(cost[key]):
   return false
 return true



func _apply_cost(cost: Dictionary, sign: int) -> void:
 for key in cost.keys():
  inv[key] = int(inv.get(key,0)) + sign * int(cost[key])

func _place_building(tile: Vector2i) -> void:
 if not FactoryData.tool_unlocked(selected_tool,milestones.stage):
  _say("Unlock this building with milestones")
  return
 if not grid.can_place(tile,selected_tool,rotation_index):
  _say("Blocked, outside map, or miner not on deposit")
  return
 var cost: Dictionary = FactoryData.COSTS.get(selected_tool,{})
 if not _can_afford(cost):
  _say("Not enough materials: " + FactoryData.format_items(cost))
  return
 if grid.place(tile,selected_tool,rotation_index):
  _apply_cost(cost,-1)
  sim.sync_machines()
  if click_audio != null:
   click_audio.play()
  _say("Built " + str(FactoryData.NAMES[selected_tool]),1.7)

func _place_belt(start: Vector2i, goal: Vector2i) -> void:
 var path: Array[Vector2i] = grid.shortest_path(start,goal)
 if path.size() < 2:
  _say("No route; drag at least two tiles. Belts cannot cross other belts.")
  return
 var additional: int = 0
 for p in path:
  if not grid.belts.has(p):
   additional += 1
 var cost: Dictionary = {"iron_plate": additional}
 if not _can_afford(cost):
  _say("Need %d iron plates" % additional)
  return
 if grid.place_path(path):
  _apply_cost(cost,-1)
  if click_audio != null:
   click_audio.play()
  _say("Connected %d conveyor tiles with animated turns" % path.size(),2.0)

func _demolish(tile: Vector2i) -> void:
 var origin: Vector2i = grid.building_at(tile)
 if origin != Vector2i(-1,-1):
  var kind: int = int(grid.buildings[origin]["type"])
  _apply_cost(FactoryData.COSTS.get(kind,{}),1)
  if sim.machines.has(origin):
   var state: Dictionary = sim.machines[origin]
   for buffer_name in ["input","output"]:
    var buffer: Dictionary = state.get(buffer_name,{})
    for key in buffer.keys():
     inv[key] = int(inv.get(key,0)) + int(buffer[key])
   inv["coal"] = int(inv.get("coal",0)) + int(state.get("fuel",0))
  if selected_machine == origin:
   _close_inspector()
 elif grid.belts.has(tile):
  inv["iron_plate"] = int(inv.get("iron_plate",0)) + 1
  if sim.items.has(tile):
   var item: Dictionary = sim.items[tile]
   inv[str(item["kind"])] = int(inv.get(item["kind"],0)) + 1
 if grid.erase_at(tile) > 0:
  sim.sync_machines()
  _say("Removed; materials fully refunded",2.0)
 else:
  _say("Nothing to remove",1.0)

func _inspect(tile: Vector2i) -> void:
 var origin: Vector2i = grid.building_at(tile)
 if origin == Vector2i(-1,-1):
  _close_inspector()
  return
 selected_machine = origin
 inspect_panel.visible = true
 var kind: int = int(grid.buildings[origin]["type"])
 recipe_choice.clear()
 var available: Array[String] = FactoryData.recipes_for(kind)
 var current: String = str(sim.machines.get(origin,{}).get("recipe",""))
 for recipe in available:
  if FactoryData.recipe_unlocked(recipe,milestones.stage):
   recipe_choice.add_item(recipe.replace("_"," ").capitalize())
   recipe_choice.set_item_metadata(recipe_choice.item_count-1,recipe)
   if recipe == current:
    recipe_choice.select(recipe_choice.item_count-1)
 recipe_choice.visible = not available.is_empty()
 _update_ui()

func _recipe_changed(index: int) -> void:
 if not grid.buildings.has(selected_machine):
  return
 var name: String = str(recipe_choice.get_item_metadata(index))
 if sim.set_recipe(selected_machine,name):
  _say("Recipe set: " + name.replace("_"," "))

func _toggle_machine() -> void:
 if not sim.machines.has(selected_machine):
  return
 var state: Dictionary = sim.machines[selected_machine]
 state["enabled"] = not bool(state["enabled"])
 sim.machines[selected_machine] = state
 _say("Machine " + ("enabled" if bool(state["enabled"]) else "disabled"))

func _collect_output() -> void:
 if not sim.machines.has(selected_machine):
  return
 var taken: Dictionary = sim.take_output(selected_machine)
 for key in taken.keys():
  inv[key] = int(inv.get(key,0)) + int(taken[key])
 _say("Collected: " + FactoryData.format_items(taken))

func _save() -> void:
 if SaveManager.save_game(grid,sim,milestones,inv,camera):
  _say("Game saved to user://overclocked_save_v5.json",4.0)
 else:
  _say("Save failed",4.0)

func _load() -> void:
 if not FileAccess.file_exists(SaveManager.FILE):
  _say("No save exists yet")
  return
 var loaded_inventory: Dictionary = SaveManager.load_game(grid,sim,milestones,camera)
 if loaded_inventory.is_empty():
  _say("Save missing, corrupted, or older than v5")
  return
 inv = loaded_inventory
 _close_inspector()
 sim.power.update(grid,sim.machines)
 _say("Factory restored",4.0)

func _load_demo() -> void:
 grid.buildings.clear()
 grid.belts.clear()
 grid.belt_inputs.clear()
 sim.items.clear()
 sim.machines.clear()
 sim.produced_total = 0
 sim.delivered_total = 0
 sim.history.clear()
 milestones = MilestoneProgress.new()
 inv = FactoryData.STARTER_INVENTORY.duplicate(true)
 # Fully working iron ore -> ingots -> plates -> hub flow.
 for part in [[Vector2i(5,6),2],[Vector2i(10,6),3],[Vector2i(15,6),4],[Vector2i(22,6),6],
  [Vector2i(8,10),9],[Vector2i(13,10),11],[Vector2i(19,10),11]]:
  grid.place(part[0],int(part[1]),0)
 for section in [[Vector2i(7,7),Vector2i(9,7)], [Vector2i(12,7),Vector2i(14,7)], [Vector2i(18,7),Vector2i(21,7)]]:
  grid.place_path(grid.shortest_path(section[0],section[1]))
 sim.sync_machines()
 camera.position = Vector2(14,8)*float(TILE)
 _close_inspector()
 _say("DEMO: miner → smelter → constructor → hub. Items and milestones are live.",8.0)

func _exit_tree() -> void:
 if sim != null and camera != null:
  SaveManager.save_game(grid,sim,milestones,inv,camera)

func _draw() -> void:
 _draw_landscape()
 _draw_belts()
 _draw_items()
 _draw_buildings()
 _draw_preview()

func _draw_landscape() -> void:
 var world: Rect2 = Rect2(Vector2.ZERO,Vector2(BuildGrid.WIDTH,BuildGrid.HEIGHT)*float(TILE))
 draw_rect(world,Color("85b46b"))
 # Deterministic handcrafted-looking patches; no external artwork.
 for x in range(BuildGrid.WIDTH):
  for y in range(BuildGrid.HEIGHT):
   var t: Vector2i = Vector2i(x,y)
   var top_left: Vector2 = Vector2(t)*float(TILE)
   var n: int = posmod(x*97+y*53+x*y*17,43)
   if n <= 5:
    draw_rect(Rect2(top_left+Vector2(6,9),Vector2(2,7)),Color("699a57",0.7))
    draw_rect(Rect2(top_left+Vector2(21,42),Vector2(4,5)),Color("bfd084",0.6))
   if (x >= 35 and y >= 1 and y <= 7) or (x>=2 and x<=5 and y>=25 and y<=28):
    draw_rect(Rect2(top_left,Vector2(TILE,TILE)),Color("5b96aa"))
    draw_line(top_left+Vector2(12,23),top_left+Vector2(34,23),Color("92c7cc",0.6),2)
   elif n == 12 or n == 13:
    draw_circle(top_left+Vector2(41,37),9,Color("a1ab8e"))
    draw_circle(top_left+Vector2(39,33),6,Color("b9bdab"))
   elif x >= 36 and x <= 38 and y >= 14 and y <= 25:
    draw_rect(Rect2(top_left,Vector2(TILE,TILE)),Color("827e6b"))
    draw_line(top_left+Vector2(0,5),top_left+Vector2(TILE,5),Color("c1b89a"),5)
    draw_line(top_left+Vector2(11,10),top_left+Vector2(11,60),Color("514f49",0.5),3)
   elif n == 28 and (x<4 or x>30 or y>20):
    draw_rect(Rect2(top_left+Vector2(24,32),Vector2(11,14)),Color("7b6855"))
    draw_circle(top_left+Vector2(29,24),16,Color("4e8760"))
    draw_circle(top_left+Vector2(19,21),10,Color("619868"))
 if show_grid:
  for x in range(BuildGrid.WIDTH+1):
   draw_line(Vector2(x*TILE,0),Vector2(x*TILE,world.size.y),Color(0.15,0.29,0.16,0.17),1)
  for y in range(BuildGrid.HEIGHT+1):
   draw_line(Vector2(0,y*TILE),Vector2(world.size.x,y*TILE),Color(0.15,0.29,0.16,0.17),1)
 for deposit in FactoryData.DEPOSITS:
  var origin: Vector2i = deposit["tile"]
  var resource: String = str(deposit["kind"])
  var color: Color = Color("9a8d7b")
  if resource == "iron_ore": color=Color("627682")
  elif resource == "copper_ore": color=Color("c77e55")
  elif resource == "limestone": color=Color("d3d0b4")
  elif resource == "coal": color=Color("464a57")
  var pos: Vector2 = Vector2(origin)*float(TILE)
  draw_rect(Rect2(pos+Vector2(3,3),Vector2(TILE*2-6,TILE*2-6)),Color(color,0.25))
  for j in range(6):
   var offset: Vector2 = Vector2(22+float((j*37)%85),19+float((j*61)%78))
   draw_circle(pos+offset,9,color)
   draw_circle(pos+offset+Vector2(-3,-3),4,color.lightened(0.25))
  if not grid.occupied(origin):
   draw_string(ThemeDB.fallback_font,pos+Vector2(8,-7),resource.replace("_"," ").capitalize(),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("24372b"))

func _draw_belts() -> void:
 var frame_index: int = int(clock*10.0)%4
 for tile in grid.belts.keys():
  var texture: Texture2D = visuals.frame(visuals.tile_kind(grid,tile),frame_index)
  if texture != null:
   draw_texture_rect(texture,Rect2(Vector2(tile)*float(TILE),Vector2(TILE,TILE)),false)

func _draw_items() -> void:
 for tile in sim.items.keys():
  var state: Dictionary = sim.items[tile]
  var p: float = float(state["progress"])
  var outgoing: Vector2i = grid.belts.get(tile,Vector2i.RIGHT)
  var incoming: Vector2i = grid.belt_inputs.get(tile,outgoing)
  var center: Vector2 = (Vector2(tile)+Vector2(0.5,0.5))*float(TILE)
  if p < 0.5:
   center += Vector2(incoming)*(p-0.5)*float(TILE)
  else:
   center += Vector2(outgoing)*(p-0.5)*float(TILE)
  var tex: Texture2D = item_sprites.get(str(state["kind"]))
  if tex != null:
   draw_texture_rect(tex,Rect2(center-Vector2(13,13),Vector2(26,26)),false)

func _draw_buildings() -> void:
 for origin in grid.buildings.keys():
  var entry: Dictionary = grid.buildings[origin]
  var kind: int = int(entry["type"])
  var sz: Vector2i = FactoryData.footprint(kind,int(entry["rotation"]))
  var rect: Rect2 = Rect2(Vector2(origin)*float(TILE)+Vector2(4,4),Vector2(sz)*float(TILE)-Vector2(8,8))
  var texture: Texture2D = machine_sprites.get(kind)
  if texture != null:
   # A soft contact shadow preserves the look of an object on grass.
   # Never draw opaque rectangles beneath machine sprites.
   var shadow_center: Vector2 = rect.get_center()+Vector2(0,rect.size.y*0.27)
   draw_set_transform(shadow_center,0,Vector2(1.0,0.27))
   draw_circle(Vector2.ZERO,minf(rect.size.x,rect.size.y)*0.40,Color(0.04,0.12,0.06,0.19))
   draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
   var sprite_size: Vector2 = Vector2(texture.get_size())
   var scale: float = minf((rect.size.x-22)/sprite_size.x,(rect.size.y-25)/sprite_size.y)
   scale = minf(scale,3.0)
   var dest_size: Vector2 = sprite_size*scale
   draw_texture_rect(texture,Rect2(rect.get_center()-dest_size*0.5,dest_size),false)
  var d: Vector2i = FactoryData.direction(int(entry["rotation"]))
  # Port dots are only shown for the inspected building or while Shift is held.
  # Otherwise machinery appears as clean cutouts directly on the grass.
  var show_ports: bool = selected_machine == origin or Input.is_key_pressed(KEY_SHIFT)
  if show_ports and kind in [2,3,4,7,8,10,6]:
   for in_tile in grid.input_ports(origin):
    var in_point: Vector2 = (Vector2(in_tile)+Vector2(0.5,0.5))*float(TILE)
    draw_circle(in_point,7.0,Color("ffdf86"))
  if kind in [2,3,4,7,8]:
   if show_ports:
    var out_tile: Vector2i = grid.port_tile(origin,true)
    if BuildGrid.in_bounds(out_tile):
     draw_circle((Vector2(out_tile)+Vector2(0.5,0.5))*float(TILE),7.0,Color("68efb0"))
    draw_line(rect.get_center(),rect.get_center()+Vector2(d)*18,Color("28454b"),3)
   if not sim.power.active(origin):
    # Small offline LED, not a background panel.
    draw_circle(rect.position+Vector2(rect.size.x-9,9),5,Color("ed746e"))
  if selected_machine == origin:
   draw_rect(rect,Color("fff2a5"),false,3)

func _draw_preview() -> void:
 if build_catalog.visible:
  return
 var tile: Vector2i = mouse_tile()
 if selected_tool in [2,3,4,6,7,8,9,10,11]:
  var sz: Vector2i = FactoryData.footprint(selected_tool,rotation_index)
  var allowed: bool = grid.can_place(tile,selected_tool,rotation_index)
  var can_pay: bool = _can_afford(FactoryData.COSTS.get(selected_tool,{}))
  var color: Color = Color(0.20,0.86,0.55,0.28) if allowed and can_pay else Color(0.92,0.23,0.25,0.33)
  draw_rect(Rect2(Vector2(tile)*float(TILE),Vector2(sz)*float(TILE)),color)
 elif selected_tool == 5 and BuildGrid.in_bounds(tile):
  draw_rect(Rect2(Vector2(tile)*float(TILE),Vector2(TILE,TILE)),Color(0.95,0.2,0.2,0.3))
 if dragging_belt:
  var path: Array[Vector2i] = grid.shortest_path(belt_start,belt_end)
  for path_tile in path:
   draw_rect(Rect2(Vector2(path_tile)*float(TILE),Vector2(TILE,TILE)),Color(0.3,0.9,0.8,0.28))
