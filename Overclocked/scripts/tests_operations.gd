extends Node
const Grid = preload("res://scripts/components/build_grid.gd")
const Sim = preload("res://scripts/components/factory_simulation.gd")
const History = preload("res://scripts/components/build_history.gd")
const Inventory = preload("res://scripts/components/inventory_rules.gd")
const Statistics = preload("res://scripts/components/production_stats.gd")

func _ready() -> void:
    var grid = Grid.new()
    var sim = Sim.new(grid)
    var edits = History.new()
    var inv: Dictionary = {"iron_plate":240,"coal":4}
    assert(Inventory.get_stacks(240)==3)
    assert(Inventory.get_stacks(100)==1)
    edits.remember(grid,sim,inv)
    assert(grid.place(Vector2i(10,10),3,0))
    inv["iron_plate"] -= 6
    var recovered: Dictionary = edits.undo(grid,sim,inv)
    assert(grid.buildings.is_empty())
    assert(int(recovered["iron_plate"])==240)
    inv = recovered
    inv = edits.redo(grid,sim,inv)
    assert(grid.buildings.has(Vector2i(10,10)))
    assert(int(inv["iron_plate"])==234)
    assert(Statistics.summary(sim,grid).contains("Waiting"))
    assert(sim.power.dashboard().contains("Total:"))
    print("PASS: transactional undo/redo, inventory stacks, statistics, power dashboard")
    get_tree().quit()
