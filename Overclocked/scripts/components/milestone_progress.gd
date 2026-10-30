extends RefCounted

const FactoryData = preload("res://scripts/components/factory_data.gd")

var stage: int = 0
var counts: Dictionary = {}
var lifetime: Dictionary = {}
var completed: int = 0
var unlock_notice: String = ""
const ENDLESS_GOALS: Array[Dictionary] = [{"iron_plate":50},{"copper_wire":40},{"reinforced_plate":20},{"circuit":15}]

func receive_item(kind: String) -> void:
 lifetime[kind] = int(lifetime.get(kind,0)) + 1
 var goals: Dictionary = FactoryData.STAGES[stage] if stage < FactoryData.STAGES.size() else ENDLESS_GOALS[completed % ENDLESS_GOALS.size()]
 if goals.has(kind):
  counts[kind] = mini(int(counts.get(kind,0)) + 1, int(goals[kind]))
 var done: bool = true
 for required in goals.keys():
  if int(counts.get(required,0)) < int(goals[required]):
   done = false
 if done:
  counts.clear()
  if stage < FactoryData.STAGES.size():
   stage += 1
   unlock_notice = "Milestone complete! " + ("Endless contracts unlocked" if stage == 3 else "New technology unlocked")
  else:
   completed += 1
   unlock_notice = "Endless contract completed! New contract available."

func summary() -> String:
 var goals: Dictionary = FactoryData.STAGES[stage] if stage < FactoryData.STAGES.size() else ENDLESS_GOALS[completed % ENDLESS_GOALS.size()]
 var parts: Array[String] = []
 for item in goals.keys():
  parts.append("%s %d/%d" % [str(item).replace("_"," ").capitalize(), int(counts.get(item,0)), int(goals[item])])
 if stage >= FactoryData.STAGES.size():
  return "Endless #%d: %s" % [completed+1," · ".join(PackedStringArray(parts))]
 return "M%d/3: %s" % [stage+1, " · ".join(PackedStringArray(parts))]

func to_data() -> Dictionary:
 return {"stage": stage, "counts": counts.duplicate(true), "lifetime": lifetime.duplicate(true), "completed": completed}

func from_data(d: Dictionary) -> void:
 stage = clampi(int(d.get("stage",0)), 0, 3)
 counts = d.get("counts", {}).duplicate(true)
 lifetime = d.get("lifetime", {}).duplicate(true)
 completed = int(d.get("completed",0))
 unlock_notice = ""
