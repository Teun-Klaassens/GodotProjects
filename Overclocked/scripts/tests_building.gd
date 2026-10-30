extends Node

const BuildGrid = preload("res://scripts/components/build_grid.gd")
const FactoryData = preload("res://scripts/components/factory_data.gd")
const BeltVisuals = preload("res://scripts/components/belt_visuals.gd")

func _ready() -> void:
    var grid: BuildGrid = BuildGrid.new()
    assert(grid.can_place(Vector2i(5,6),2,0)) # iron deposit
    assert(not grid.can_place(Vector2i(12,12),2,0)) # no deposit
    assert(grid.place(Vector2i(5,6),2,0))
    assert(not grid.can_place(Vector2i(6,6),3,0))
    assert(grid.place(Vector2i(10,6),3,0))
    assert(grid.place(Vector2i(15,6),4,0))
    assert(grid.place(Vector2i(22,6),6,0))
    assert(grid.building_at(Vector2i(23,7)) == Vector2i(22,6))
    assert(FactoryData.footprint(4,1) == Vector2i(2,3))
    assert(grid.input_ports(Vector2i(22,6)).size() == 3)
    assert(grid.input_adjacent(Vector2i(10,6)) == Vector2i(9,7))
    var p1: Array[Vector2i] = grid.shortest_path(Vector2i(7,7),Vector2i(9,7))
    assert(p1.size() == 3)
    assert(grid.place_path(p1))
    assert(grid.belts[Vector2i(9,7)] == Vector2i.RIGHT)
    assert(grid.receiver_for(Vector2i(9,7),Vector2i.RIGHT) == Vector2i(10,6))
    var p2: Array[Vector2i] = grid.shortest_path(Vector2i(12,7),Vector2i(14,7))
    assert(grid.place_path(p2))
    var p3: Array[Vector2i] = grid.shortest_path(Vector2i(18,7),Vector2i(21,7))
    assert(grid.place_path(p3))
    assert(grid.receiver_for(Vector2i(21,7),Vector2i.RIGHT) == Vector2i(22,6))
    assert(not grid.can_place(Vector2i(36,15),9,0)) # cliffs
    assert(not grid.place_path([]))
    var corners: BuildGrid = BuildGrid.new()
    var path: Array[Vector2i] = [Vector2i(2,2),Vector2i(3,2),Vector2i(3,3)]
    assert(corners.place_path(path))
    var visuals: BeltVisuals = BeltVisuals.new()
    assert(visuals.tile_kind(corners,Vector2i(3,2)) == "loop_clockwise_tr")
    assert(visuals.frame("loop_clockwise_tr",0) != null)
    assert(grid.erase_at(Vector2i(22,7)) == 6)
    print("PASS: grid, deposits, footprints, ports, shortest paths, loop corner, demolition")
    get_tree().quit()
