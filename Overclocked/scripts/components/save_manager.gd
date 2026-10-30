extends RefCounted

const BuildGrid = preload("res://scripts/components/build_grid.gd")
const FactoryData = preload("res://scripts/components/factory_data.gd")
const FactorySimulation = preload("res://scripts/components/factory_simulation.gd")
const MilestoneProgress = preload("res://scripts/components/milestone_progress.gd")

const FILE: String = "user://overclocked_save_v5.json"

static func save_game(grid: BuildGrid, sim: FactorySimulation, progress: MilestoneProgress, inventory: Dictionary, camera: Camera2D) -> bool:
 var data: Dictionary = {"version": 5, "buildings": [], "belts": [], "items": [], "machines": [],
  "milestone": progress.to_data(), "inventory": inventory.duplicate(true),
  "produced": sim.produced_total, "delivered": sim.delivered_total, "history": sim.history.duplicate(true),
  "camera": [camera.position.x, camera.position.y, camera.zoom.x]}
 for origin in grid.buildings.keys():
  var e: Dictionary = grid.buildings[origin]
  data["buildings"].append([origin.x,origin.y,int(e["type"]),int(e["rotation"])])
 for tile in grid.belts.keys():
  var d: Vector2i = grid.belts[tile]
  var input: Vector2i = grid.belt_inputs.get(tile,d)
  data["belts"].append([tile.x,tile.y,d.x,d.y,input.x,input.y])
 for tile in sim.items.keys():
  var item: Dictionary = sim.items[tile]
  data["items"].append([tile.x,tile.y,str(item["kind"]),float(item["progress"])])
 for origin in sim.machines.keys():
  data["machines"].append([origin.x,origin.y,sim.machines[origin].duplicate(true)])
 var file: FileAccess = FileAccess.open(FILE,FileAccess.WRITE)
 if file == null:
  return false
 file.store_string(JSON.stringify(data))
 return true

static func load_game(grid: BuildGrid, sim: FactorySimulation, progress: MilestoneProgress, camera: Camera2D) -> Dictionary:
 if not FileAccess.file_exists(FILE):
  return {}
 var file: FileAccess = FileAccess.open(FILE,FileAccess.READ)
 if file == null:
  return {}
 var parsed: Variant = JSON.parse_string(file.get_as_text())
 if not parsed is Dictionary:
  return {}
 var data: Dictionary = parsed
 if int(data.get("version",0)) != 5:
  return {}
 grid.buildings.clear()
 grid.belts.clear()
 grid.belt_inputs.clear()
 for e in data.get("buildings",[]):
  if e.size() != 4:
   continue
  var origin: Vector2i = Vector2i(int(e[0]),int(e[1]))
  var kind: int = int(e[2])
  var rot: int = int(e[3])
  if FactoryData.SIZES.has(kind) and grid.can_place(origin,kind,rot):
   grid.place(origin,kind,rot)
 for e in data.get("belts",[]):
  if e.size() != 6:
   continue
  var tile: Vector2i = Vector2i(int(e[0]),int(e[1]))
  if not BuildGrid.in_bounds(tile) or grid.building_at(tile) != Vector2i(-1,-1):
   continue
  grid.belts[tile] = Vector2i(int(e[2]),int(e[3]))
  grid.belt_inputs[tile] = Vector2i(int(e[4]),int(e[5]))
 sim.items.clear()
 sim.machines.clear()
 sim.sync_machines()
 for e in data.get("machines",[]):
  if e.size() != 3:
   continue
  var origin: Vector2i = Vector2i(int(e[0]),int(e[1]))
  if sim.machines.has(origin) and e[2] is Dictionary:
   var state: Dictionary = sim.machines[origin]
   var loaded: Dictionary = e[2]
   for key in state.keys():
    if loaded.has(key):
     state[key] = loaded[key]
   sim.machines[origin] = state
 for e in data.get("items",[]):
  if e.size() != 4:
   continue
  var t: Vector2i = Vector2i(int(e[0]),int(e[1]))
  if grid.belts.has(t):
   sim.items[t] = {"kind":str(e[2]),"progress":clampf(float(e[3]),0.0,0.98)}
 progress.from_data(data.get("milestone",{}))
 sim.produced_total = int(data.get("produced",0))
 sim.delivered_total = int(data.get("delivered",0))
 sim.history = []
 for h in data.get("history",[]):
  if h is Dictionary:
   sim.history.append(h)
 var cam: Array = data.get("camera",[])
 if cam.size() == 3:
  camera.position = Vector2(float(cam[0]),float(cam[1]))
  camera.zoom = Vector2.ONE * clampf(float(cam[2]),0.5,3.0)
 return data.get("inventory",{}).duplicate(true)
