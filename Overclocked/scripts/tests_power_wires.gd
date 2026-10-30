extends Node2D
## F6 in scenes/tests/power_wires_test.tscn.
const Data = preload("res://scripts/components/factory_data.gd")
const Grid = preload("res://scripts/components/build_grid.gd")
const Simulation = preload("res://scripts/components/factory_simulation.gd")
const Wires = preload("res://scripts/components/power_wires.gd")

func _ready() -> void:
    var grid: Grid = Grid.new()
    var simulation: Simulation = Simulation.new(grid)
    var wires: Wires = Wires.new()
    add_child(wires)
    wires.configure(grid,simulation.power)
    assert(wires.connections().is_empty(),"Empty factory must have no wires")
    assert(grid.place(Vector2i(4,4),9,0),"Place generator")
    assert(grid.place(Vector2i(8,4),11,0),"Place first pole")
    assert(grid.place(Vector2i(12,4),11,0),"Place second pole")
    assert(grid.place(Vector2i(14,7),3,0),"Place smelter")
    simulation.sync_machines()
    var edges: Array[Dictionary] = wires.connections()
    assert(edges.size() == 3,"Expected 2 power-network cables and 1 consumer cable")
    var n_network: int = 0
    var n_consumer: int = 0
    for edge in edges:
        if edge["kind"] == "network":
            n_network += 1
        if edge["kind"] == "machine":
            n_consumer += 1
    assert(n_network == 2,"Expected 2 unique generator/pole links")
    assert(n_consumer == 1,"Expected 1 machine link")
    print("POWER WIRE VISUALIZATION TESTS PASSED")
