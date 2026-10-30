extends RefCounted

const FactoryData = preload("res://scripts/components/factory_data.gd")

const TILE_SIZE: int = 64
const WIDTH: int = 40
const HEIGHT: int = 30
const CARDINAL: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var buildings: Dictionary = {} # Vector2i -> {type:int,rotation:int}
var belts: Dictionary = {} # Vector2i -> outgoing direction
var belt_inputs: Dictionary = {} # Vector2i -> incoming direction of travel

static func in_bounds(t: Vector2i) -> bool:
    return t.x >= 0 and t.y >= 0 and t.x < WIDTH and t.y < HEIGHT

static func is_terrain_blocked(t: Vector2i) -> bool:
    return (t.x >= 35 and t.y >= 1 and t.y <= 7) or (t.x >= 2 and t.x <= 5 and t.y >= 25 and t.y <= 28) or (t.x >= 36 and t.x <= 38 and t.y >= 14 and t.y <= 25)

static func footprint(kind: int, rot: int) -> Vector2i:
    return FactoryData.footprint(kind, rot)

func building_at(tile: Vector2i) -> Vector2i:
    for origin in buildings.keys():
        var entry: Dictionary = buildings[origin]
        var sz: Vector2i = footprint(int(entry["type"]), int(entry["rotation"]))
        if tile.x >= origin.x and tile.x < origin.x + sz.x and tile.y >= origin.y and tile.y < origin.y + sz.y:
            return origin
    return Vector2i(-1,-1)

func occupied(t: Vector2i) -> bool:
    return belts.has(t) or building_at(t) != Vector2i(-1,-1)

func can_place(origin: Vector2i, kind: int, rot: int) -> bool:
    if not FactoryData.SIZES.has(kind):
        return false
    var sz: Vector2i = footprint(kind, rot)
    for y in range(sz.y):
        for x in range(sz.x):
            var t: Vector2i = origin + Vector2i(x,y)
            if not in_bounds(t) or is_terrain_blocked(t) or occupied(t):
                return false
    if kind == 2 and FactoryData.deposit_at(origin, sz) == "":
        return false
    return true

func place(origin: Vector2i, kind: int, rot: int) -> bool:
    if not can_place(origin, kind, rot):
        return false
    buildings[origin] = {"type": kind, "rotation": posmod(rot, 4)}
    return true

func erase_at(tile: Vector2i) -> int:
    if belts.has(tile):
        belts.erase(tile)
        belt_inputs.erase(tile)
        return 1
    var origin: Vector2i = building_at(tile)
    if origin != Vector2i(-1,-1):
        var kind: int = int(buildings[origin]["type"])
        buildings.erase(origin)
        return kind
    return 0

func shortest_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
    var empty: Array[Vector2i] = []
    if not in_bounds(start) or not in_bounds(goal):
        return empty
    if is_terrain_blocked(start) or is_terrain_blocked(goal) or building_at(start) != Vector2i(-1,-1) or building_at(goal) != Vector2i(-1,-1):
        return empty
    var queue: Array[Vector2i] = [start]
    var previous: Dictionary = {start: start}
    var head: int = 0
    while head < queue.size():
        var current: Vector2i = queue[head]
        head += 1
        if current == goal:
            break
        for d in CARDINAL:
            var nxt: Vector2i = current + d
            if not in_bounds(nxt) or is_terrain_blocked(nxt) or previous.has(nxt):
                continue
            if building_at(nxt) != Vector2i(-1,-1):
                continue
            if belts.has(nxt) and nxt != goal:
                continue
            previous[nxt] = current
            queue.append(nxt)
    if not previous.has(goal):
        return empty
    var path: Array[Vector2i] = []
    var tile: Vector2i = goal
    while tile != start:
        path.push_front(tile)
        tile = previous[tile]
    path.push_front(start)
    return path

