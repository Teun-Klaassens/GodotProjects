extends StaticBody2D
class_name Tile

@onready var polygon_2d: Polygon2D = $Polygon2D

@export var ball: Ball


func _ready() -> void:
	set_color()


func toggle(collided_ball: Ball) -> void:
	ball = collided_ball

	collision_layer = ball._get_collision_layer()

	highlight()
	set_color()
	start_ripple()
	
	get_tree().current_scene.update_score()
	
func highlight() -> void:
	z_index = 10
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.16)
	tween.tween_property(self, "scale", Vector2.ONE, 0)
	await tween.finished

	
	z_index = 0
	
func set_color() -> void:
	var target_color: Color

	if ball.is_ball_one:
		target_color = ball.colour_ball_two
	else:
		target_color = ball.colour_ball_one

	var tween = create_tween()

	tween.tween_property(
		polygon_2d,
		"color",
		Color(1, 0.2, 0.2, 0.5),
		0.1
	)

	tween.tween_property(
		polygon_2d,
		"color",
		target_color,
		0.3
	)

func start_ripple() -> void:
	for tile in get_parent().get_children():
		if tile is Tile and tile != self:
			var distance = global_position.distance_to(tile.global_position)

			if(distance < 30):
				tile.ripple(distance)
			
func ripple(distance: float) -> void:
	var delay = distance * 0.006

	await get_tree().create_timer(delay).timeout

	var tween = create_tween()

	tween.tween_property(
		self,
		"scale",
		Vector2(1.2, 1.2),
		0.18
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.12
	)
