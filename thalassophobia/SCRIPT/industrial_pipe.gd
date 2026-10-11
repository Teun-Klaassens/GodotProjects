@tool
extends Node3D

@export var outer_radius: float = 4.5:
	set(v):
		outer_radius = v
		_update_pipe()

@export var inner_radius: float = 3.8:
	set(v):
		inner_radius = v
		_update_pipe()

@export var pipe_height: float = 52.0:
	set(v):
		pipe_height = v
		_update_pipe()

@onready var outer_cyl: CSGCylinder3D = $PipeCSGCombiner/OuterPipe
@onready var inner_cyl: CSGCylinder3D = $PipeCSGCombiner/HollowInner

func _ready() -> void:
	_update_pipe()

func _update_pipe() -> void:
	if outer_cyl and inner_cyl:
		outer_cyl.radius = outer_radius
		outer_cyl.height = pipe_height
		inner_cyl.radius = inner_radius
		inner_cyl.height = pipe_height + 1.0
