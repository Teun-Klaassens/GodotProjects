extends AudioStreamPlayer3D

# Procedural heavy crashing subterranean water wave audio
var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0
var phase_sub: float = 0.0
var phase_mid: float = 0.0
var wave_timer: float = 0.0
var crash_envelope: float = 0.0

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.2
	stream = gen
	play()
	playback = get_stream_playback() as AudioStreamGeneratorPlayback

func _process(delta: float) -> void:
	if playback == null:
		return

	var frames_available := playback.get_frames_available()
	for i in range(frames_available):
		# Wave crash cycle every ~3.2 seconds
		wave_timer += 1.0 / sample_rate
		if wave_timer >= 3.2:
			wave_timer -= 3.2
			crash_envelope = 1.0 # Trigger a wave break/crash impact

		# Decay crash impact
		crash_envelope = max(0.0, crash_envelope - (1.2 / sample_rate))

		# Continuous subterranean deep swells (38Hz and 75Hz)
		phase_sub += 38.0 / sample_rate
		phase_mid += 75.0 / sample_rate
		var sub := sin(phase_sub * TAU) * 0.45
		var mid := sin(phase_mid * TAU) * 0.25

		# Wave swell modulation
		var swell := (sin(wave_timer * (TAU / 3.2)) * 0.5 + 0.5) * 0.35 + 0.15

		# Crashing foam/spray filtered noise
		var white_noise := (randf() * 2.0 - 1.0)
		var crash_sound := white_noise * crash_envelope * 0.55
		var continuous_wash := white_noise * swell * 0.18

		var final_sample := (sub + mid + crash_sound + continuous_wash) * 0.5
		playback.push_frame(Vector2(final_sample, final_sample))
