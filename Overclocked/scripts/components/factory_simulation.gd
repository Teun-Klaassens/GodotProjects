extends RefCounted

const BuildGrid = preload("res://scripts/components/build_grid.gd")
const FactoryData = preload("res://scripts/components/factory_data.gd")
const PowerNetwork = preload("res://scripts/components/power_network.gd")

const SPEED: float = 2.3
const BUFFER_LIMIT: int = 32
const OUTPUT_LIMIT: int = 24
var grid: BuildGrid
var machines: Dictionary = {} # origin -> {recipe, input:{kind:int}, output:{kind:int},timer, produced, fuel}
var items: Dictionary = {} # belt tile -> {kind:String,progress:float}
var produced_total: int = 0
var delivered_total: int = 0
var power: PowerNetwork = PowerNetwork.new()
var delivery_callback: Callable
var history: Array[Dictionary] = []
var history_clock: float = 0.0
var interval_produced: int = 0
var interval_delivered: int = 0
var interval_consumed: int = 0
var elapsed: float = 0.0

func _init(build_grid: BuildGrid) -> void:
 grid = build_grid

func new_machine(kind: int) -> Dictionary:
 return {"recipe": FactoryData.default_recipe(kind), "input": {}, "output": {}, "timer": 0.0,
  "produced": 0, "fuel": 0, "fuel_timer": 0.0, "deposit": "", "enabled": true}

func sync_machines() -> void:
 for origin in machines.keys():
  if not grid.buildings.has(origin):
   machines.erase(origin)
 for origin in grid.buildings.keys():
  if not machines.has(origin):
   var kind: int = int(grid.buildings[origin]["type"])
   var state: Dictionary = new_machine(kind)
   if kind == 2:
    state["deposit"] = FactoryData.deposit_at(origin, grid.footprint(kind, int(grid.buildings[origin]["rotation"])))
   machines[origin] = state
 for tile in items.keys():
  if not grid.belts.has(tile):
   items.erase(tile)

func set_recipe(origin: Vector2i, recipe: String) -> bool:
 if not machines.has(origin) or not grid.buildings.has(origin):
  return false
 if recipe not in FactoryData.RECIPES:
  return false
 if int(grid.buildings[origin]["type"]) != int(FactoryData.RECIPES[recipe]["machine"]):
  return false
 var state: Dictionary = machines[origin]
 state["recipe"] = recipe
 state["timer"] = 0.0
 machines[origin] = state
 return true

func _sum_counts(d: Dictionary) -> int:
 var total: int = 0
 for k in d.keys():
  total += int(d[k])
 return total

func _can_craft(state: Dictionary, recipe: Dictionary) -> bool:
 var inputs: Dictionary = state["input"]
 var outputs: Dictionary = state["output"]
 if _sum_counts(outputs) >= OUTPUT_LIMIT:
  return false
 for key in recipe["inputs"].keys():
  if int(inputs.get(key,0)) < int(recipe["inputs"][key]):
   return false
 return true

func _craft(origin: Vector2i, delta: float) -> void:
 var kind: int = int(grid.buildings[origin]["type"])
 var state: Dictionary = machines[origin]
 if not bool(state["enabled"]):
  return
 if kind in [2,3,4,7,8] and not power.active(origin):
  return
 if kind == 2:
  var resource: String = str(state.get("deposit",""))
  if resource == "" or _sum_counts(state["output"]) >= OUTPUT_LIMIT:
   return
  state["timer"] = float(state["timer"]) + delta
  if float(state["timer"]) >= 1.0:
   state["timer"] = float(state["timer"]) - 1.0
   var out: Dictionary = state["output"]
   out[resource] = int(out.get(resource,0)) + 1
   state["produced"] = int(state["produced"]) + 1
   produced_total += 1
   interval_produced += 1
  machines[origin] = state
  return
 if kind == 8:
  # Storage accepts any item and dispatches from its output buffer.
  var storage_input: Dictionary = state["input"]
  var storage_output: Dictionary = state["output"]
  if _sum_counts(storage_output) < OUTPUT_LIMIT:
   for key in storage_input.keys():
    if int(storage_input[key]) > 0:
     storage_input[key] = int(storage_input[key]) - 1
     storage_output[key] = int(storage_output.get(key,0)) + 1
     break
  machines[origin] = state
  return
 if kind == 10:
  state["fuel_timer"] = float(state["fuel_timer"]) + delta
  if int(state["fuel"]) > 0 and float(state["fuel_timer"]) >= 12.0:
   state["fuel"] = int(state["fuel"]) - 1
   state["fuel_timer"] = float(state["fuel_timer"]) - 12.0
  machines[origin] = state
  return
 if kind not in [3,4,7]:
  return
 var recipe_name: String = str(state["recipe"])
 if not FactoryData.RECIPES.has(recipe_name):
  return
 var recipe: Dictionary = FactoryData.RECIPES[recipe_name]
 if not _can_craft(state, recipe):
  state["timer"] = 0.0
  machines[origin] = state
  return
 state["timer"] = float(state["timer"]) + delta
 if float(state["timer"]) >= float(recipe["seconds"]):
  state["timer"] = float(state["timer"]) - float(recipe["seconds"])
  var input_buffer: Dictionary = state["input"]
  var output_buffer: Dictionary = state["output"]
  for key in recipe["inputs"].keys():
   input_buffer[key] = int(input_buffer[key]) - int(recipe["inputs"][key])
   interval_consumed += int(recipe["inputs"][key])
  for key in recipe["outputs"].keys():
   output_buffer[key] = int(output_buffer.get(key,0)) + int(recipe["outputs"][key])
   produced_total += int(recipe["outputs"][key])
   interval_produced += int(recipe["outputs"][key])
  state["produced"] = int(state["produced"]) + 1
 machines[origin] = state

