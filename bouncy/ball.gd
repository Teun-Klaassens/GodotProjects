extends CharacterBody2D
class_name Ball

@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var particles = $Trail
@onready var bounce_particles: GPUParticles2D = $BounceParticles

@export var is_ball_one := false
@export var colour_ball_one := Color("fe87a3ff")
@export var colour_ball_two := Color('#B18FCF')
@export var speed := 75.0



func _ready() -> void:
	# Set the position
	global_position.y = (get_viewport_rect().size.y/2)
	if is_ball_one:
		global_position.x = (get_viewport_rect().size.x/4) + (get_viewport_rect().size.y/2)
	else:
		global_position.x = (get_viewport_rect().size.x/4)

	# Set velocity
	velocity.x = -speed
	velocity.y = randi_range(-15, 15) # randomize that starting velocity a bit.

	# Set the correct colours
	polygon_2d.color = colour_ball_one if is_ball_one else colour_ball_two


func _physics_process(delta: float) -> void:
	var collision : KinematicCollision2D = move_and_collide(velocity * delta)
	# If there is a collision, bounce the ball and toggle the collided tile
	if collision:
		bounce_particles.restart()
		bounce_particles.emitting = true
		
		squash_and_stretch(collision.get_normal())

		velocity = velocity.bounce(collision.get_normal())

		if collision.get_collider() is Tile:
			particles.visible = true
			collision.get_collider().toggle(self)

			hit_stop()

func _get_collision_layer() -> int:
	return collision_layer
	
func squash_and_stretch(collision_normal: Vector2) -> void:
	pass
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	var squash_scale: Vector2

	# Hit left/right wall
	if abs(collision_normal.x) > abs(collision_normal.y):
		squash_scale = Vector2(0.0, 0.2)

	# Hit top/bottom
	else:
		squash_scale = Vector2(0.2, 0.0)

	tween.tween_property(
		polygon_2d,
		"scale",
		squash_scale,
		0.05
	)

	tween.tween_property(
		polygon_2d,
		"scale",
		Vector2.ONE,
		0.05
	)

func hit_stop() -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.04, true, false, true).timeout
	Engine.time_scale = 0.5
	await get_tree().create_timer(0.2, true, false, true).timeout
	Engine.time_scale = 1.0
