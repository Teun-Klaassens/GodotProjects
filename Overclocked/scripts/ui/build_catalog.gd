extends Control
## In-game Satisfactory-inspired building catalog. Uses only user-supplied sprites.
signal build_requested(kind: int)
signal hotbar_requested(kind: int)
signal closed

const Data = preload("res://scripts/components/factory_data.gd")
const GROUPS: Dictionary = {
 "Logistics": [1,8],
 "Production": [2,3,4,7],
 "Power": [9,10,11],
 "Special": [6],
 "Tools": [5]
}
const DESCRIPTIONS: Dictionary = {
 1: "Moves individual items between machines along automatically routed paths. Corners use the animated loop tiles.",
 2: "Extracts unlimited resources from an iron, copper, coal or limestone deposit. Requires electricity.",
 3: "Smelts iron and copper ore into metal ingots. Choose its recipe in the machine inspector.",
 4: "Manufactures plates, rods, wire and concrete from basic materials.",
 5: "Removes buildings or belts. All construction materials and stored items are refunded.",
 6: "Receives products from belts and advances your delivery milestones. Unlocks endless contracts.",
 7: "Combines processed materials into advanced parts, including reinforced plates and circuits.",
 8: "Stores and forwards items arriving from connected conveyors.",
 9: "Starter generator supplying 60 kW of electricity to nearby machines through poles.",
 10: "Coal-fueled generator supplying 150 kW when it has fuel. Connect its input to a coal belt.",
 11: "Connects electrical networks over seven tiles. Machines automatically connect within six tiles."
}
const POWER_TEXT: Dictionary = {2:"Consumes 6 kW",3:"Consumes 8 kW",4:"Consumes 10 kW",7:"Consumes 16 kW",8:"Consumes 2 kW",9:"Produces 60 kW",10:"Produces 150 kW",11:"Network connector"}
const SPRITES: Dictionary = {
 1:"res://assets/Overclocked_Assets/conveyors/tiles/horizontal_right/frame_00.png",
 2:"res://assets/sprites/miner.png",3:"res://assets/sprites/smelter.png",4:"res://assets/sprites/constructor.png",
 6:"res://assets/sprites/hub.png",7:"res://assets/sprites/assembler.png",8:"res://assets/sprites/storage.png",
 9:"res://assets/sprites/generator.png",10:"res://assets/sprites/coal_generator.png",11:"res://assets/sprites/power_pole.png"
}
const ACCENT: Color = Color("ffa54b")
const PANEL: Color = Color("172330")
const PANEL_ALT: Color = Color("243341")
const WHITE: Color = Color("f3f5f5")
const MUTED: Color = Color("aebec9")

var current_group: String = "Logistics"
var selected_kind: int = 1
var materials: Dictionary = {}
var stage: int = 0
var slot_index: int = 0
var last_stage: int = -1
var search_text: String = ""
var categories: Dictionary = {}
var cards: Dictionary = {}
var catalog_grid: GridContainer
var section_title: Label
var detail_name: Label
var detail_description: Label
var detail_stat: Label
var detail_status: Label
var detail_preview: TextureRect
var detail_costs: HBoxContainer
var build_button: Button
var hotbar_button: Button
var search: LineEdit
var frame: PanelContainer

static func flat(color: Color, border_color: Color = Color.TRANSPARENT, radius: int = 9) -> StyleBoxFlat:
 var s: StyleBoxFlat = StyleBoxFlat.new()
 s.bg_color = color
 s.set_corner_radius_all(radius)
 s.border_color = border_color
 s.set_border_width_all(1 if border_color.a > 0 else 0)
 s.content_margin_left = 11.0
 s.content_margin_right = 11.0
 s.content_margin_top = 9.0
 s.content_margin_bottom = 9.0
 return s

static func txt(value: String, size: int = 14, color: Color = WHITE) -> Label:
 var l: Label = Label.new()
 l.text = value
 l.add_theme_font_size_override("font_size",size)
 l.add_theme_color_override("font_color",color)
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return l

static func btn(value: String, action: Callable) -> Button:
 var b: Button = Button.new()
 b.text = value
 b.pressed.connect(action)
 b.add_theme_color_override("font_color",WHITE)
 b.add_theme_color_override("font_hover_color",WHITE)
 b.add_theme_stylebox_override("normal",flat(PANEL_ALT))
 b.add_theme_stylebox_override("hover",flat(Color("3b4c59"),ACCENT))
 b.add_theme_stylebox_override("pressed",flat(Color("435464"),ACCENT))
 b.add_theme_stylebox_override("disabled",flat(Color("172029")))
 return b

