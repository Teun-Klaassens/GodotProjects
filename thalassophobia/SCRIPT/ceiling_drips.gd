extends Node3D

@onready var drip_audio: AudioStreamPlayer3D = $DripAudio

func _ready() -> void:
	if drip_audio and drip_audio.stream:
		# Auto-restart on finished to ensure endless looping
		drip_audio.finished.connect(_on_audio_finished)
		drip_audio.play()

func _on_audio_finished() -> void:
	if drip_audio:
		drip_audio.play()
