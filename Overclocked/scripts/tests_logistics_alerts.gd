extends Node
const Grid = preload("res://scripts/components/build_grid.gd")
const Sim = preload("res://scripts/components/factory_simulation.gd")
const Alerts = preload("res://scripts/components/factory_alerts.gd")

func _ready() -> void:
    var grid = Grid.new()
    assert(grid.place(Vector2i(9,9),12,0))
    assert(grid.place(Vector2i(15,9),13,0))
    assert(grid.receiver_for(Vector2i(8,9),Vector2i.RIGHT) == Vector2i(9,9))
    assert(grid.receiver_for(Vector2i(9,8),Vector2i.DOWN) == Vector2i(-1,-1))
    assert(grid.receiver_for(Vector2i(15,8),Vector2i.DOWN) == Vector2i(15,9))
    assert(grid.receiver_for(Vector2i(14,9),Vector2i.RIGHT) == Vector2i(15,9))
    assert(grid.junction_outputs(Vector2i(9,9)).size() == 3)
    assert(grid.place_path([Vector2i(10,9),Vector2i(11,9)]))
    assert(grid.place_path([Vector2i(9,10),Vector2i(9,11)]))
    var sim = Sim.new(grid)
    sim.sync_machines()
    var a: Dictionary = sim.machines[Vector2i(9,9)]
    a["input"] = {"iron_ore": 3}
    sim.machines[Vector2i(9,9)] = a
    sim._release_outputs()
    assert(sim.items.size() == 1)
    assert(int(sim.machines[Vector2i(9,9)]["input"]["iron_ore"]) == 2)
    sim.items.clear()
    sim._release_outputs()
    assert(sim.items.size() == 1)
    var alert = Alerts.new()
    alert.refresh(grid,sim)
    assert(alert.details() != "")
    print("PASS: split/merge ports, round robin, alerts, paths")
    get_tree().quit()
