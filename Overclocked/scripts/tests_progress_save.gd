extends Node

const BuildGrid = preload("res://scripts/components/build_grid.gd")
const FactorySimulation = preload("res://scripts/components/factory_simulation.gd")
const MilestoneProgress = preload("res://scripts/components/milestone_progress.gd")
const SaveManager = preload("res://scripts/components/save_manager.gd")

func _ready() -> void:
    var progress: MilestoneProgress = MilestoneProgress.new()
    for i in range(20):
        progress.receive_item("iron_plate")
    assert(progress.stage == 1)
    for i in range(30):
        progress.receive_item("copper_wire")
    for i in range(20):
        progress.receive_item("iron_rod")
    assert(progress.stage == 2)
    for i in range(15):
        progress.receive_item("reinforced_plate")
    for i in range(10):
        progress.receive_item("circuit")
    for i in range(20):
        progress.receive_item("concrete")
    assert(progress.stage == 3)
    for i in range(50):
        progress.receive_item("iron_plate")
    assert(progress.completed == 1)
    var grid: BuildGrid = BuildGrid.new()
    assert(grid.place(Vector2i(5,6),2,0))
    assert(grid.place(Vector2i(8,10),9,0))
    assert(grid.place_path([Vector2i(7,7),Vector2i(8,7),Vector2i(9,7)]))
    var sim: FactorySimulation = FactorySimulation.new(grid)
    sim.sync_machines()
    sim.machines[Vector2i(5,6)]["produced"] = 12
    var camera: Camera2D = Camera2D.new()
    camera.position = Vector2(400,500)
    var inventory: Dictionary = {"iron_plate":17,"iron_rod":8}
    assert(SaveManager.save_game(grid,sim,progress,inventory,camera))
    grid.buildings.clear()
    grid.belts.clear()
    sim.machines.clear()
    var loaded: Dictionary = SaveManager.load_game(grid,sim,progress,camera)
    assert(int(loaded.get("iron_plate",0)) == 17)
    assert(grid.buildings.has(Vector2i(5,6)))
    assert(grid.belts.has(Vector2i(7,7)))
    assert(int(sim.machines[Vector2i(5,6)]["produced"]) == 12)
    assert(progress.completed == 1)
    assert(camera.position == Vector2(400,500))
    print("PASS: all milestones, endless contracts, save / load round trip")
    get_tree().quit()
