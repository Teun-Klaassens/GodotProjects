extends StaticBody3D
class_name NoteInteractable
## Interactive collectible maintenance clipboard / incident report.
## Highlights when looked at, shows [E] Read Log, plays note_rustle.wav,
## and opens a readable log interface overlay.

@export var title: String = "INCIDENT LOG #14"
@export_multiline var body: String = "WATER DISPLACEMENT REPORT:\n\nHydro-sensors in Sector B have detected massive subsurface displacement. The support pylons are experiencing cyclical shear stress beyond structural tolerance.\n\nEvacuation protocols are locked pending manual override of the three Grid Breakers located along the catwalk perimeter.\n\nDo not look down into the deep end."
@export var prompt_text: String = "[E] Read Incident Log"

var has_read: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("notes")

func get_prompt() -> String:
	return prompt_text

func interact() -> void:
	# Play note rustle sound
	var ha = load("res://SCRIPT/horror_audio.gd")
	if ha:
		ha.play_2d(get_tree(), "note_rustle", 0.0)

	var director = get_tree().get_first_node_in_group("facility_director")
	if director and director.has_method("display_note"):
		director.display_note(title, body)
