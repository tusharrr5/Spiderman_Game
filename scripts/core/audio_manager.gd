extends Node
## Autoload "Audio": looping music with crossfades and a small pooled SFX player set.

const SFX_POOL_SIZE: int = 10

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current_music: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for p in [_music_a, _music_b]:
		p.bus = "Master"
		p.volume_db = -80.0
		add_child(p)
	_active = _music_a
	for i in range(SFX_POOL_SIZE):
		var s := AudioStreamPlayer.new()
		add_child(s)
		_pool.append(s)


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	_cache[path] = st
	return st


func _linear_db(v: float) -> float:
	return linear_to_db(maxf(0.0001, v))


## Plays a looping music track (res://assets/music/<name>.wav). Same track keeps playing.
func play_music(name: String, fade: float = 0.8, looped: bool = true) -> void:
	if name == _current_music and _active.playing:
		return
	_current_music = name
	var path := "res://assets/music/%s.wav" % name
	var st := _load(path)
	if st == null:
		return
	if st is AudioStreamWAV:
		var wav := st as AudioStreamWAV
		if looped:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() / 2
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var old := _active
	_active = _music_b if _active == _music_a else _music_a
	_active.stream = st
	_active.volume_db = -40.0
	_active.play()
	var target := _linear_db(GameState.music_volume * 0.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_active, "volume_db", target, fade)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.chain().tween_callback(old.stop)


func stop_music(fade: float = 0.6) -> void:
	_current_music = ""
	var p := _active
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.stop)


func refresh_volumes() -> void:
	if _active.playing:
		_active.volume_db = _linear_db(GameState.music_volume * 0.7)


## Plays a one-shot effect. `name` is a file in res://assets/audio without extension, or a full path.
func play_sfx(name: String, volume: float = 1.0, pitch_jitter: float = 0.06) -> void:
	var path := name if name.begins_with("res://") else "res://assets/audio/%s.wav" % name
	var st := _load(path)
	if st == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.stream = st
	p.volume_db = _linear_db(GameState.sfx_volume * volume)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
