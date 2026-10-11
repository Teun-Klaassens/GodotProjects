@tool
extends EditorScript

# Usage in Godot Editor:
# 1. Open the scene you want to build into (e.g. main.tscn or the_reservoir.tscn).
# 2. In Godot's Script Editor, open this script (build_chamber.gd).
# 3. Press Ctrl+Shift+X (or File -> Run).
# 4. The chamber geometry will be created instantly under the 'Chamber' node.
# 5. Press Ctrl+S to save the scene.

func _run() -> void:
	var scene_root := get_scene()
	if scene_root == null:
		printerr("[BuildChamber] No active scene is open in the editor. Open your scene first!")
		return

	var chamber: Node3D = null
	if scene_root.name == "Chamber":
		chamber = scene_root as Node3D
	else:
		chamber = scene_root.find_child("Chamber", true, false) as Node3D

	if chamber == null:
		printerr("[BuildChamber] No 'Chamber' node found in the active scene '", scene_root.name, "'.")
		return

	print("[BuildChamber] Building chamber in scene '", scene_root.name, "'...")

	# Clear previously generated CSG boxes
	var children_to_remove: Array[Node] = []
	for child in chamber.get_children():
		if child is CSGBox3D:
			children_to_remove.append(child)

	for child in children_to_remove:
		chamber.remove_child(child)
		child.free()

	# Chamber Dimensions
	var chamber_width: float = 80.0
	var chamber_length: float = 150.0
	var chamber_height: float = 35.0
	var wall_thickness: float = 2.0

	# Walkway Dimensions
	var walkway_width: float = 2.0
	var walkway_length: float = 100.0
	var walkway_height: float = 1.0

	_create_box(chamber, scene_root, "Floor", Vector3(0, -20.0, 0), Vector3(chamber_width, 2.0, chamber_length))
	_create_box(chamber, scene_root, "LeftWall", Vector3(-chamber_width / 2.0, 0, 0), Vector3(wall_thickness, chamber_height, chamber_length))
	_create_box(chamber, scene_root, "RightWall", Vector3(chamber_width / 2.0, 0, 0), Vector3(wall_thickness, chamber_height, chamber_length))
	_create_box(chamber, scene_root, "BackWall", Vector3(0, 0, -chamber_length / 2.0), Vector3(chamber_width, chamber_height, wall_thickness))
	_create_box(chamber, scene_root, "FrontWall", Vector3(0, 0, chamber_length / 2.0), Vector3(chamber_width, chamber_height, wall_thickness))
	_create_box(chamber, scene_root, "Ceiling", Vector3(0, chamber_height / 2.0, 0), Vector3(chamber_width, 2.0, chamber_length))
	_create_box(chamber, scene_root, "Walkway", Vector3(0, walkway_height, 0), Vector3(walkway_width, 0.5, walkway_length))

	print("[BuildChamber] Chamber built successfully with 7 CSG nodes! Remember to press Ctrl+S to save.")


func _create_box(parent: Node3D, scene_root: Node, box_name: String, box_position: Vector3, box_size: Vector3) -> void:
	var box := CSGBox3D.new()
	box.name = box_name
	box.position = box_position
	box.size = box_size
	box.use_collision = true
	parent.add_child(box)
	box.owner = scene_root
