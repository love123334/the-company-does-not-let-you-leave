extends Node

var _audio_players: Array[AudioStreamPlayer] = []
var _siren_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer

var snd_step: AudioStreamWAV
var snd_mop: AudioStreamWAV
var snd_scrub: AudioStreamWAV
var snd_swing: AudioStreamWAV
var snd_alarm: AudioStreamWAV
var snd_screech: AudioStreamWAV
var snd_growl: AudioStreamWAV
var snd_click: AudioStreamWAV
var snd_stone: AudioStreamWAV
var snd_pickup: AudioStreamWAV
var snd_shatter: AudioStreamWAV
var snd_whisper: AudioStreamWAV
var snd_breath_gasp: AudioStreamWAV
var snd_cloth_wrap: AudioStreamWAV
var snd_metal_drag: AudioStreamWAV

var snd_ambient_work: AudioStreamWAV
var snd_ambient_chase: AudioStreamWAV
var snd_ambient_cutscene: AudioStreamWAV

var music_volume_multiplier: float = 1.0
var sfx_volume_multiplier: float = 1.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _generate_all_clean_sounds()
    
    for i in range(16):
        var p = AudioStreamPlayer.new()
        add_child(p)
        _audio_players.append(p)
        
    _siren_player = AudioStreamPlayer.new()
    _siren_player.stream = _create_clean_siren()
    _siren_player.volume_db = -8.0
    add_child(_siren_player)
    
    _music_player = AudioStreamPlayer.new()
    _music_player.volume_db = -6.0
    add_child(_music_player)

func _generate_all_clean_sounds() -> void:
    snd_step = _create_smooth_tone(110.0, 45.0, 0.09, 0.3)
    snd_mop = _create_smooth_tone(180.0, 80.0, 0.15, 0.4)
    snd_scrub = _create_smooth_tone(220.0, 110.0, 0.08, 0.45)
    snd_swing = _create_smooth_tone(350.0, 150.0, 0.12, 0.35)
    snd_alarm = _create_smooth_tone(450.0, 750.0, 0.4, 0.45)
    snd_screech = _create_smooth_tone(850.0, 200.0, 0.5, 0.6)
    snd_growl = _create_smooth_tone(90.0, 40.0, 0.8, 0.5)
    snd_click = _create_smooth_tone(1200.0, 800.0, 0.04, 0.25)
    snd_stone = _create_smooth_tone(70.0, 50.0, 0.5, 0.35)
    snd_pickup = _create_smooth_tone(523.0, 1046.0, 0.18, 0.4)
    snd_shatter = _create_smooth_tone(900.0, 150.0, 0.4, 0.6)
    snd_whisper = _create_breath_or_cloth_wav(260.0, 140.0, 0.55, 0.38, 0.55)
    snd_breath_gasp = _create_breath_or_cloth_wav(340.0, 190.0, 0.28, 0.48, 0.65)
    snd_cloth_wrap = _create_breath_or_cloth_wav(180.0, 95.0, 0.36, 0.52, 0.70)
    snd_metal_drag = _create_heavy_metal_drag_wav()
    
    snd_ambient_work = _create_work_ambient()
    snd_ambient_chase = _create_chase_ambient()
    snd_ambient_cutscene = _create_cutscene_ambient()

