extends Node

const BuildGrid = preload("res://scripts/components/build_grid.gd")
const FactorySimulation = preload("res://scripts/components/factory_simulation.gd")
const MilestoneProgress = preload("res://scripts/components/milestone_progress.gd")

func _ready() -> void:
 var grid: BuildGrid = BuildGrid.new()
 for part in [[Vector2i(5,6),2],[Vector2i(10,6),3],[Vector2i(15,6),4],[Vector2i(22,6),6],
  [Vector2i(8,10),9],[Vector2i(13,10),11],[Vector2i(19,10),11]]:
  assert(grid.place(part[0],int(part[1]),0))
 for section in [[Vector2i(7,7),Vector2i(9,7)],[Vector2i(12,7),Vector2i(14,7)],[Vector2i(18,7),Vector2i(21,7)]]:
  assert(grid.place_path(grid.shortest_path(section[0],section[1])))
 var sim: FactorySimulation = FactorySimulation.new(grid)
 var progress: MilestoneProgress = MilestoneProgress.new()
 sim.delivery_callback = Callable(progress,"receive_item")
 sim.sync_machines()
 sim.power.update(grid,sim.machines)
 assert(sim.power.active(Vector2i(5,6)))
 assert(sim.power.active(Vector2i(10,6)))
 assert(sim.power.active(Vector2i(15,6)))
 for frame in range(2000):
  sim.tick(0.05)
 assert(sim.produced_total > 40)
 assert(sim.delivered_total >= 20)
 assert(progress.stage >= 1)
 assert(sim.history.size() > 0)
 assert(sim.history[0].has("consumed"))
 print("PASS: power, ore extraction, smelting, plates, conveyor delivery, milestone, history")
 get_tree().quit()