func place_path(path: Array[Vector2i]) -> bool:
    if path.size() < 2:
        return false
    for i in range(path.size()):
        var tile: Vector2i = path[i]
        if not in_bounds(tile) or is_terrain_blocked(tile) or building_at(tile) != Vector2i(-1,-1):
            return false
        if belts.has(tile) and i != 0 and i != path.size()-1:
            return false
    for i in range(path.size()):
        var tile: Vector2i = path[i]
        var incoming: Vector2i = path[i] - path[i-1] if i > 0 else path[1] - path[0]
        var outgoing: Vector2i = path[i+1] - path[i] if i < path.size()-1 else incoming
        if i == 0 and belts.has(tile):
            incoming = belt_inputs.get(tile, incoming)
        if i == path.size()-1:
            # The terminal should point into a compatible receiver's designated input.
            for d in CARDINAL:
                var maybe: Vector2i = tile + d
                var receiver: Vector2i = building_at(maybe)
                if receiver != Vector2i(-1,-1) and receiver_for(tile, d) == receiver:
                    outgoing = d
                    break
        belts[tile] = outgoing
        belt_inputs[tile] = incoming
    return true

func get_input_port(origin: Vector2i) -> Vector2i:
    return port_tile(origin, false)

func port_tile(origin: Vector2i, is_output: bool) -> Vector2i:
    var entry: Dictionary = buildings.get(origin, {})
    if entry.is_empty():
        return Vector2i(-100,-100)
    var kind: int = int(entry["type"])
    var sz: Vector2i = footprint(kind, int(entry["rotation"]))
    var d: Vector2i = FactoryData.direction(int(entry["rotation"]))
    var middle: Vector2i = origin + Vector2i(int(sz.x / 2), int(sz.y / 2))
    if d == Vector2i.RIGHT:
        return Vector2i(origin.x + sz.x, middle.y) if is_output else Vector2i(origin.x, middle.y)
    if d == Vector2i.LEFT:
        return Vector2i(origin.x-1, middle.y) if is_output else Vector2i(origin.x+sz.x-1, middle.y)
    if d == Vector2i.DOWN:
        return Vector2i(middle.x, origin.y+sz.y) if is_output else Vector2i(middle.x, origin.y)
    return Vector2i(middle.x, origin.y-1) if is_output else Vector2i(middle.x, origin.y+sz.y-1)

func input_ports(origin: Vector2i) -> Array[Vector2i]:
    # Assembler and hub have three fixed rear input ports for multi-item recipes.
    var ports: Array[Vector2i] = [get_input_port(origin)]
    var kind: int = int(buildings[origin]["type"])
    if kind in [6,7]:
        var sz: Vector2i = footprint(kind,int(buildings[origin]["rotation"]))
        var d: Vector2i = FactoryData.direction(int(buildings[origin]["rotation"]))
        var side: Vector2i = Vector2i(-d.y,d.x)
        var p: Vector2i = ports[0]
        var span: int = sz.y if d.x != 0 else sz.x
        for offset in [-1,1]:
            var t: Vector2i = p + side * offset
            if t.x >= origin.x and t.y >= origin.y and t.x < origin.x + sz.x and t.y < origin.y + sz.y and span >= 3:
                ports.append(t)
    return ports

func input_adjacent(origin: Vector2i) -> Vector2i:
    return get_input_port(origin) - FactoryData.direction(int(buildings[origin]["rotation"]))

func output_adjacent(origin: Vector2i) -> Vector2i:
    return port_tile(origin, true)

func junction_outputs(origin: Vector2i) -> Array[Vector2i]:
    if not buildings.has(origin):
        return []
    var kind: int = int(buildings[origin]["type"])
    var d: Vector2i = FactoryData.direction(int(buildings[origin]["rotation"]))
    if kind == 12:
        return [d, Vector2i(-d.y,d.x), Vector2i(d.y,-d.x)]
    if kind == 13:
        return [d]
    return []

func receiver_for(tile: Vector2i, direction: Vector2i) -> Vector2i:
    var target: Vector2i = tile + direction
    var origin: Vector2i = building_at(target)
    if origin == Vector2i(-1,-1):
        return origin
    var receiver_kind: int = int(buildings[origin]["type"])
    if receiver_kind in [12,13]:
        var facing: Vector2i = FactoryData.direction(int(buildings[origin]["rotation"]))
        if receiver_kind == 12:
            return origin if direction == facing else Vector2i(-1,-1)
        # Mergers accept from rear and either side, never from the front.
        return origin if direction != -facing else Vector2i(-1,-1)
    var entered: bool = false
    for port in input_ports(origin):
        if port - direction == tile:
            entered = true
    if not entered:
        return Vector2i(-1,-1)
    if FactoryData.direction(int(buildings[origin]["rotation"])) != direction:
        return Vector2i(-1,-1)
    return origin
