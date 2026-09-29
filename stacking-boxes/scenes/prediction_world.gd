
extends SubViewport

signal prediction_ready(final_transform: Transform2D)

@onready var simulated_blocks: Node2D = $SimulatedBlocks

var simulation_script = preload("res://scripts/simulation_block.gd")
var prediction_id: int = 0


func _ready() -> void:
	world_2d = World2D.new()


func create_simulated_block(original: RigidBody2D) -> void:
	var simulated = original.duplicate()
	simulated.remove_from_group("Boxes")

	# Remove gameplay behaviour
	simulated.set_script(simulation_script)

	# Reset physics state
	simulated.freeze = false
	simulated.linear_velocity = Vector2.ZERO
	simulated.angular_velocity = 0.0

	simulated_blocks.add_child(simulated)

	simulated.simulation_finished_signal.connect(_on_simulation_finished)
	
	simulated.global_position = original.global_position
	simulated.global_rotation = original.global_rotation

	print("Simulated block created!")


func _on_simulation_finished(final_transform: Transform2D) -> void:
	prediction_ready.emit(final_transform)
