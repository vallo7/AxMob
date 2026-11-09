extends Node
## Moteur audio du jeu (autoload « AudioManager »).
##
## Mixage professionnel en quelques idées simples :
##  - BUSES : Music / SFX / UI / Ambience -> Master. SFX = compresseur doux + air (réverb légère) ;
##    5 sous-bus de panoramique (SFX gauche..droite) : un son se place dans le champ stéréo selon sa
##    position dans l'arène, sans lecteur 3D coûteux. Master = limiteur dur (jamais de saturation).
##  - POLYPHONIE : pool de voix fixe ; chaque son a un délai minimal, un nombre max d'instances
##    et une priorité ; à saturation on coupe la voix la moins importante (jamais l'alerte de
##    dégâts).
##  - VARIATION : rotation sans répétition des variantes + variation aléatoire de hauteur/volume.
##  - MUSIQUE ADAPTATIVE : trois couches synchronisées (rythme / harmonie / mélodie) dans un
##    AudioStreamSynchronized ; le jeu les fait entrer selon l'action. Fondu enchaîné entre
##    morceaux.
##  - DUCKING : la musique s'efface brièvement sous les gros impacts ; filtre passe-bas en pause.
## Le son ne bloque jamais le jeu : aucun fichier manquant ne provoque d'erreur (le son est ignoré).

const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const BUS_AMB: StringName = &"Ambience"
const PAN_BUSES: Array[StringName] = [
	&"SfxPanL2", &"SfxPanL1", &"SfxPanC", &"SfxPanR1", &"SfxPanR2"
]
const PAN_VALUES: Array[float] = [-0.85, -0.42, 0.0, 0.42, 0.85]
const VOICE_COUNT: int = 24
## Hors de l'arène : pas de position (son centré, sans atténuation).
const NO_POS: Vector2 = Vector2(1.0e9, 1.0e9)
const SOUND_LABELS: Array[String] = ["MUSIQUE + EFFETS", "EFFETS SEULS", "SILENCE"]
const MUSIC_BASE_DB: float = -3.0
const AMB_DB: float = -5.0
## Portée du panoramique (m) et atténuation maximale avec la distance au joueur.
const PAN_RANGE: float = 12.0
const FAR_START: float = 7.0
const FAR_END: float = 26.0
const FAR_ATTEN_DB: float = 7.0
const STEM_RATE: float = 1.6
const DUCK_RECOVER_DB_PER_S: float = 9.0

const MUSIC_TRACKS: Dictionary = {
	&"menu": ["res://assets/audio/music/menu.ogg"],
	&"run":
	[
		"res://assets/audio/music/run_a.ogg",
		"res://assets/audio/music/run_b.ogg",
		"res://assets/audio/music/run_c.ogg",
	],
	&"boss":
	[
		"res://assets/audio/music/boss_a.ogg",
		"res://assets/audio/music/boss_b.ogg",
		"res://assets/audio/music/boss_c.ogg",
	],
}
const AMBIENCE_PATH: String = "res://assets/audio/amb/beach.ogg"

var sound_mode: int = 0
## Diagnostic : sons joués / refusés (délai, saturation) depuis le lancement.
var played: int = 0
var refused: int = 0

var _bank: Dictionary = {}
var _last_play: Dictionary = {}
var _last_variant: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_name: PackedStringArray = PackedStringArray()
var _voice_prio: PackedInt32Array = PackedInt32Array()
var _voice_start: PackedFloat64Array = PackedFloat64Array()
var _voice_limit: int = VOICE_COUNT
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _music_players: Array[AudioStreamPlayer] = []
var _music_slot: int = 0
var _music_kind: StringName = &""
var _music_streams: Dictionary = {}
var _layer_target: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0])
var _layer_value: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0])
var _amb: AudioStreamPlayer
var _duck_db: float = 0.0
var _muffled: bool = false
var _lowpass: AudioEffectLowPassFilter
var _music_volume: float = 1.0
var _sfx_volume: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 424242
	sound_mode = UserSettings.sound_mode()
	_build_buses()
	_build_voices()
	_build_music_players()
	_apply_mix()
	EventBus.quality_changed.connect(func(_t: int) -> void: _apply_quality())
	_apply_quality()


func _exit_tree() -> void:
	shutdown()


## Arrête tout (voix, musique, ambiance) : appelé à la fermeture pour libérer proprement les flux.
func shutdown() -> void:
	stop_all()
	for p: AudioStreamPlayer in _music_players:
		p.stop()
		p.stream = null
	_amb.stop()
	_amb.stream = null
	for v: AudioStreamPlayer in _voices:
		v.stream = null
	_bank.clear()
	_music_streams.clear()


