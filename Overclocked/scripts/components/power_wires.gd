extends Node2D
## Renders sprite-based orange cables for the *same* automatic connections
## used by PowerNetwork. Every edge has two world-space end points.
const Data = preload("res://scripts/components/factory_data.gd")
const PowerNetwork = preload("res://scripts/components/power_network.gd")
const WIRE: Texture2D = preload("res://assets/sprites/power_wire.png")
const TILE: float = 64.0
var grid
var power
var enabled: bool = true

func configure(build_grid, network) -> void:
 grid = build_grid
 power = network
 queue_redraw()

func connections() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 if grid == null:
  return result
 var nodes: Array[Vector2i] = []
 for origin in grid.buildings.keys():
  var kind: int = int(grid.buildings[origin]["type"])
  if kind in [9,10,11]:
   nodes.append(origin)
 # Traverse the same radius-connected pole/generator graph as PowerNetwork.
 # Each edge is drawn once, including connections between generators and poles.
 var seen: Dictionary = {}
 for root in nodes:
  if seen.has(root):
   continue
  seen[root] = true
  var queue: Array[Vector2i] = [root]
  var head: int = 0
  while head < queue.size():
   var origin: Vector2i = queue[head]
   head += 1
   for candidate in nodes:
    if seen.has(candidate):
     continue
    if _center(origin).distance_to(_center(candidate)) <= PowerNetwork.CONNECT_DISTANCE*TILE:
     seen[candidate] = true
     queue.append(candidate)
     result.append({"from":origin,"to":candidate,"active":true,"kind":"network"})
 # Consumers are wired to exactly the nearest node within range, matching
 # PowerNetwork.update(). Machines don't create new pole-to-pole connections.
 for origin in grid.buildings.keys():
  var kind: int = int(grid.buildings[origin]["type"])
  if not Data.POWER.has(kind):
   continue
  var best: Vector2i = Vector2i(-1,-1)
  var distance: float = INF
  for node in nodes:
   var d: float = _center(origin).distance_to(_center(node))
   if d < distance and d <= PowerNetwork.MACHINE_DISTANCE*TILE:
    best = node
    distance = d
  if best != Vector2i(-1,-1):
   var receiving_power: bool = power != null and power.active(origin)
   result.append({"from":best,"to":origin,"active":receiving_power,"kind":"machine"})
 return result

func _center(origin: Vector2i) -> Vector2:
 var entry: Dictionary = grid.buildings[origin]
 var footprint: Vector2i = Data.footprint(int(entry["type"]),int(entry["rotation"]))
 return (Vector2(origin)+Vector2(footprint)*0.5)*TILE

func _anchor(origin: Vector2i) -> Vector2:
 var center: Vector2 = _center(origin)
 var kind: int = int(grid.buildings[origin]["type"])
 if kind == 11:
  return center+Vector2(0,-25)
 if kind in [9,10]:
  return center+Vector2(0,-13)
 return center+Vector2(0,-12)

func _draw() -> void:
 if not enabled or grid == null:
  return
 for segment in connections():
  _draw_cable(_anchor(segment["from"]),_anchor(segment["to"]),bool(segment["active"]))

func _curve_point(a: Vector2,b: Vector2,t: float) -> Vector2:
 var sag: float = minf(22.0,a.distance_to(b)*0.095)
 return a.lerp(b,t)+Vector2(0,sag*sin(t*PI))

func _draw_cable(a: Vector2,b: Vector2,powered: bool) -> void:
 var distance: float = a.distance_to(b)
 if distance < 3.0:
  return
 var count: int = maxi(2,ceili(distance/20.0))
 var tint: Color = Color(1,1,1,0.98) if powered else Color(0.60,0.74,0.86,0.65)
 for index in range(count):
  var point_a: Vector2 = _curve_point(a,b,float(index)/float(count))
  var point_b: Vector2 = _curve_point(a,b,float(index+1)/float(count))
  var segment: Vector2 = point_b-point_a
  draw_set_transform(point_a,segment.angle(),Vector2.ONE)
  draw_texture_rect(WIRE,Rect2(Vector2(0,-5),Vector2(segment.length()+0.6,10)),false,tint)
 draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
 # Small connectors anchor each visible cable to its machines.
 for point in [a,b]:
  draw_circle(point,4.5,Color("29343c"))
  draw_circle(point,2.5,Color("ffb85b") if powered else Color("a4bac8"))
