
extends RigidBody2D

signal simulation_finished_signal(final_transform: Transform2D)

@export var settle_velocity: float = 2.0
@export var settle_angular_velocity: float = 0.1

var simulation_finished: bool = false
var settled_frames: int = 0


func _physics_process(_delta: float) -> void:
	if simulation_finished:
		return

	if linear_velocity.length() < settle_velocity \
	and absf(angular_velocity) < settle_angular_velocity:

		settled_frames += 1
	else:
		settled_frames = 0

	if settled_frames >= 30:
		simulation_finished = true

		print("Simulation finished!")
		print("Final position: ", global_position)
		print("Final rotation: ", global_rotation_degrees)

		simulation_finished_signal.emit(global_transform)
