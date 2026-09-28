
extends RigidBody2D

signal box_landed
signal game_over

@export_category("Move")
@export var move_speed: float = 300.0

@export_category("Boundaries")
@export var min_x: float = -150.0
@export var max_x: float = 150.0

var is_dropped = false
var has_landed = false


func _ready() -> void:
	freeze = true
	contact_monitor = true
	max_contacts_reported = 8

	add_to_group("Boxes")

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if is_dropped:
		if not has_landed and get_contact_count() > 0:
			has_landed = true
			box_landed.emit()
		return

	var direction = Input.get_axis("left", "right")

	global_position.x += direction * move_speed * delta

	global_position.x = clampf(
		global_position.x,
		min_x,
		max_x
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drop") and not is_dropped:
		drop_box()


func drop_box() -> void:
	is_dropped = true
	freeze = false


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Floor"):
		game_over.emit()
