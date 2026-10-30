extends Control

var samples: Array[Dictionary] = []

func _ready() -> void:
    custom_minimum_size = Vector2(390, 172)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var bounds: Rect2 = Rect2(Vector2(24, 15), size - Vector2(40, 35))
    draw_rect(bounds, Color("202b33"))
    for j in range(5):
        var y: float = bounds.position.y + bounds.size.y * float(j) / 4.0
        draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),Color(1,1,1,0.12),1)
    if samples.size() <= 1:
        return
    var highest: float = 1.0
    for s in samples:
        for key in ["produced","consumed","delivered","power_used","power_supply"]:
            highest = maxf(highest,float(s.get(key,0)))
    var columns: Array = [[],[],[],[],[]]
    for i in range(samples.size()):
        var x: float = bounds.position.x + bounds.size.x * float(i) / float(samples.size()-1)
        var s: Dictionary = samples[i]
        var names: Array[String] = ["produced","consumed","delivered","power_used","power_supply"]
        for j in range(names.size()):
            var y: float = bounds.end.y - bounds.size.y * float(s.get(names[j],0)) / highest
            columns[j].append(Vector2(x,y))
    var colors: Array[Color] = [Color("76dd9c"),Color("cf91ea"),Color("f4d36b"),Color("ff9871"),Color("89caff")]
    for j in range(columns.size()):
        var points: PackedVector2Array = PackedVector2Array(columns[j])
        if points.size() >= 2:
            draw_polyline(points,colors[j],2.0,true)