func play(stream: AudioStreamWAV, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
    if stream == null: return
    var final_db = volume_db + linear_to_db(max(0.01, sfx_volume_multiplier))
    for p in _audio_players:
        if not p.playing:
            p.stream = stream
            p.volume_db = final_db
            p.pitch_scale = pitch_scale
            p.play()
            return
    var p = _audio_players[0]
    p.stream = stream
    p.volume_db = final_db
    p.pitch_scale = pitch_scale
    p.play()

func start_ambient_music() -> void:
    if _music_player.stream != snd_ambient_work or not _music_player.playing:
        _music_player.stream = snd_ambient_work
        _music_player.volume_db = -6.0 + linear_to_db(max(0.01, music_volume_multiplier))
        _music_player.play()

func start_chase_music() -> void:
    if _music_player.stream != snd_ambient_chase or not _music_player.playing:
        _music_player.stream = snd_ambient_chase
        _music_player.volume_db = -4.0 + linear_to_db(max(0.01, music_volume_multiplier))
        _music_player.play()

func start_cutscene_music() -> void:
    if _music_player.stream != snd_ambient_cutscene or not _music_player.playing:
        _music_player.stream = snd_ambient_cutscene
        _music_player.volume_db = -6.0 + linear_to_db(max(0.01, music_volume_multiplier))
        _music_player.play()

func stop_music() -> void:
    if _music_player.playing:
        _music_player.stop()

func start_siren() -> void:
    if not _siren_player.playing:
        _siren_player.play()

func stop_siren() -> void:
    if _siren_player.playing:
        _siren_player.stop()

func set_music_volume(v: float) -> void:
    music_volume_multiplier = clamp(v, 0.0, 1.5)
    _music_player.volume_db = -6.0 + linear_to_db(max(0.01, music_volume_multiplier))

func set_sfx_volume(v: float) -> void:
    sfx_volume_multiplier = clamp(v, 0.0, 1.5)
    _siren_player.volume_db = -8.0 + linear_to_db(max(0.01, sfx_volume_multiplier))

func play_crawler_skitter() -> void:
    play(snd_click, -10.0, randf_range(1.3, 1.75))

func play_Wet_Squish() -> void:
    play(snd_mop, -1.0, randf_range(0.75, 0.95))

func play_cultist_chant() -> void:
    play(snd_growl, -4.0, randf_range(0.85, 1.1))

func play_stone_grind() -> void:
    play(snd_metal_drag, -2.0, randf_range(0.9, 1.1))

func play_stone_drag(volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
    play(snd_metal_drag, volume_db, pitch_scale)

func play_metal_drag(volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
    play_stone_drag(volume_db, pitch_scale)

func play_hunter_screech() -> void:
    play(snd_screech, 2.0, randf_range(0.92, 1.08))

func play_heavy_step() -> void:
    play(snd_step, -2.0, randf_range(0.55, 0.7))

func play_heartbeat() -> void:
    play(snd_step, -4.0, 0.48)

func play_breath_gasp(intensity: float = 0.5) -> void:
    var vol: float = lerpf(-7.0, 2.5, clampf(intensity, 0.0, 1.0))
    var pitch: float = lerpf(0.92, 1.38, clampf(intensity, 0.0, 1.0)) + randf_range(-0.05, 0.05)
    play(snd_breath_gasp, vol, pitch)

func play_cloth_wrap() -> void:
    play(snd_cloth_wrap, 2.5, randf_range(0.88, 1.12))

func _create_breath_or_cloth_wav(f_start: float, f_end: float, dur: float, vol: float, noise_mix: float) -> AudioStreamWAV:
    var rate: int = 22050
    var samples: int = int(dur * float(rate))
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)
    var phase: float = 0.0
    var lp: float = 0.0
    for i in range(samples):
        var t: float = float(i) / float(samples)
        var freq: float = lerpf(f_start, f_end, t)
        phase += (freq * TAU) / float(rate)
        if phase > TAU:
            phase -= TAU
        var env: float = sin(t * PI)
        var raw_noise: float = (randf() * 2.0 - 1.0)
        lp = lerpf(lp, raw_noise, 0.18)
        var sig: float = sin(phase) * (1.0 - noise_mix) + lp * noise_mix
        var val: float = sig * env * vol
        var s16: int = int(clamp(val * 32767.0, -32768.0, 32767.0))
        var u16: int = s16 if s16 >= 0 else s16 + 65536
        bytes[i * 2] = u16 & 0xFF
        bytes[i * 2 + 1] = (u16 >> 8) & 0xFF
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.data = bytes
    return wav

func _create_smooth_tone(f_start: float, f_end: float, dur: float, vol: float) -> AudioStreamWAV:
    var rate: int = 22050
    var samples: int = int(dur * float(rate))
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)
    
    var phase: float = 0.0
    for i in range(samples):
        var t: float = float(i) / float(samples)
        var freq: float = lerp(f_start, f_end, t)
        phase += (freq * TAU) / float(rate)
        if phase > TAU: phase -= TAU
        
        var env: float = 1.0
        if t < 0.1: env = t / 0.1
        elif t > 0.8: env = (1.0 - t) / 0.2
        
        var val: float = sin(phase) * env * vol
        var s16: int = int(clamp(val * 32767.0, -32768.0, 32767.0))
        var u16: int = s16 if s16 >= 0 else s16 + 65536
        bytes[i * 2] = u16 & 0xFF
        bytes[i * 2 + 1] = (u16 >> 8) & 0xFF
        
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.data = bytes
    return wav

# HTML Work Drone (Sub-bass notes 55, 58, 52, 62 + tremolo + subtle crackle)
func _create_work_ambient() -> AudioStreamWAV:
    var rate: int = 22050
    var dur: float = 10.0
    var samples: int = int(dur * float(rate))
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)
    
    var notes: Array[float] = [55.0, 58.0, 52.0, 62.0]
    var phase1: float = 0.0
    var phase2: float = 0.0
    
    for i in range(samples):
        var t: float = float(i) / float(samples)
        var note_idx: int = int(t * 4.0) % 4
        var base_freq: float = notes[note_idx]
        
        phase1 += (base_freq * TAU) / float(rate)
        if phase1 > TAU: phase1 -= TAU
        phase2 += (base_freq * 2.0 * TAU) / float(rate)
        if phase2 > TAU: phase2 -= TAU
        
        # Smooth amplitude modulation
        var lfo: float = 0.75 + 0.25 * sin(t * TAU * 3.0)
        var crackle: float = (randf() * 2.0 - 1.0) * 0.03 if (i % 230 == 0) else 0.0
        var val: float = (sin(phase1) * 0.45 + sin(phase2) * 0.12 + crackle) * lfo
        
        var s16: int = int(clamp(val * 32767.0, -32768.0, 32767.0))
        var u16: int = s16 if s16 >= 0 else s16 + 65536
        bytes[i * 2] = u16 & 0xFF
        bytes[i * 2 + 1] = (u16 >> 8) & 0xFF
        
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wav.loop_begin = 0
    wav.loop_end = samples
    wav.data = bytes
    return wav

