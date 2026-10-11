extends AudioStreamPlayer3D

var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0

var groan_timer: float = 0.0
var next_groan: float = 12.0
var groan_active: bool = false
var groan_time: float = 0.0

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.3
	stream = gen
	unit_size = 35.0
	max_distance = 300.0
	volume_db = -4.0
	play()
	playback = get_stream_playback() as AudioStreamGeneratorPlayback
	next_groan = randf_range(8.0, 18.0)

func _physics_process(delta: float) -> void:
	groan_timer += delta
	if not groan_active and groan_timer >= next_groan:
		groan_timer = 0.0
		next_groan = randf_range(14.0, 26.0)
		groan_active = true
		groan_time = 0.0

	if groan_active:
		groan_time += delta
		if groan_time >= 3.5:
			groan_active = false

func _process(_delta: float) -> void:
	if playback == null:
		return

	var frames := playback.get_frames_available()
	for i in range(frames):
		# Continuous deep distant rushing water rush inside pipe
		var rush := (randf() * 2.0 - 1.0) * 0.04

		# Periodic metallic stress groan / creak
		var groan := 0.0
		if groan_active:
			var progress := groan_time / 3.5
			var env := sin(progress * PI)
			var freq := 85.0 + sin(groan_time * 6.0) * 15.0
			groan = sin(groan_time * freq * TAU) * env * 0.22

		var s := rush + groan
		playback.push_frame(Vector2(s, s))
