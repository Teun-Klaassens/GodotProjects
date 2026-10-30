extends RefCounted

# Single source for recipes, building costs, footprints and milestone requirements.
const NAMES: Dictionary = {
    1: "Conveyor", 2: "Miner", 3: "Smelter", 4: "Constructor", 5: "Demolish",
    6: "Delivery Hub", 7: "Assembler", 8: "Storage", 9: "Generator",
    10: "Coal Generator", 11: "Power Pole", 12: "Splitter", 13: "Merger"
}
const COSTS: Dictionary = {
    1: {"iron_plate": 1}, 2: {"iron_plate": 8, "iron_rod": 4},
    3: {"iron_plate": 6, "iron_rod": 2}, 4: {"iron_plate": 8, "iron_rod": 4},
    6: {"iron_plate": 12}, 7: {"reinforced_plate": 4, "copper_wire": 8},
    8: {"iron_plate": 5}, 9: {"iron_plate": 10},
    10: {"reinforced_plate": 5, "copper_wire": 10, "concrete": 6},
    11: {"iron_rod": 2, "copper_wire": 2},
    12: {"iron_plate": 3, "iron_rod": 2}, 13: {"iron_plate": 3, "iron_rod": 2}
}
const SIZES: Dictionary = {2: Vector2i(2,2), 3: Vector2i(2,2), 4: Vector2i(3,2),
    6: Vector2i(4,3), 7: Vector2i(3,3), 8: Vector2i(2,2),
    9: Vector2i(2,2), 10: Vector2i(3,3), 11: Vector2i(1,1),
    12: Vector2i(1,1), 13: Vector2i(1,1)}
const POWER: Dictionary = {2: 6, 3: 8, 4: 10, 7: 16, 8: 2}
const RECIPES: Dictionary = {
    "iron_ingot": {"machine": 3, "inputs": {"iron_ore": 1}, "outputs": {"iron_ingot": 1}, "seconds": 1.0},
    "copper_ingot": {"machine": 3, "inputs": {"copper_ore": 1}, "outputs": {"copper_ingot": 1}, "seconds": 1.0},
    "iron_plate": {"machine": 4, "inputs": {"iron_ingot": 2}, "outputs": {"iron_plate": 1}, "seconds": 2.0},
    "iron_rod": {"machine": 4, "inputs": {"iron_ingot": 1}, "outputs": {"iron_rod": 2}, "seconds": 1.5},
    "copper_wire": {"machine": 4, "inputs": {"copper_ingot": 1}, "outputs": {"copper_wire": 2}, "seconds": 1.5},
    "concrete": {"machine": 4, "inputs": {"limestone": 2}, "outputs": {"concrete": 1}, "seconds": 2.0},
    "reinforced_plate": {"machine": 7, "inputs": {"iron_plate": 2, "iron_rod": 2}, "outputs": {"reinforced_plate": 1}, "seconds": 3.0},
    "circuit": {"machine": 7, "inputs": {"copper_wire": 2, "iron_plate": 1}, "outputs": {"circuit": 1}, "seconds": 3.0}
}
const RECIPE_ORDER: Array[String] = ["iron_ingot", "copper_ingot", "iron_plate", "iron_rod", "copper_wire", "concrete", "reinforced_plate", "circuit"]
const DEPOSITS: Array[Dictionary] = [
    {"tile": Vector2i(5,6), "kind": "iron_ore"},
    {"tile": Vector2i(5,19), "kind": "iron_ore"},
    {"tile": Vector2i(19,5), "kind": "copper_ore"},
    {"tile": Vector2i(30,8), "kind": "copper_ore"},
    {"tile": Vector2i(28,22), "kind": "limestone"},
    {"tile": Vector2i(10,24), "kind": "coal"},
    {"tile": Vector2i(32,25), "kind": "iron_ore"}
]
const STAGES: Array[Dictionary] = [
    {"iron_plate": 20},
    {"copper_wire": 30, "iron_rod": 20},
    {"reinforced_plate": 15, "circuit": 10, "concrete": 20}
]
const STARTER_INVENTORY: Dictionary = {
    "iron_plate": 160, "iron_rod": 70, "copper_wire": 55,
    "reinforced_plate": 10, "concrete": 18, "circuit": 0, "coal": 10
}

static func direction(rotation: int) -> Vector2i:
    var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
    return dirs[posmod(rotation, 4)]

static func footprint(kind: int, rotation: int) -> Vector2i:
    var size: Vector2i = SIZES.get(kind, Vector2i.ONE)
    if rotation % 2 != 0:
        return Vector2i(size.y, size.x)
    return size

static func recipes_for(kind: int) -> Array[String]:
    var found: Array[String] = []
    for key in RECIPE_ORDER:
        if int(RECIPES[key]["machine"]) == kind:
            found.append(key)
    return found

static func default_recipe(kind: int) -> String:
    var all_recipes: Array[String] = recipes_for(kind)
    if all_recipes.is_empty():
        return ""
    return all_recipes[0]

static func deposit_at(tile: Vector2i, size: Vector2i) -> String:
    for dep in DEPOSITS:
        var p: Vector2i = dep["tile"]
        if p.x >= tile.x and p.y >= tile.y and p.x < tile.x + size.x and p.y < tile.y + size.y:
            return str(dep["kind"])
    return ""

static func tool_unlocked(kind: int, stage: int) -> bool:
    if kind == 7 or kind == 10:
        return stage >= 2
    if kind == 8:
        return stage >= 1
    return true

static func recipe_unlocked(recipe: String, stage: int) -> bool:
    if recipe in ["copper_ingot", "copper_wire", "iron_rod"]:
        return stage >= 1
    if recipe in ["concrete", "reinforced_plate", "circuit"]:
        return stage >= 2
    return true

static func format_items(items: Dictionary) -> String:
    if items.is_empty():
        return "none"
    var parts: Array[String] = []
    for kind in items.keys():
        if int(items[kind]) != 0:
            parts.append("%s ×%d" % [str(kind).replace("_", " ").capitalize(), int(items[kind])])
    return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "none"