# HTML Chase Drone (40Hz low rumble + tense sawtooth cluster 120, 127, 134 + 7Hz tremolo)
func _create_chase_ambient() -> AudioStreamWAV:
    var rate: int = 22050
    var dur: float = 4.8
    var samples: int = int(dur * float(rate))
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)
    
    var phase_rumble: float = 0.0
    var phase_c1: float = 0.0
    var phase_c2: float = 0.0
    var phase_c3: float = 0.0
    
    for i in range(samples):
        var t: float = float(i) / float(samples)
        phase_rumble += (40.0 * TAU) / float(rate)
        if phase_rumble > TAU: phase_rumble -= TAU
        
        phase_c1 += (120.0 * TAU) / float(rate)
        if phase_c1 > TAU: phase_c1 -= TAU
        phase_c2 += (127.0 * TAU) / float(rate)
        if phase_c2 > TAU: phase_c2 -= TAU
        phase_c3 += (134.0 * TAU) / float(rate)
        if phase_c3 > TAU: phase_c3 -= TAU
        
        var tremolo: float = 0.6 + 0.4 * sin(t * TAU * 7.5)
        var saw1: float = (phase_c1 / PI) - 1.0
        var saw2: float = (phase_c2 / PI) - 1.0
        var saw3: float = (phase_c3 / PI) - 1.0
        
        # Pulse hits every 1.2s
        var pulse_t: float = fmod(t * 4.0, 1.0)
        var hit_env: float = exp(-pulse_t * 3.5)
        
        var val: float = (sin(phase_rumble) * 0.4) + ((saw1 + saw2 + saw3) * 0.15 * tremolo * hit_env)
        var s16: int = int(clamp(val * 32767.0, -32768.0, 32767.0))
        var u16: int = s16 if s16 >= 0 else s16 + 65536
        bytes[i * 2] = u16 & 0xFF
        bytes[i * 2 + 1] = (u16 >> 8) & 0xFF
        
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wav.loop_begin = 0
    wav.loop_end = samples
    wav.data = bytes
    return wav