func _can_receive(origin: Vector2i, kind: String) -> bool:
 var machine_type: int = int(grid.buildings[origin]["type"])
 if machine_type == 6:
  return true
 var state: Dictionary = machines[origin]
 if machine_type == 10:
  return kind == "coal" and int(state["fuel"]) < 80
 if machine_type == 8:
  return _sum_counts(state["input"]) < 96
 if machine_type not in [3,4,7]:
  return false
 var allowed: bool = false
 # Let buffers hold ingredients for all recipes of this building, enabling switching.
 for recipe_name in FactoryData.recipes_for(machine_type):
  if FactoryData.RECIPES[recipe_name]["inputs"].has(kind):
   allowed = true
 return allowed and _sum_counts(state["input"]) < BUFFER_LIMIT

func _receive(origin: Vector2i, kind: String) -> void:
 var machine_type: int = int(grid.buildings[origin]["type"])
 if machine_type == 6:
  delivered_total += 1
  interval_delivered += 1
  if delivery_callback.is_valid():
   delivery_callback.call(kind)
  return
 var state: Dictionary = machines[origin]
 if machine_type == 10:
  state["fuel"] = int(state["fuel"]) + 1
 else:
  var input_buffer: Dictionary = state["input"]
  input_buffer[kind] = int(input_buffer.get(kind,0)) + 1
 machines[origin] = state

func _release_outputs() -> void:
 for origin in grid.buildings.keys():
  var machine_type: int = int(grid.buildings[origin]["type"])
  if machine_type not in [2,3,4,7,8]:
   continue
  var tile: Vector2i = grid.output_adjacent(origin)
  var direction: Vector2i = FactoryData.direction(int(grid.buildings[origin]["rotation"]))
  if not grid.belts.has(tile) or items.has(tile) or grid.belts[tile] != direction:
   continue
  var state: Dictionary = machines[origin]
  var buffer: Dictionary = state["output"]
  for key in buffer.keys():
   if int(buffer[key]) > 0:
    items[tile] = {"kind": str(key), "progress": 0.0}
    buffer[key] = int(buffer[key]) - 1
    break
  machines[origin] = state

func _move_items(delta: float) -> void:
 var before: Dictionary = items.duplicate(true)
 var after: Dictionary = before.duplicate(true)
 # Snapshot stepping guarantees no overwrites or double moves in one update.
 for tile in before.keys():
  if not grid.belts.has(tile):
   after.erase(tile)
   continue
  var item: Dictionary = before[tile]
  var direction: Vector2i = grid.belts[tile]
  var p: float = float(item["progress"]) + SPEED * delta
  if p < 1.0:
   after[tile]["progress"] = p
   continue
  var next: Vector2i = tile + direction
  if grid.belts.has(next) and not before.has(next) and not after.has(next):
   # A neighbour must accept items traveling in this approach direction.
   var expected: Vector2i = grid.belt_inputs.get(next, direction)
   if expected == direction:
    after.erase(tile)
    after[next] = {"kind": str(item["kind"]), "progress": minf(p-1.0,0.95)}
    continue
  var receiver: Vector2i = grid.receiver_for(tile, direction)
  if receiver != Vector2i(-1,-1) and _can_receive(receiver, str(item["kind"])):
   _receive(receiver, str(item["kind"]))
   after.erase(tile)
   continue
  after[tile]["progress"] = 0.98
 items = after

func tick(delta: float) -> void:
 delta = minf(delta, 0.1)
 elapsed += delta
 sync_machines()
 power.update(grid, machines)
 for origin in grid.buildings.keys():
  _craft(origin, delta)
 _release_outputs()
 _move_items(delta)
 history_clock += delta
 if history_clock >= 2.0:
  history_clock -= 2.0
  history.append({"produced": interval_produced, "delivered": interval_delivered,
   "consumed": interval_consumed, "power_used": power.demand, "power_supply": power.capacity})
  if history.size() > 45:
   history.pop_front()
  interval_produced = 0
  interval_delivered = 0
  interval_consumed = 0

func take_output(origin: Vector2i) -> Dictionary:
 if not machines.has(origin):
  return {}
 var state: Dictionary = machines[origin]
 var buffer: Dictionary = state["output"].duplicate(true)
 state["output"] = {}
 machines[origin] = state
 return buffer

func status_for(origin: Vector2i) -> String:
 if not machines.has(origin):
  return ""
 var s: Dictionary = machines[origin]
 var kind: int = int(grid.buildings[origin]["type"])
 if kind == 10:
  return "Coal fuel %d | %s" % [int(s["fuel"]), "Active" if int(s["fuel"]) > 0 else "Needs coal"]
 if kind == 9:
  return "60 kW generator"
 if kind == 11:
  return "Connects power within 7 tiles"
 if kind == 6:
  return "Receives deliveries from its rear input"
 var power_text: String = "ON" if power.active(origin) else "NO POWER"
 return "%s | Recipe: %s\nInput: %s\nOutput: %s\nProduced: %d" % [power_text, str(s["recipe"]), FactoryData.format_items(s["input"]), FactoryData.format_items(s["output"]), int(s["produced"])]
