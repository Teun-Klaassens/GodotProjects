extends RefCounted
## World editing helpers shared by mouse controls and tests.
## A rectangle selects each multi-tile machine only once, even if many of its tiles overlap.

const FactoryData = preload("res://scripts/components/factory_data.gd")
const BuildGrid = preload("res://scripts/components/build_grid.gd")

static func rectangle(first: Vector2i, last: Vector2i) -> Rect2i:
    var minimum: Vector2i = Vector2i(mini(first.x, last.x), mini(first.y, last.y))
    var maximum: Vector2i = Vector2i(maxi(first.x, last.x), maxi(first.y, last.y))
    return Rect2i(minimum, maximum - minimum + Vector2i.ONE)

static func pick(grid, tile: Vector2i) -> Dictionary:
    if not BuildGrid.in_bounds(tile):
        return {}
    var origin: Vector2i = grid.building_at(tile)
    if origin != Vector2i(-1, -1):
        var entry: Dictionary = grid.buildings[origin]
        return {"type": int(entry["type"]), "rotation": int(entry["rotation"]), "origin": origin}
    if grid.belts.has(tile):
        return {"type": 1, "rotation": 0, "origin": tile}
    return {}

static func targets(grid, first: Vector2i, last: Vector2i) -> Dictionary:
    var machines: Array[Vector2i] = []
    var belts: Array[Vector2i] = []
    var seen_machines: Dictionary = {}
    var selection: Rect2i = rectangle(first, last)
    var clipped: Rect2i = selection.intersection(Rect2i(0, 0, BuildGrid.WIDTH, BuildGrid.HEIGHT))
    for y in range(clipped.position.y, clipped.end.y):
        for x in range(clipped.position.x, clipped.end.x):
            var tile: Vector2i = Vector2i(x, y)
            if grid.belts.has(tile):
                belts.append(tile)
            else:
                var origin: Vector2i = grid.building_at(tile)
                if origin != Vector2i(-1, -1) and not seen_machines.has(origin):
                    seen_machines[origin] = true
                    machines.append(origin)
    return {"buildings": machines, "belts": belts}

static func has_targets(selection: Dictionary) -> bool:
    return not selection["buildings"].is_empty() or not selection["belts"].is_empty()

## Call history.remember() exactly once BEFORE calling this method.
static func remove(grid, sim, inventory: Dictionary, selection: Dictionary) -> Dictionary:
    var machines_removed: int = 0
    var belts_removed: int = 0
    for origin in selection["buildings"]:
        if not grid.buildings.has(origin):
            continue
        var kind: int = int(grid.buildings[origin]["type"])
        var cost: Dictionary = FactoryData.COSTS.get(kind, {})
        for item in cost.keys():
            inventory[item] = int(inventory.get(item, 0)) + int(cost[item])
        if sim.machines.has(origin):
            var machine: Dictionary = sim.machines[origin]
            for buffer_name in ["input", "output"]:
                var buffer: Dictionary = machine.get(buffer_name, {})
                for item in buffer.keys():
                    inventory[item] = int(inventory.get(item, 0)) + int(buffer[item])
            inventory["coal"] = int(inventory.get("coal", 0)) + int(machine.get("fuel", 0))
        if grid.erase_at(origin) > 0:
            machines_removed += 1
    for tile in selection["belts"]:
        if not grid.belts.has(tile):
            continue
        inventory["iron_plate"] = int(inventory.get("iron_plate", 0)) + 1
        if sim.items.has(tile):
            var carried: Dictionary = sim.items[tile]
            var item_name: String = str(carried.get("kind", ""))
            if item_name != "":
                inventory[item_name] = int(inventory.get(item_name, 0)) + 1
            sim.items.erase(tile)
        if grid.erase_at(tile) > 0:
            belts_removed += 1
    if machines_removed > 0 or belts_removed > 0:
        sim.sync_machines()
        sim.power.update(grid, sim.machines)
    return {"buildings": machines_removed, "belts": belts_removed}