static func picture(kind: int) -> Texture2D:
 if SPRITES.has(kind):
  return load(str(SPRITES[kind]))
 return null

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 visible = false
 var shade: ColorRect = ColorRect.new()
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.color = Color(0.02,0.035,0.055,0.78)
 shade.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(shade)
 var center: CenterContainer = CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 center.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(center)
 frame = PanelContainer.new()
 frame.custom_minimum_size = Vector2(1040,570)
 frame.add_theme_stylebox_override("panel",flat(PANEL,Color("435566"),12))
 center.add_child(frame)
 var outer: VBoxContainer = VBoxContainer.new()
 outer.add_theme_constant_override("separation",12)
 frame.add_child(outer)
 var header: HBoxContainer = HBoxContainer.new()
 header.add_theme_constant_override("separation",14)
 outer.add_child(header)
 var branding: Label = txt("OVERCLOCKED   /   BUILD CATALOG",23)
 branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(branding)
 search = LineEdit.new()
 search.custom_minimum_size = Vector2(300,36)
 search.placeholder_text = "Search for buildings..."
 search.text_changed.connect(_search_changed)
 header.add_child(search)
 var close_button: Button = btn("✕",hide_catalog)
 close_button.custom_minimum_size = Vector2(42,36)
 header.add_child(close_button)
 var rule: HSeparator = HSeparator.new()
 outer.add_child(rule)
 var content: HBoxContainer = HBoxContainer.new()
 content.size_flags_vertical = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",12)
 outer.add_child(content)
 var sidebar: VBoxContainer = VBoxContainer.new()
 sidebar.custom_minimum_size.x = 158
 sidebar.add_theme_constant_override("separation",7)
 content.add_child(sidebar)
 for group in GROUPS.keys():
  var tab: Button = btn(group, _group_clicked.bind(group))
  tab.custom_minimum_size.y = 54
  tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
  sidebar.add_child(tab)
  categories[group] = tab
 var separator: VSeparator = VSeparator.new()
 content.add_child(separator)
 var central: VBoxContainer = VBoxContainer.new()
 central.custom_minimum_size.x = 490
 central.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_child(central)
 section_title = txt("LOGISTICS",18,ACCENT)
 central.add_child(section_title)
 var scroll: ScrollContainer = ScrollContainer.new()
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 central.add_child(scroll)
 catalog_grid = GridContainer.new()
 catalog_grid.columns = 3
 catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 catalog_grid.add_theme_constant_override("h_separation",9)
 catalog_grid.add_theme_constant_override("v_separation",9)
 scroll.add_child(catalog_grid)
 var right_shell: PanelContainer = PanelContainer.new()
 right_shell.custom_minimum_size.x = 275
 right_shell.add_theme_stylebox_override("panel",flat(Color("1e2e3a"),Color("34495a")))
 content.add_child(right_shell)
 var right: VBoxContainer = VBoxContainer.new()
 right.add_theme_constant_override("separation",9)
 right_shell.add_child(right)
 detail_name = txt("Conveyor",21,WHITE)
 right.add_child(detail_name)
 detail_preview = TextureRect.new()
 detail_preview.custom_minimum_size = Vector2(235,162)
 detail_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 detail_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 detail_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 right.add_child(detail_preview)
 detail_description = txt("",13,MUTED)
 detail_description.custom_minimum_size.y = 77
 right.add_child(detail_description)
 detail_stat = txt("",13,ACCENT)
 right.add_child(detail_stat)
 right.add_child(HSeparator.new())
 right.add_child(txt("BUILD COST",13,WHITE))
 detail_costs = HBoxContainer.new()
 detail_costs.add_theme_constant_override("separation",5)
 right.add_child(detail_costs)
 detail_status = txt("",12,MUTED)
 right.add_child(detail_status)
 var filler: Control = Control.new()
 filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
 right.add_child(filler)
 build_button = btn("Select for placement",_request_build)
 build_button.custom_minimum_size.y = 36
 right.add_child(build_button)
 hotbar_button = btn("Assign to hotbar slot",_assign_hotbar)
 hotbar_button.custom_minimum_size.y = 36
 right.add_child(hotbar_button)
 outer.add_child(HSeparator.new())
 outer.add_child(txt("B  Close menu    •    Left click an item for details    •    Select to build    •    Assign replaces the active hotbar slot",12,MUTED))
 _refresh_grid()
 _refresh_detail()

func open_catalog(inventory: Dictionary, current_stage: int, hotbar_slot: int) -> void:
 materials = inventory.duplicate(true)
 stage = current_stage
 slot_index = hotbar_slot
 last_stage = current_stage
 visible = true
 search.clear()
 search_text = ""
 _refresh_grid()
 _refresh_detail()

func hide_catalog() -> void:
 visible = false
 search.release_focus()
 closed.emit()

func update_context(inventory: Dictionary, current_stage: int, hotbar_slot: int) -> void:
 if not visible:
  return
 if materials == inventory and stage == current_stage and slot_index == hotbar_slot:
  return
 materials = inventory.duplicate(true)
 stage = current_stage
 slot_index = hotbar_slot
 if last_stage != stage:
  last_stage = stage
  _refresh_grid()
 _refresh_detail()

func _group_clicked(group: String) -> void:
 current_group = group
 _refresh_grid()

func _search_changed(value: String) -> void:
 search_text = value.strip_edges().to_lower()
 _refresh_grid()

