extends RefCounted

const BuildGrid = preload("res://scripts/components/build_grid.gd")
const FactoryData = preload("res://scripts/components/factory_data.gd")

const CONNECT_DISTANCE: float = 7.0
const MACHINE_DISTANCE: float = 6.0
var capacity: int = 0
var demand: int = 0
var powered: Dictionary = {} # machine origin -> bool
var group_count: int = 0
var offline_count: int = 0

func center(grid: BuildGrid, origin: Vector2i) -> Vector2:
 var entry: Dictionary = grid.buildings[origin]
 var sz: Vector2i = FactoryData.footprint(int(entry["type"]), int(entry["rotation"]))
 return Vector2(origin) + Vector2(sz) * 0.5

func update(grid: BuildGrid, machines: Dictionary) -> void:
 powered.clear()
 capacity = 0
 demand = 0
 offline_count = 0
 group_count = 0
 var nodes: Array[Vector2i] = []
 for origin in grid.buildings.keys():
  var kind: int = int(grid.buildings[origin]["type"])
  if kind == 9 or kind == 10 or kind == 11:
   nodes.append(origin)
 var groups: Array = []
 var seen: Dictionary = {}
 for node in nodes:
  if seen.has(node):
   continue
  var group: Array[Vector2i] = []
  var queue: Array[Vector2i] = [node]
  seen[node] = true
  var head: int = 0
  while head < queue.size():
   var current: Vector2i = queue[head]
   head += 1
   group.append(current)
   for other in nodes:
    if not seen.has(other) and center(grid,current).distance_to(center(grid,other)) <= CONNECT_DISTANCE:
     seen[other] = true
     queue.append(other)
  groups.append(group)
 group_count = groups.size()
 var demands: Array[int] = []
 var capacities: Array[int] = []
 for group in groups:
  var supply: int = 0
  for origin in group:
   var kind: int = int(grid.buildings[origin]["type"])
   if kind == 9:
    supply += 60
   elif kind == 10 and int(machines.get(origin, {}).get("fuel",0)) > 0:
    supply += 150
  capacities.append(supply)
  demands.append(0)
  capacity += supply
 var machine_groups: Dictionary = {}
 for origin in grid.buildings.keys():
  var kind: int = int(grid.buildings[origin]["type"])
  if not FactoryData.POWER.has(kind):
   continue
  var closest: float = INF
  var chosen: int = -1
  for i in range(groups.size()):
   for power_node in groups[i]:
    var distance: float = center(grid,origin).distance_to(center(grid,power_node))
    if distance < closest and distance <= MACHINE_DISTANCE:
     closest = distance
     chosen = i
  machine_groups[origin] = chosen
  if chosen >= 0:
   demands[chosen] += int(FactoryData.POWER[kind])
 for i in range(groups.size()):
  demand += demands[i]
 for origin in machine_groups.keys():
  var group_id: int = int(machine_groups[origin])
  var enabled: bool = group_id >= 0 and capacities[group_id] >= demands[group_id] and capacities[group_id] > 0
  powered[origin] = enabled
  if not enabled:
   offline_count += 1

func active(origin: Vector2i) -> bool:
 return bool(powered.get(origin, false))

func summary() -> String:
 return "Power %d/%d kW | %d offline" % [demand, capacity, offline_count]
