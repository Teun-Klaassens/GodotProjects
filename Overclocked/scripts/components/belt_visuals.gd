extends RefCounted

# The original v5 ZIP referenced this class but omitted the file.
# Four 32x32 frames per conveyor tile were exported from the user's Aseprite artwork.
const BuildGrid = preload("res://scripts/components/build_grid.gd")
const SOURCE: String = "res://assets/Overclocked_Assets/conveyors/tiles/"
const FRAME_COUNT: int = 4

var textures: Dictionary = {}

func _init() -> void:
 for kind in ["horizontal_left", "horizontal_right", "vertical_up", "vertical_down",
  "loop_clockwise_tl", "loop_clockwise_tr", "loop_clockwise_bl", "loop_clockwise_br",
  "loop_counterclockwise_tl", "loop_counterclockwise_tr", "loop_counterclockwise_bl", "loop_counterclockwise_br"]:
  var frames: Array[Texture2D] = []
  for i in range(FRAME_COUNT):
   var path: String = SOURCE + kind + "/frame_%02d.png" % i
   var texture: Texture2D = load(path)
   if texture != null:
    frames.append(texture)
  textures[kind] = frames

func frame(kind: String, index: int) -> Texture2D:
 var frames: Array = textures.get(kind, [])
 if frames.is_empty():
  return null
 return frames[posmod(index, frames.size())]

func tile_kind(grid: BuildGrid, tile: Vector2i) -> String:
 var outgoing: Vector2i = grid.belts.get(tile, Vector2i.RIGHT)
 var incoming: Vector2i = grid.belt_inputs.get(tile, outgoing)
 if incoming == outgoing:
  if outgoing == Vector2i.LEFT:
   return "horizontal_left"
  if outgoing == Vector2i.UP:
   return "vertical_up"
  if outgoing == Vector2i.DOWN:
   return "vertical_down"
  return "horizontal_right"
 # Travel-direction turns: clockwise (R->D->L->U) and counterclockwise.
 # Use the quarter-loop sprites from the uploaded Aseprite sheet.
 if incoming == Vector2i.RIGHT and outgoing == Vector2i.DOWN:
  return "loop_clockwise_tr"
 if incoming == Vector2i.DOWN and outgoing == Vector2i.LEFT:
  return "loop_clockwise_br"
 if incoming == Vector2i.LEFT and outgoing == Vector2i.UP:
  return "loop_clockwise_bl"
 if incoming == Vector2i.UP and outgoing == Vector2i.RIGHT:
  return "loop_clockwise_tl"
 if incoming == Vector2i.RIGHT and outgoing == Vector2i.UP:
  return "loop_counterclockwise_br"
 if incoming == Vector2i.UP and outgoing == Vector2i.LEFT:
  return "loop_counterclockwise_tr"
 if incoming == Vector2i.LEFT and outgoing == Vector2i.DOWN:
  return "loop_counterclockwise_tl"
 if incoming == Vector2i.DOWN and outgoing == Vector2i.RIGHT:
  return "loop_counterclockwise_bl"
 return "horizontal_right"