func _kinds() -> Array[int]:
 var output: Array[int] = []
 if search_text == "":
  for kind in GROUPS[current_group]:
   output.append(int(kind))
 else:
  for category in GROUPS.keys():
   for kind in GROUPS[category]:
    var id: int = int(kind)
    if str(Data.NAMES[id]).to_lower().contains(search_text) or str(DESCRIPTIONS[id]).to_lower().contains(search_text):
     output.append(id)
 return output

func _refresh_grid() -> void:
 if catalog_grid == null:
  return
 for child in catalog_grid.get_children():
  catalog_grid.remove_child(child)
  child.queue_free()
 cards.clear()
 for group in categories.keys():
  var tab: Button = categories[group]
  tab.add_theme_stylebox_override("normal",flat(ACCENT if group == current_group and search_text == "" else PANEL_ALT))
  tab.add_theme_color_override("font_color", Color("15232e") if group == current_group and search_text == "" else WHITE)
 section_title.text = "SEARCH RESULTS" if search_text != "" else current_group.to_upper()
 var candidates: Array[int] = _kinds()
 if candidates.is_empty():
  catalog_grid.add_child(txt("No matching buildings.",15,MUTED))
  return
 for kind in candidates:
  var card: Button = btn("",_select_card.bind(kind))
  card.custom_minimum_size = Vector2(150,151)
  card.add_theme_stylebox_override("normal",flat(Color("263743"),ACCENT if kind == selected_kind else Color("354959")))
  card.add_theme_stylebox_override("hover",flat(Color("354959"),ACCENT))
  card.disabled = not Data.tool_unlocked(kind,stage)
  catalog_grid.add_child(card)
  cards[kind] = card
  var card_v: VBoxContainer = VBoxContainer.new()
  card_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  card_v.offset_left = 6
  card_v.offset_top = 6
  card_v.offset_right = -6
  card_v.offset_bottom = -6
  card_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
  card.add_child(card_v)
  var art: TextureRect = TextureRect.new()
  art.texture = picture(kind)
  art.custom_minimum_size.y = 82
  art.size_flags_vertical = Control.SIZE_EXPAND_FILL
  art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  art.mouse_filter = Control.MOUSE_FILTER_IGNORE
  card_v.add_child(art)
  var name_label: Label = txt(str(Data.NAMES[kind]),14,WHITE)
  name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  card_v.add_child(name_label)
  var cost: String = "Free" if kind == 5 else Data.format_items(Data.COSTS.get(kind,{}))
  var cost_label: Label = txt("LOCKED" if card.disabled else cost,10,MUTED)
  cost_label.max_lines_visible = 2
  cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  card_v.add_child(cost_label)

func _select_card(kind: int) -> void:
 selected_kind = kind
 _refresh_grid()
 _refresh_detail()

func _refresh_detail() -> void:
 if detail_name == null:
  return
 detail_name.text = str(Data.NAMES.get(selected_kind,"Unknown"))
 detail_preview.texture = picture(selected_kind)
 detail_description.text = str(DESCRIPTIONS.get(selected_kind,""))
 detail_stat.text = str(POWER_TEXT.get(selected_kind,"Grid placement  •  90° rotation"))
 for child in detail_costs.get_children():
  detail_costs.remove_child(child)
  child.queue_free()
 var costs: Dictionary = Data.COSTS.get(selected_kind,{})
 var can_build: bool = true
 for item in costs.keys():
  var required: int = int(costs[item])
  var owned: int = int(materials.get(item,0))
  var cost_tile: VBoxContainer = VBoxContainer.new()
  cost_tile.custom_minimum_size.x = 70
  detail_costs.add_child(cost_tile)
  var tex: TextureRect = TextureRect.new()
  tex.texture = load("res://assets/sprites/item_" + str(item) + ".png")
  tex.custom_minimum_size.y = 37
  tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  cost_tile.add_child(tex)
  var label: Label = txt("%d / %d" % [owned,required],12,Color("6be0a4") if owned >= required else Color("ff8e83"))
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  cost_tile.add_child(label)
  cost_tile.tooltip_text = str(item).replace("_"," ").capitalize()
  if owned < required:
   can_build = false
 if costs.is_empty():
  detail_costs.add_child(txt("No materials required",13,MUTED))
 var unlocked: bool = Data.tool_unlocked(selected_kind,stage)
 build_button.disabled = not unlocked
 hotbar_button.disabled = not unlocked
 detail_status.text = "LOCKED — Complete more milestones" if not unlocked else ("Materials available" if can_build else "Missing materials — you can select it anyway")
 hotbar_button.text = "Assign to hotbar slot %d" % (slot_index+1 if slot_index < 9 else 0)

func _request_build() -> void:
 if Data.tool_unlocked(selected_kind,stage):
  build_requested.emit(selected_kind)
  hide_catalog()

func _assign_hotbar() -> void:
 if Data.tool_unlocked(selected_kind,stage):
  hotbar_requested.emit(selected_kind)
  hide_catalog()
