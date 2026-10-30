extends RefCounted
## In-memory transactional undo/redo of construction and machine settings.
const LIMIT: int = 40
var undos: Array[Dictionary] = []
var redos: Array[Dictionary] = []

func capture(grid, sim, inventory: Dictionary) -> Dictionary:
    return {"buildings":grid.buildings.duplicate(true), "belts":grid.belts.duplicate(true),
        "belt_inputs":grid.belt_inputs.duplicate(true),"machines":sim.machines.duplicate(true),
        "items":sim.items.duplicate(true),"inventory":inventory.duplicate(true)}

func remember(grid, sim, inventory: Dictionary) -> void:
    undos.append(capture(grid,sim,inventory))
    if undos.size() > LIMIT:
        undos.pop_front()
    redos.clear()

func _restore(snapshot: Dictionary, grid, sim) -> Dictionary:
    grid.buildings = snapshot["buildings"].duplicate(true)
    grid.belts = snapshot["belts"].duplicate(true)
    grid.belt_inputs = snapshot["belt_inputs"].duplicate(true)
    sim.machines = snapshot["machines"].duplicate(true)
    sim.items = snapshot["items"].duplicate(true)
    sim.sync_machines()
    sim.power.update(grid,sim.machines)
    return snapshot["inventory"].duplicate(true)

func undo(grid, sim, inventory: Dictionary) -> Dictionary:
    if undos.is_empty():
        return {}
    redos.append(capture(grid,sim,inventory))
    return _restore(undos.pop_back(),grid,sim)

func redo(grid, sim, inventory: Dictionary) -> Dictionary:
    if redos.is_empty():
        return {}
    undos.append(capture(grid,sim,inventory))
    return _restore(redos.pop_back(),grid,sim)

func reset() -> void:
    undos.clear()
    redos.clear()
