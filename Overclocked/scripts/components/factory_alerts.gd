extends RefCounted
## A snapshot of actionable factory problems. Uses no global class-name dependencies.
const Data = preload("res://scripts/components/factory_data.gd")
var alerts: Array[Dictionary] = []
var last_signature: String = ""

func refresh(grid, sim) -> bool:
    var next_alerts: Array[Dictionary] = []
    if sim.power.offline_count > 0:
        next_alerts.append({"severity":"critical", "label":"%d machines without power" % sim.power.offline_count, "tile":Vector2i(-1,-1)})
    if sim.power.demand > sim.power.capacity and sim.power.capacity > 0:
        next_alerts.append({"severity":"critical", "label":"Power demand exceeds generation", "tile":Vector2i(-1,-1)})
    var jams: int = 0
    for tile in sim.items.keys():
        if float(sim.items[tile].get("progress",0)) >= 0.97:
            jams += 1
    if jams > 0:
        next_alerts.append({"severity":"warning", "label":"%d blocked conveyor items" % jams, "tile":Vector2i(-1,-1)})
    var stalled: int = 0
    for origin in sim.machines.keys():
        if not grid.buildings.has(origin):
            continue
        var kind: int = int(grid.buildings[origin]["type"])
        var state: Dictionary = sim.machines[origin]
        if kind in [3,4,7] and bool(state.get("enabled",true)) and sim.power.active(origin):
            var recipe_name: String = str(state.get("recipe",""))
            if Data.RECIPES.has(recipe_name) and not sim._can_craft(state,Data.RECIPES[recipe_name]):
                stalled += 1
    if stalled > 0:
        next_alerts.append({"severity":"info", "label":"%d machines waiting for ingredients/output space" % stalled, "tile":Vector2i(-1,-1)})
    var parts: Array[String] = []
    for alert in next_alerts:
        parts.append(str(alert["severity"])+":"+str(alert["label"]))
    var signature: String = "|".join(PackedStringArray(parts))
    var changed: bool = signature != last_signature
    last_signature = signature
    alerts = next_alerts
    return changed

func summary() -> String:
    if alerts.is_empty():
        return "No active factory alerts"
    return "%d alerts: %s" % [alerts.size(),str(alerts[0]["label"])]

func details() -> String:
    if alerts.is_empty():
        return "All systems normal."
    var lines: Array[String] = []
    for alert in alerts:
        lines.append("[%s] %s" % [str(alert["severity"]).to_upper(),str(alert["label"])])
    return "
".join(PackedStringArray(lines))