func _process(delta: float) -> void:
	_update_layers(delta)
	# Le ducking récupère doucement ; le volume de musique suit.
	if _duck_db < 0.0:
		_duck_db = minf(_duck_db + DUCK_RECOVER_DB_PER_S * delta, 0.0)
	_apply_music_volume()


# --- Construction des bus ---------------------------------------------------------------------


func _build_buses() -> void:
	_ensure_bus(BUS_MUSIC, &"Master")
	_ensure_bus(BUS_SFX, &"Master")
	_ensure_bus(BUS_UI, &"Master")
	_ensure_bus(BUS_AMB, &"Master")
	var master: int = AudioServer.get_bus_index(&"Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.8
		limiter.pre_gain_db = 0.0
		limiter.release = 0.1
		AudioServer.add_bus_effect(master, limiter)
	var sfx: int = AudioServer.get_bus_index(BUS_SFX)
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var comp: AudioEffectCompressor = AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		comp.attack_us = 5000.0
		comp.release_ms = 140.0
		comp.gain = 2.0
		AudioServer.add_bus_effect(sfx, comp)
		var air: AudioEffectReverb = AudioEffectReverb.new()
		air.room_size = 0.35
		air.damping = 0.7
		air.wet = 0.08
		air.dry = 1.0
		AudioServer.add_bus_effect(sfx, air)
	var music: int = AudioServer.get_bus_index(BUS_MUSIC)
	if AudioServer.get_bus_effect_count(music) == 0:
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(music, _lowpass)
	else:
		_lowpass = AudioServer.get_bus_effect(music, 0) as AudioEffectLowPassFilter
	for i: int in PAN_BUSES.size():
		_ensure_bus(PAN_BUSES[i], BUS_SFX)
		var idx: int = AudioServer.get_bus_index(PAN_BUSES[i])
		if AudioServer.get_bus_effect_count(idx) == 0:
			var panner: AudioEffectPanner = AudioEffectPanner.new()
			panner.pan = PAN_VALUES[i]
			AudioServer.add_bus_effect(idx, panner)


func _ensure_bus(bus_name: StringName, send: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)


func _build_voices() -> void:
	for i: int in VOICE_COUNT:
		var v: AudioStreamPlayer = AudioStreamPlayer.new()
		v.bus = BUS_SFX
		v.finished.connect(_on_voice_finished.bind(i))
		add_child(v)
		_voices.append(v)
	_voice_name.resize(VOICE_COUNT)
	_voice_prio.resize(VOICE_COUNT)
	_voice_start.resize(VOICE_COUNT)


func _build_music_players() -> void:
	for i: int in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = BUS_MUSIC
		p.volume_db = -80.0
		add_child(p)
		_music_players.append(p)
	_amb = AudioStreamPlayer.new()
	_amb.bus = BUS_AMB
	_amb.volume_db = AMB_DB
	add_child(_amb)


func _apply_quality() -> void:
	if QualityManager != null and QualityManager.profile != null:
		_voice_limit = clampi(QualityManager.profile.max_voices, 4, VOICE_COUNT)
		# Profil plus bas : les voix au-delà de la nouvelle limite sont libérées.
		for i: int in range(_voice_limit, VOICE_COUNT):
			if _voices[i].playing:
				_release(i)


# --- Effets sonores ----------------------------------------------------------------------------


## Joue un effet. `pos` (plan XZ de l'arène) place le son dans le champ stéréo et l'atténue avec
## la distance au joueur ; `NO_POS` = centré. Renvoie vrai si le son a effectivement démarré.
func play(
	sound: StringName,
	pos: Vector2 = NO_POS,
	vol_db: float = 0.0,
	pitch: float = 1.0,
	variant: int = -1,
	listener: Vector2 = Vector2.ZERO
) -> bool:
	var d: Dictionary = SfxCatalog.def(sound)
	if sound_mode == 2 or d.is_empty():
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	var slot: int = _reserve(sound, d, now)
	if slot < 0:
		refused += 1
		return false
	var stream: AudioStream = _pick_stream(sound, int(d["n"]), variant)
	if stream == null:
		return false
	var v: AudioStreamPlayer = _voices[slot]
	v.stream = stream
	v.bus = _bus_for(d, pos)
	var atten: float = _distance_attenuation(pos, listener)
	v.volume_db = float(d["vol"]) + vol_db - atten + _rng.randf_range(-0.8, 0.8)
	var spread: float = float(d["pitch"])
	v.pitch_scale = pitch * (1.0 + _rng.randf_range(-spread, spread))
	_voice_name[slot] = String(sound)
	_voice_prio[slot] = int(d["prio"])
	_voice_start[slot] = now
	_last_play[sound] = now
	v.play()
	played += 1
	return true


## Réserve une voix pour `sound` : respecte le délai minimal et le nombre max d'instances ; à
## saturation, un son important coupe un son moins important. Renvoie -1 si refusé.
func _reserve(sound: StringName, d: Dictionary, now: float) -> int:
	if now - float(_last_play.get(sound, -10.0)) < float(d["cd"]):
		return -1
	var prio: int = int(d["prio"])
	if _count_active(sound) >= int(d["max"]) and (prio < 2 or not _steal_same(sound)):
		return -1
	return _acquire_voice(prio)


## Son d'interface (centré, bus UI).
func play_ui(sound: StringName) -> void:
	play(sound)


func _bus_for(d: Dictionary, pos: Vector2) -> StringName:
	if StringName(d["bus"]) == BUS_UI:
		return BUS_UI
	if pos == NO_POS:
		return PAN_BUSES[2]
	return PAN_BUSES[pan_index(pos.x)]


## Sous-bus de panoramique (0..4) pour une abscisse du plan de l'arène.
static func pan_index(x: float) -> int:
	var p: float = clampf(x / PAN_RANGE, -1.0, 1.0)
	if p < -0.65:
		return 0
	if p < -0.2:
		return 1
	if p <= 0.2:
		return 2
	if p <= 0.65:
		return 3
	return 4


static func _distance_attenuation(pos: Vector2, listener: Vector2) -> float:
	if pos == NO_POS:
		return 0.0
	var dist: float = pos.distance_to(listener)
	return clampf((dist - FAR_START) / (FAR_END - FAR_START), 0.0, 1.0) * FAR_ATTEN_DB


func _pick_stream(sound: StringName, count: int, variant: int) -> AudioStream:
	var list: Array = _bank.get(sound, []) as Array
	if list.is_empty():
		for i: int in count:
			var path: String = SfxCatalog.path(sound, i)
			if ResourceLoader.exists(path):
				list.append(load(path))
		_bank[sound] = list
	if list.is_empty():
		return null
	var idx: int = variant
	if idx < 0:
		idx = _rng.randi() % list.size()
		if list.size() > 1 and idx == int(_last_variant.get(sound, -1)):
			idx = (idx + 1 + _rng.randi() % (list.size() - 1)) % list.size()
	idx = clampi(idx, 0, list.size() - 1)
	_last_variant[sound] = idx
	return list[idx] as AudioStream


## Voix libre, sinon la moins importante (priorité plus basse, puis la plus ancienne).
func _acquire_voice(prio: int) -> int:
	var worst: int = -1
	for i: int in _voice_limit:
		if not _voices[i].playing:
			return i
		if (
			worst < 0
			or _voice_prio[i] < _voice_prio[worst]
			or (_voice_prio[i] == _voice_prio[worst] and _voice_start[i] < _voice_start[worst])
		):
			worst = i
	if worst >= 0 and _voice_prio[worst] < prio:
		_release(worst)
		return worst
	return -1


func _steal_same(sound: StringName) -> bool:
	var oldest: int = -1
	for i: int in _voice_limit:
		if _voices[i].playing and _voice_name[i] == String(sound):
			if oldest < 0 or _voice_start[i] < _voice_start[oldest]:
				oldest = i
	if oldest < 0:
		return false
	_release(oldest)
	return true


func _release(slot: int) -> void:
	_voices[slot].stop()
	_on_voice_finished(slot)


func _on_voice_finished(slot: int) -> void:
	_voice_name[slot] = ""


## Instances de `sound` en cours de lecture (comptées sur les voix : jamais de compteur à dériver).
func _count_active(sound: StringName) -> int:
	var n: int = 0
	var key: String = String(sound)
	for i: int in VOICE_COUNT:
		if _voices[i].playing and _voice_name[i] == key:
			n += 1
	return n


## Coupe tous les effets en cours (changement de scène, tests).
func stop_all() -> void:
	for i: int in VOICE_COUNT:
		if _voices[i].playing:
			_release(i)


func active_voices() -> int:
	var n: int = 0
	for v: AudioStreamPlayer in _voices:
		if v.playing:
			n += 1
	return n


# --- Musique -----------------------------------------------------------------------------------


## Lance un morceau (menu / run / boss / none) avec fondu enchaîné.
func play_music(kind: StringName, fade: float = 1.0) -> void:
	if kind == _music_kind:
		return
	_music_kind = kind
	var old: AudioStreamPlayer = _music_players[_music_slot]
	_music_slot = 1 - _music_slot
	var fresh: AudioStreamPlayer = _music_players[_music_slot]
	var stream: AudioStream = null
	if kind != &"none" and MUSIC_TRACKS.has(kind):
		stream = _music_stream(kind)
	if not old.playing and stream == null:
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.chain().tween_callback(old.stop)
	if stream == null:
		return
	fresh.stream = stream
	fresh.volume_db = -60.0
	fresh.play()
	_layer_value = PackedFloat32Array([1.0, 0.0, 0.0])
	_layer_target = PackedFloat32Array([1.0, 0.0, 0.0])
	tw.tween_property(fresh, "volume_db", 0.0, fade)


func music_kind() -> StringName:
	return _music_kind


func _music_stream(kind: StringName) -> AudioStream:
	if _music_streams.has(kind):
		return _music_streams[kind] as AudioStream
	var paths: Array = MUSIC_TRACKS[kind] as Array
	var loaded: Array[AudioStreamOggVorbis] = []
	for p: String in paths:
		if not ResourceLoader.exists(p):
			continue
		var s: AudioStreamOggVorbis = load(p) as AudioStreamOggVorbis
		if s == null:
			continue
		s.loop = true
		loaded.append(s)
	if loaded.is_empty():
		return null
	var result: AudioStream = loaded[0]
	if loaded.size() > 1:
		var sync: AudioStreamSynchronized = AudioStreamSynchronized.new()
		sync.stream_count = loaded.size()
		for i: int in loaded.size():
			sync.set_sync_stream(i, loaded[i])
		result = sync
	_music_streams[kind] = result
	return result


## Intensité de chaque couche (0..1) : [rythme, harmonie, mélodie]. Lissée dans `_process`.
func set_layers(targets: PackedFloat32Array) -> void:
	_layer_target = targets


func _update_layers(delta: float) -> void:
	var stream: AudioStream = _music_streams.get(_music_kind) as AudioStream
	for i: int in _layer_value.size():
		_layer_value[i] = move_toward(_layer_value[i], _layer_target[i], STEM_RATE * delta)
	if stream is AudioStreamSynchronized:
		var sync: AudioStreamSynchronized = stream as AudioStreamSynchronized
		for i: int in mini(sync.stream_count, _layer_value.size()):
			sync.set_sync_stream_volume(i, linear_to_db(maxf(_layer_value[i], 0.0001)))


func layer_value(i: int) -> float:
	return _layer_value[i]


## Abaisse brièvement la musique (dB négatifs) : elle remonte seule.
func duck_music(db: float) -> void:
	_duck_db = minf(_duck_db, db)


## Musique étouffée (filtre passe-bas) : pause, panneau d'amélioration.
func set_muffled(on: bool) -> void:
	if on == _muffled or _lowpass == null:
		return
	_muffled = on
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_lowpass, "cutoff_hz", 900.0 if on else 20500.0, 0.3)


