@tool
extends Node3D

@export_group("Chamber Dimensions")
@export var chamber_width: float = 80.0
@export var chamber_length: float = 150.0
@export var chamber_height: float = 35.0
@export var wall_thickness: float = 2.0

@export_group("Walkway")
@export var walkway_width: float = 2.0
@export var walkway_length: float = 100.0
@export var walkway_height: float = 1.0

@export_group("Generation Actions")
@export var generate: bool = false:
	set(value):
		if value:
			generate = false
			generate_chamber()

@export var clear: bool = false:
	set(value):
		if value:
			clear = false
			clear_chamber()


func _get_scene_root() -> Node:
	if Engine.is_editor_hint():
		var tree := get_tree()
		if tree and tree.edited_scene_root:
			return tree.edited_scene_root
	if owner != null:
		return owner
	return self


func clear_chamber() -> void:
	# Only delete generated CSGBox3D geometry so user nodes aren't removed
	var children_to_remove: Array[Node] = []
	for child in get_children():
		if child is CSGBox3D:
			children_to_remove.append(child)

	for child in children_to_remove:
		remove_child(child)
		child.free()

	print("Chamber geometry cleared.")


func generate_chamber() -> void:
	if not Engine.is_editor_hint():
		print("generate_chamber() skipped outside of the editor.")
		return

	print("Generating chamber...")
	clear_chamber()

	var scene_root := _get_scene_root()

	# Floor (centered at y = -20)
	create_box(
		"Floor",
		Vector3(0, -20.0, 0),
		Vector3(chamber_width, 2.0, chamber_length),
		scene_root
	)

	# Left wall (x = -chamber_width / 2)
	create_box(
		"LeftWall",
		Vector3(-chamber_width / 2.0, 0, 0),
		Vector3(wall_thickness, chamber_height, chamber_length),
		scene_root
	)

	# Right wall (x = chamber_width / 2)
	create_box(
		"RightWall",
		Vector3(chamber_width / 2.0, 0, 0),
		Vector3(wall_thickness, chamber_height, chamber_length),
		scene_root
	)

	# Back wall (z = -chamber_length / 2)
	create_box(
		"BackWall",
		Vector3(0, 0, -chamber_length / 2.0),
		Vector3(chamber_width, chamber_height, wall_thickness),
		scene_root
	)

	# Front wall (z = chamber_length / 2)
	create_box(
		"FrontWall",
		Vector3(0, 0, chamber_length / 2.0),
		Vector3(chamber_width, chamber_height, wall_thickness),
		scene_root
	)

	# Ceiling (y = chamber_height / 2)
	create_box(
		"Ceiling",
		Vector3(0, chamber_height / 2.0, 0),
		Vector3(chamber_width, 2.0, chamber_length),
		scene_root
	)

	# Narrow walkway (centered at y = walkway_height)
	create_box(
		"Walkway",
		Vector3(0, walkway_height, 0),
		Vector3(walkway_width, 0.5, walkway_length),
		scene_root
	)

	print("Chamber generated successfully! (Owner: ", scene_root.name, ")")


func create_box(
	box_name: String,
	box_position: Vector3,
	box_size: Vector3,
	scene_root: Node
) -> void:
	var box := CSGBox3D.new()
	box.name = box_name
	box.position = box_position
	box.size = box_size
	box.use_collision = true

	add_child(box)

	# Assign owner to the scene root so Godot persists it in the Scene tree dock
	if scene_root:
		box.owner = scene_root
