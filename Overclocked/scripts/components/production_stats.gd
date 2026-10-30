extends RefCounted
## Rolling 30-second performance snapshot from the 2-second history samples.
static func summary(sim, grid) -> String:
    var count: int = mini(15,sim.history.size())
    if count <= 0:
        return "Waiting for 2 seconds of production history."
    var produced: float = 0.0
    var consumed: float = 0.0
    var delivered: float = 0.0
    for i in range(sim.history.size()-count,sim.history.size()):
        var row: Dictionary = sim.history[i]
        produced += float(row.get("produced",0))
        consumed += float(row.get("consumed",0))
        delivered += float(row.get("delivered",0))
    var scale: float = 30.0/float(count)
    var jams: int = 0
    var full: int = 0
    for tile in sim.items.keys():
        if float(sim.items[tile].get("progress",0.0)) >= 0.97:
            jams += 1
    for origin in sim.machines.keys():
        var state: Dictionary = sim.machines[origin]
        var output: Dictionary = state.get("output",{})
        var total: int = 0
        for v in output.values():
            total += int(v)
        if total >= sim.OUTPUT_LIMIT:
            full += 1
    return "Last %ds  •  %.1f items/min produced  •  %.1f/min consumed  •  %.1f/min delivered
Bottlenecks: %d blocked belt items; %d full output buffers" % [count*2,produced*scale,consumed*scale,delivered*scale,jams,full]