func is_muffled() -> bool:
	return _muffled


func play_ambience() -> void:
	if _amb.playing:
		return
	if ResourceLoader.exists(AMBIENCE_PATH):
		var s: AudioStreamOggVorbis = load(AMBIENCE_PATH) as AudioStreamOggVorbis
		if s != null:
			s.loop = true
			_amb.stream = s
			_amb.play()


func stop_ambience() -> void:
	_amb.stop()


# --- Réglages ----------------------------------------------------------------------------------


func cycle_sound_mode() -> void:
	set_sound_mode((sound_mode + 1) % 3)


func set_sound_mode(mode: int) -> void:
	sound_mode = clampi(mode, 0, 2)
	UserSettings.set_sound_mode(sound_mode)
	_apply_mix()


func sound_label() -> String:
	return SOUND_LABELS[sound_mode]


func _apply_mix() -> void:
	var sfx_on: bool = sound_mode < 2
	for bus: StringName in [BUS_SFX, BUS_UI, BUS_AMB]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), not sfx_on)
	_apply_music_volume()


func _apply_music_volume() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	AudioServer.set_bus_mute(idx, sound_mode != 0)
	AudioServer.set_bus_volume_db(
		idx, MUSIC_BASE_DB + _duck_db + linear_to_db(maxf(_music_volume, 0.0001))
	)
