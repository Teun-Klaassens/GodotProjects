
extends Node2D

@export var object_scenes: Array[PackedScene]
@export var camera_threshold: float = 40.0
@export var camera_speed: float = 6

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var camera: Camera2D = $Camera
@export var spawn_margin: float = 150.0

@onready var score_label: Label = $HUD/ScoreLabel

var score: int = 0
var current_box: RigidBody2D
var is_game_over := false
var starting_camera_y: float
var target_camera_y: float


func _ready() -> void:
	starting_camera_y = camera.global_position.y
	target_camera_y = starting_camera_y
	update_spawn_point()
	spawn_box()


func _process(delta: float) -> void:
	if is_game_over:
		return

	var highest_point := INF

	for box in get_tree().get_nodes_in_group("Boxes"):
		if box.has_landed:
			highest_point = minf(highest_point, box.global_position.y)

	if highest_point == INF:
		return

	if highest_point < starting_camera_y - camera_threshold:
		target_camera_y = minf(target_camera_y, highest_point + camera_threshold)

	camera.global_position.y = lerpf(
		camera.global_position.y,
		target_camera_y,
		minf(camera_speed * delta, 1.0)
	)

	update_spawn_point()


func spawn_box() -> void:
	if is_game_over or object_scenes.is_empty():
		return

	update_spawn_point()

	current_box = object_scenes.pick_random().instantiate()
	add_child(current_box)
	current_box.global_position = spawn_point.global_position

	current_box.box_landed.connect(_on_box_landed)
	current_box.game_over.connect(_on_game_over)


func _on_box_landed() -> void:
	score += 1
	score_label.text = str(score)

	await get_tree().create_timer(0.5).timeout

	if not is_game_over:
		spawn_box()
		
func update_spawn_point() -> void:
	var viewport_height = get_viewport_rect().size.y / camera.zoom.y
	spawn_point.global_position.y = camera.global_position.y - viewport_height / 2.0 + spawn_margin


func _on_game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	print("GAME OVER!")