# Cutscene Ambience (Filtered rain noise + distant resonant thunder)
func _create_cutscene_ambient() -> AudioStreamWAV:
    var rate: int = 22050
    var dur: float = 8.0
    var samples: int = int(dur * float(rate))
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)
    
    var thunder_phase: float = 0.0
    var last_noise: float = 0.0
    
    for i in range(samples):
        var t: float = float(i) / float(samples)
        # Soft low-pass filtered rain
        var raw_white: float = randf() * 2.0 - 1.0
        last_noise = lerp(last_noise, raw_white, 0.12)
        var rain: float = last_noise * 0.18
        
        # Distant thunder rumble
        thunder_phase += (38.0 * TAU) / float(rate)
        if thunder_phase > TAU: thunder_phase -= TAU
        var thunder_env: float = max(0.0, sin(t * TAU * 1.5)) * exp(-fmod(t * 3.0, 1.0) * 2.5) * 0.35
        var val: float = rain + sin(thunder_phase) * thunder_env
        
        var s16: int = int(clamp(val * 32767.0, -32768.0, 32767.0))
        var u16: int = s16 if s16 >= 0 else s16 + 65536
        bytes[i * 2] = u16 & 0xFF
        bytes[i * 2 + 1] = (u16 >> 8) & 0xFF
        
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wav.loop_begin = 0
    wav.loop_end = samples
    wav.data = bytes
    return wav

func _create_clean_siren() -> AudioStreamWAV:
    var rate: int = 22050
    var dur: float = 2.4
    var samples: int = int(dur * float(rate))
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)
    
    var phase: float = 0.0
    for i in range(samples):
        var t: float = float(i) / float(samples)
        var freq: float = 460.0 + sin(t * TAU) * 220.0
        phase += (freq * TAU) / float(rate)
        if phase > TAU: phase -= TAU
        var val: float = sin(phase) * 0.4
        var s16: int = int(clamp(val * 32767.0, -32768.0, 32767.0))
        var u16: int = s16 if s16 >= 0 else s16 + 65536
        bytes[i * 2] = u16 & 0xFF
        bytes[i * 2 + 1] = (u16 >> 8) & 0xFF
        
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wav.loop_begin = 0
    wav.loop_end = samples
    wav.data = bytes
    return wav

# Heavy solid stone sliding, grinding and crushing across concrete floor (pure natural stone friction)
func _create_heavy_metal_drag_wav() -> AudioStreamWAV:
    var rate: int = 22050
    var dur: float = 1.05
    var samples: int = int(dur * float(rate))
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)

    var p_sub: float = 0.0
    var lp_grit1: float = 0.0
    var lp_grit2: float = 0.0
    var lp_grit3: float = 0.0

    for i in range(samples):
        var t: float = float(i) / float(samples)

        # 1. Pure subterranean low bass weight rumble (36Hz -> 30Hz slow drift)
        var f_sub: float = lerpf(38.0, 31.0, t)
        p_sub += (f_sub * TAU) / float(rate)
        var sub_bass: float = sin(p_sub) * 0.45

        # 2. Heavy rough stone granule friction (pure multi-pole low-pass filtered brown noise, cutoff ~260Hz)
        # Completely devoid of harsh saws, FM tones, metallic ring, or rapid buzzing
        var white: float = randf() * 2.0 - 1.0
        lp_grit1 = lerpf(lp_grit1, white, 0.055)
        lp_grit2 = lerpf(lp_grit2, lp_grit1, 0.075)
        lp_grit3 = lerpf(lp_grit3, lp_grit2, 0.09)

        # Subtle organic stone drag roughness (slow randomized micro-shifts)
        var stone_grind: float = lp_grit3 * 3.4

        # 3. Natural physical envelope: gradual heavy shove, sustained heavy drag, slow heavy rest
        var env: float = 1.0
        if t < 0.18:
            env = t / 0.18
        elif t > 0.65:
            env = max(0.0, (1.0 - t) / 0.35)

        var val: float = (sub_bass + stone_grind) * env * 0.78
        var s16: int = int(clamp(val * 32767.0, -32768.0, 32767.0))
        var u16: int = s16 if s16 >= 0 else s16 + 65536
        bytes[i * 2] = u16 & 0xFF
        bytes[i * 2 + 1] = (u16 >> 8) & 0xFF

    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.data = bytes
    return wav
