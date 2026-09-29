
extends Node2D

@export var object_scenes: Array[PackedScene]

@export_category("Camera")
@export var camera_threshold: float = 150.0
@export var camera_speed: float = 3.0

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var camera: Camera2D = $Camera

@export_category("Ghost")
@export var ghost_opacity: float = 0.3
@export var ghost_distance: float = 3000.0
@export var ghost_offset: float = 2.0

@onready var prediction_world = $PredictionWorld

var ghost: Node2D


var current_box: RigidBody2D
var is_game_over = false

var starting_camera_y: float
var target_camera_y: float

var last_prediction_x: float = INF

@export_category("Prediction")
@export var prediction_interval: float = 0.15

var prediction_timer: float = 0.0


func _ready() -> void:
	starting_camera_y = camera.global_position.y
	target_camera_y = starting_camera_y
	
	prediction_world.prediction_ready.connect(_on_prediction_ready)

	spawn_box()

func _physics_process(delta: float) -> void:
	if is_game_over:
		return

	if not is_instance_valid(current_box):
		return

	if current_box.is_dropped:
		ghost.visible = false
		return

	prediction_timer -= delta

	if prediction_timer <= 0.0:
		if absf(current_box.global_position.x - last_prediction_x) > 2.0:

			last_prediction_x = current_box.global_position.x
			prediction_timer = prediction_interval

			prediction_world.create_simulated_block(current_box)

func _process(delta: float) -> void:
	if is_game_over:
		return

	var highest_point = INF

	# Find the highest object that has landed
	for box in get_tree().get_nodes_in_group("Boxes"):
		if box is RigidBody2D and "has_landed" in box and box.has_landed:
			highest_point = min(highest_point, box.global_position.y)

	if highest_point == INF:
		return

	# Only move the camera when the tower gets high enough
	var threshold_y = starting_camera_y - camera_threshold

	if highest_point < threshold_y:
		var new_target = highest_point + camera_threshold

		# Camera can only move upwards
		target_camera_y = min(target_camera_y, new_target)

	# Smooth camera movement
	camera.global_position.y = lerpf(
		camera.global_position.y,
		target_camera_y,
		minf(camera_speed * delta, 1.0)
	)


func spawn_box() -> void:
	if is_game_over or object_scenes.is_empty():
		return

	# Pick a random Tetris block
	var random_scene = object_scenes.pick_random()

	# Create the block
	var new_box = random_scene.instantiate()

	add_child(new_box)
	new_box.global_position = spawn_point.global_position

	current_box = new_box

	# Connect signals
	new_box.box_landed.connect(_on_box_landed)
	new_box.game_over.connect(_on_game_over)
	
	create_ghost()
	
	prediction_world.create_simulated_block(current_box)


func _on_box_landed() -> void:
	await get_tree().create_timer(0.5).timeout

	if not is_game_over:
		spawn_box()




func create_ghost() -> void:
	if is_instance_valid(ghost):
		ghost.free()

	ghost = Node2D.new()
	ghost.name = "Ghost"
	add_child(ghost)

	var original_visuals = current_box.get_node("Visuals")
	var ghost_visuals = original_visuals.duplicate()

	ghost.add_child(ghost_visuals)

	# Preserve the original colour and apply transparency
	ghost.modulate = Color(1, 1, 1, ghost_opacity)
	ghost.z_index = -1

	ghost.global_position = current_box.global_position



func update_ghost() -> void:
	if not is_instance_valid(ghost):
		return

	if not is_instance_valid(current_box):
		return

	if current_box.is_dropped:
		ghost.visible = false
		return

	var space = get_world_2d().direct_space_state
	var motion = Vector2.DOWN * ghost_distance
	var safe_fraction = 1.0

	for child in current_box.get_children():
		if child is CollisionShape2D:
			if child.disabled or child.shape == null:
				continue

			var query = PhysicsShapeQueryParameters2D.new()

			query.shape = child.shape
			query.transform = child.global_transform
			query.motion = motion
			query.collision_mask = current_box.collision_mask
			query.exclude = [current_box.get_rid()]

			var result = space.cast_motion(query)

			if result.size() > 0:
				safe_fraction = minf(safe_fraction, result[0])

	ghost.global_position = current_box.global_position + motion * safe_fraction + Vector2(0, ghost_offset)
	ghost.global_rotation = current_box.global_rotation
	ghost.visible = true
	
func _on_prediction_ready(final_transform: Transform2D) -> void:
	if not is_instance_valid(ghost):
		return

	ghost.global_transform = final_transform
	print("Ghost prediction received!")


func _on_game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	print("GAME OVER!")
