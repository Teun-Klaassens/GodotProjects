
extends Node2D

@export var object_scenes: Array[PackedScene]

@export_category("Camera")
@export var camera_threshold: float = 150.0
@export var camera_speed: float = 3.0

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var camera: Camera2D = $Camera

var current_box: RigidBody2D
var is_game_over = false

var starting_camera_y: float
var target_camera_y: float


func _ready() -> void:
	starting_camera_y = camera.global_position.y
	target_camera_y = starting_camera_y

	spawn_box()


func _process(delta: float) -> void:
	if is_game_over:
		return

	var highest_point = INF

	# Find the highest object that has landed
	for box in get_tree().get_nodes_in_group("Boxes"):
		if box is RigidBody2D and box.has_landed:
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


func _on_box_landed() -> void:
	await get_tree().create_timer(0.5).timeout

	if not is_game_over:
		spawn_box()


func _on_game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	print("GAME OVER!")
