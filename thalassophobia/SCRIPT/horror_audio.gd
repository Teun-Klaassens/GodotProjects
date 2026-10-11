extends Node
## Central audio manager for sound effects and horror triggers.
## Autoloaded or accessed via AudioStreamPlayer pools.

const SFX := {
	#"door_creak": preload("res://SOUND/door_creak.wav"),
	"door_locked": preload("res://SOUND/door_locked.wav"),
	"enemy_growl": preload("res://SOUND/enemy_growl.wav"),
	"enemy_step": preload("res://SOUND/enemy_step.wav"),
	"escape_sting": preload("res://SOUND/escape_sting.wav"),
	"flicker": preload("res://SOUND/flicker.wav"),
	"heartbeat": preload("res://SOUND/heartbeat.wav"),
	"jumpscare": preload("res://SOUND/jumpscare.wav"),
	"note_rustle": preload("res://SOUND/note_rustle.wav"),
	"pickup": preload("res://SOUND/pickup.wav"),
	"blip": preload("res://SOUND/blip.wav"),
}

static func play_2d(tree: SceneTree, sound_key: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not SFX.has(sound_key):
		push_warning("Sound not found in HorrorAudio: " + sound_key)
		return null
	var stream: AudioStream = SFX[sound_key]
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	var root := tree.current_scene if tree else null
	if root:
		root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player

static func play_3d(parent: Node, sound_key: String, pos: Vector3, volume_db: float = 0.0, max_dist: float = 60.0) -> AudioStreamPlayer3D:
	if not SFX.has(sound_key):
		push_warning("Sound not found in HorrorAudio: " + sound_key)
		return null
	var stream: AudioStream = SFX[sound_key]
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 15.0
	player.max_distance = max_dist
	var host: Node = parent if parent else (parent.get_tree().current_scene if parent and parent.get_tree() else null)
	if host:
		host.add_child(player)
	player.global_position = pos
	player.finished.connect(player.queue_free)
	player.play()
	return player
