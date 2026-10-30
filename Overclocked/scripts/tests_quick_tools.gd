extends Node

const BuildGrid = preload("res://scripts/components/build_grid.gd")
const FactoryData = preload("res://scripts/components/factory_data.gd")
const FactorySimulation = preload("res://scripts/components/factory_simulation.gd")
const BuildHistory = preload("res://scripts/components/build_history.gd")
const ConstructionTools = preload("res://scripts/components/construction_tools.gd")

func _ready() -> void:
    var grid: BuildGrid = BuildGrid.new()
    assert(grid.place(Vector2i(10, 10), 3, 0)) # 2x2 smelter
    assert(grid.place(Vector2i(15, 10), 4, 1)) # Rotated 2x3 constructor
    assert(grid.place(Vector2i(20, 10), 8, 0)) # 2x2 storage
    var belt_path: Array[Vector2i] = [Vector2i(23, 10), Vector2i(23, 11), Vector2i(23, 12)]
    assert(grid.place_path(belt_path))
    var simulation: FactorySimulation = FactorySimulation.new(grid)
    simulation.sync_machines()
    simulation.items[Vector2i(23, 11)] = {"kind": "iron_ore", "progress": 0.25}
    var inventory: Dictionary = FactoryData.STARTER_INVENTORY.duplicate(true)
    var start_plates: int = int(inventory["iron_plate"])
    var history: BuildHistory = BuildHistory.new()

    # Middle-click eyedropper also works on a non-origin tile of rotated buildings.
    var picked: Dictionary = ConstructionTools.pick(grid, Vector2i(16, 12))
    assert(int(picked["type"]) == 4)
    assert(int(picked["rotation"]) == 1)
    assert(int(ConstructionTools.pick(grid, Vector2i(23, 11))["type"]) == 1)
    assert(ConstructionTools.pick(grid, Vector2i(0, 0)).is_empty())

    # Dragging in any direction produces an inclusive tile rectangle.
    assert(ConstructionTools.rectangle(Vector2i(5, 7), Vector2i(3, 5)) == Rect2i(3, 5, 3, 3))
    assert(not ConstructionTools.has_targets(ConstructionTools.targets(grid, Vector2i(-90, -90), Vector2i(-50, -50))))

    # Selection touching one tile of a multi-tile machine deletes it exactly once.
    var selection: Dictionary = ConstructionTools.targets(grid, Vector2i(23, 11), Vector2i(11, 11))
    assert(selection["buildings"].size() == 3)
    assert(selection["belts"].size() == 1)
    history.remember(grid, simulation, inventory)
    var removed: Dictionary = ConstructionTools.remove(grid, simulation, inventory, selection)
    assert(int(removed["buildings"]) == 3)
    assert(int(removed["belts"]) == 1)
    assert(grid.buildings.is_empty())
    assert(not grid.belts.has(Vector2i(23, 11)))
    assert(grid.belts.has(Vector2i(23, 10)))
    assert(not simulation.items.has(Vector2i(23, 11)))
    assert(int(inventory["iron_plate"]) == start_plates + 20)
    assert(int(inventory.get("iron_ore", 0)) == 1)

    # One Ctrl+Z restores all machines, the belt, and the carried item together.
    inventory = history.undo(grid, simulation, inventory)
    assert(grid.buildings.size() == 3)
    assert(grid.belts.has(Vector2i(23, 11)))
    assert(simulation.items.has(Vector2i(23, 11)))
    assert(int(inventory["iron_plate"]) == start_plates)
    print("PASS: picker, reverse drag, unique buildings, refunds, carried items, single-step undo")
    get_tree().quit()
