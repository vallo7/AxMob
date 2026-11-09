extends RefCounted
## Tests (logique pure) de la phase 5 : gouverneur de qualité, arrêt sur image, calcul du cadrage,
## animation procédurale des ennemis, catalogue sonore, panoramique, profils de qualité.

var t: Object


func _check(cond: bool, msg: String) -> void:
	t.call("check", cond, msg)


# --- QualityGovernor ---------------------------------------------------------------------------


## Alimente le gouverneur avec `seconds` de durées d'image constantes ; renvoie les changements.
func _feed(g: QualityGovernor, seconds: float, frame_ms: float) -> Array[int]:
	var out: Array[int] = []
	var dt: float = frame_ms / 1000.0
	var elapsed: float = 0.0
	while elapsed < seconds:
		var r: int = g.feed(dt)
		if r >= 0:
			out.append(r)
		elapsed += dt
	return out


func test_governor_steps_down_on_slow_frames() -> void:
	var g: QualityGovernor = QualityGovernor.new(QualityProfile.Tier.HIGH)
	var changes: Array[int] = _feed(g, 12.0, 24.0)
	_check(
		changes.size() >= 1 and changes[0] == QualityProfile.Tier.MEDIUM, "descend HIGH -> MEDIUM"
	)
	_check(g.tier < QualityProfile.Tier.HIGH, "profil abaissé")
	var more: Array[int] = _feed(g, 20.0, 24.0)
	_check(g.tier == QualityProfile.Tier.LOW, "continue jusqu'à BAS si ça reste lent")
	_check(more.size() >= 1, "changement notifié")
	_check(_feed(g, 20.0, 24.0).is_empty(), "jamais en dessous de BAS")


func test_governor_drops_fast_on_very_slow_frames() -> void:
	var g: QualityGovernor = QualityGovernor.new(QualityProfile.Tier.HIGH)
	var changes: Array[int] = _feed(g, 6.0, 40.0)
	_check(changes.size() >= 1, "fenêtre très lente : descente sans attendre deux fenêtres")


func test_governor_stable_at_60fps() -> void:
	var g: QualityGovernor = QualityGovernor.new(QualityProfile.Tier.MEDIUM)
	g.ceiling = QualityProfile.Tier.MEDIUM
	_check(_feed(g, 60.0, 16.67).is_empty(), "60 i/s stable : aucun changement")


func test_governor_probes_up_then_reverts_and_sets_ceiling() -> void:
	var g: QualityGovernor = QualityGovernor.new(QualityProfile.Tier.MEDIUM)
	# Images parfaites jusqu'au premier changement : sonde vers le profil du dessus.
	var changed: int = -1
	var guard: int = 0
	while changed < 0 and guard < 5000:
		changed = g.feed(0.0166)
		guard += 1
	_check(changed == QualityProfile.Tier.HIGH, "sonde vers ÉLEVÉ après une période sans raté")
	_check(
		guard * 0.0166 >= QualityGovernor.GOOD_BEFORE_PROBE,
		"pas avant %.0f s de stabilité" % QualityGovernor.GOOD_BEFORE_PROBE
	)
	# Stabilisation (images ignorées), puis une fenêtre lente : la sonde échoue.
	_feed(g, QualityGovernor.SETTLE, 16.6)
	var back: Array[int] = _feed(g, QualityGovernor.WINDOW + 0.1, 24.0)
	_check(back.size() == 1 and back[0] == QualityProfile.Tier.MEDIUM, "retour à MOYEN")
	_check(g.ceiling == QualityProfile.Tier.MEDIUM, "plafond abaissé (pas de yo-yo)")
	_feed(g, QualityGovernor.SETTLE, 16.6)
	_check(_feed(g, 40.0, 16.6).is_empty(), "plus de sonde vers ÉLEVÉ cette session")


func test_governor_ignores_hitches_and_can_be_disabled() -> void:
	var g: QualityGovernor = QualityGovernor.new(QualityProfile.Tier.HIGH)
	for i: int in 400:
		_check(g.feed(0.6) < 0, "image de 600 ms (chargement) ignorée")
	g.enabled = false
	_check(_feed(g, 30.0, 40.0).is_empty(), "désactivé : aucune décision")


# --- Profils -----------------------------------------------------------------------------------


func test_quality_profiles_are_monotonic() -> void:
	var low: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.LOW)
	var mid: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.MEDIUM)
	var high: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.HIGH)
	_check(low.fx_density < mid.fx_density and mid.fx_density < high.fx_density, "densité d'effets")
	_check(low.render_megapixels < mid.render_megapixels, "résolution 3D BAS < MOYEN")
	_check(mid.render_megapixels < high.render_megapixels, "résolution 3D MOYEN < ÉLEVÉ")
	_check(low.spark_capacity < high.spark_capacity or high.spark_capacity >= 256, "capacités")
	_check(low.max_voices <= mid.max_voices and mid.max_voices <= high.max_voices, "polyphonie")
	_check(high.msaa == Viewport.MSAA_2X and low.msaa == Viewport.MSAA_DISABLED, "anticrénelage")
	_check(QualityProfile.clamp_tier(99) == QualityProfile.Tier.HIGH, "borne haute")
	_check(QualityProfile.clamp_tier(-3) == QualityProfile.Tier.LOW, "borne basse")


func test_render_scale_targets_pixel_budget() -> void:
	var high: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.HIGH)
	var mid: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.MEDIUM)
	# Samsung S10e : écran 1080 x 2280 -> rendu 3D à ~92 % en ÉLEVÉ, ~77 % en MOYEN.
	var s10e_high: float = high.render_scale_for(1080.0, 2280.0)
	_check(s10e_high > 0.88 and s10e_high < 0.96, "S10e ÉLEVÉ : 3D à %.0f %%" % (s10e_high * 100.0))
	var s10e_mid: float = mid.render_scale_for(1080.0, 2280.0)
	_check(s10e_mid > 0.72 and s10e_mid < 0.82, "S10e MOYEN : 3D à %.0f %%" % (s10e_mid * 100.0))
	# Écran QHD+ (1440 x 3040) : réduit davantage, l'interface reste nette (dessinée en natif).
	var qhd: float = high.render_scale_for(1440.0, 3040.0)
	_check(qhd > 0.6 and qhd < 0.8, "QHD+ : 3D à %.0f %%" % (qhd * 100.0))
	_check(high.render_scale_for(720.0, 1280.0) == 1.0, "petit écran : pas de réduction")
	var low: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.LOW)
	_check(low.render_scale_for(1440.0, 3040.0) >= 0.5, "plancher d'échelle")


# --- FeelDirector -------------------------------------------------------------------------------


func test_feel_director_hitstop_and_slowmo() -> void:
	var feel: FeelConfig = FeelConfig.new()
	var d: FeelDirector = FeelDirector.new(feel)
	_check(d.advance(0.016) == 1.0, "temps normal sans demande")
	d.request(0.05, 0.04)
	_check(d.advance(0.016) < 0.1, "arrêt sur image : quasi figé")
	d.advance(0.02)
	d.advance(0.02)
	_check(d.advance(0.016) == 1.0, "revient à la normale après la durée RÉELLE")
	d.request(0.5, 0.35)
	_check(is_equal_approx(d.advance(0.016), 0.35), "ralenti")
	d.request(0.05, 0.04)
	_check(d.advance(0.016) < 0.1, "l'arrêt sur image domine le ralenti")
	_check(d.is_active(), "actif")
	d.request(-1.0, 0.0)
	_check(true, "durée négative ignorée sans erreur")


# --- CameraFit ----------------------------------------------------------------------------------


func test_camera_fit_hits_target_and_follows_pitch() -> void:
	var cfg: GameConfig = DataRegistry.config()
	var feel: FeelConfig = FeelConfig.new()
	var dist: float = CameraFit.distance_for(cfg, feel)
	var pts: Array[Vector3] = CameraFit._points(cfg)
	var foci: Array[Vector3] = CameraFit._foci(cfg, feel)
	var worst: float = CameraFit.worst_ndc_x(pts, foci, dist, feel)
	_check(absf(worst - feel.fit_target) < 0.004, "cadrage : pire cas = cible (%.3f)" % worst)
	_check(CameraFit.worst_ndc_x(pts, foci, dist * 1.1, feel) < worst, "plus loin = plus petit")
	# Plus la vue est oblique, plus la caméra doit reculer pour garder les tourelles dans l'écran.
	var steep: FeelConfig = FeelConfig.new()
	steep.pitch_degrees = 75.0
	_check(CameraFit.distance_for(cfg, steep) != dist, "la distance dépend de l'angle")
	_check(feel.pitch_degrees < 70.0, "angle plus en plongée que la phase 4 (70°)")


# --- Animation procédurale des ennemis -----------------------------------------------------------


func _enemy(state: Enemy.State, st: float) -> Enemy:
	var e: Enemy = Enemy.new(0)
	e.data = DataRegistry.enemies()[0]
	e.state = state
	e.state_time = st
	e.facing = Vector2(0.0, -1.0)
	return e


func test_enemy_juice_spawn_pops_and_settles() -> void:
	var j: JuiceProfile = JuiceProfile.new()
	var out: EnemyJuice.Out = EnemyJuice.Out.new()
	var e: Enemy = _enemy(Enemy.State.SPAWNING, 0.0)
	EnemyJuice.compute(e, j, 0.5, 0.6, 3.0, out)
	_check(out.uniform < 0.35, "apparition : part de très petit (%.2f)" % out.uniform)
	e.state_time = 0.25
	EnemyJuice.compute(e, j, 0.5, 0.6, 3.0, out)
	_check(out.offset.y > 0.1, "apparition : saute hors du sable")
	e.state_time = 0.5
	EnemyJuice.compute(e, j, 0.5, 0.6, 3.0, out)
	_check(absf(out.uniform - 1.0) < 0.02, "fin d'apparition : taille normale")


func test_enemy_juice_run_hops_and_squashes() -> void:
	var j: JuiceProfile = JuiceProfile.new()
	var out: EnemyJuice.Out = EnemyJuice.Out.new()
	var e: Enemy = _enemy(Enemy.State.CHASE, 1.0)
	e.vel = Vector2(0.0, -3.0)
	var highest: float = 0.0
	var squash_seen: bool = false
	var stretch_seen: bool = false
	for i: int in 120:
		EnemyJuice.advance(e, j, 3.0, 1.0 / 60.0)
		EnemyJuice.compute(e, j, 0.5, 0.6, 3.0, out)
		highest = maxf(highest, out.offset.y)
		squash_seen = squash_seen or out.scale.y < 0.97
		stretch_seen = stretch_seen or out.scale.y > 1.03
		_check(out.scale.y > 0.0 and out.scale.x > 0.0, "échelle toujours positive")
	_check(highest > j.hop_height * 0.8, "rebonds en courant")
	_check(squash_seen and stretch_seen, "écrasement ET étirement")
	e.vel = Vector2.ZERO
	EnemyJuice.compute(e, j, 0.5, 0.6, 3.0, out)
	_check(absf(out.offset.y) < 0.001, "à l'arrêt : plus de rebond")


func test_enemy_juice_hit_squash_decays() -> void:
	var j: JuiceProfile = JuiceProfile.new()
	var out: EnemyJuice.Out = EnemyJuice.Out.new()
	var e: Enemy = _enemy(Enemy.State.CHASE, 1.0)
	e.hit_kick = 1.0
	e.hit_dir = Vector2(1.0, 0.0)
	EnemyJuice.compute(e, j, 0.5, 0.6, 3.0, out)
	_check(out.scale.y < 0.85, "impact : écrasement net (%.2f)" % out.scale.y)
	_check(absf(out.rot.z) > 0.01 or absf(out.rot.x) > 0.01, "impact : inclinaison")
	for i: int in 120:
		EnemyJuice.advance(e, j, 3.0, 1.0 / 60.0)
	_check(e.hit_kick == 0.0, "l'impulsion retombe à zéro")


func test_enemy_juice_death_styles_end_cleanly() -> void:
	var out: EnemyJuice.Out = EnemyJuice.Out.new()
	for style: int in 4:
		var j: JuiceProfile = JuiceProfile.new()
		j.death_style = style as JuiceProfile.DeathStyle
		var e: Enemy = _enemy(Enemy.State.DYING, 0.0)
		for k: int in 11:
			e.state_time = 0.6 * float(k) / 10.0
			EnemyJuice.compute(e, j, 0.5, 0.6, 3.0, out)
			_check(
				out.scale.x > 0.0 and out.scale.y > 0.0 and out.scale.z > 0.0,
				"style %d : échelle valide" % style
			)
			_check(
				is_finite(out.rot.y) and is_finite(out.offset.y),
				"style %d : valeurs finies" % style
			)


func test_every_enemy_has_juice_and_sound_kind() -> void:
	var all: Array[EnemyData] = DataRegistry.enemies().duplicate()
	all.append(DataRegistry.wave_table().boss)
	var kinds: Array[StringName] = [&"shell", &"squish", &"hollow", &"bubble", &"kraken"]
	for d: EnemyData in all:
		_check(d.juice != null, "%s : profil d'animation" % d.id)
		_check(kinds.has(d.sound_kind), "%s : famille sonore valide" % d.id)
		_check(
			SfxCatalog.has(StringName("mat_" + String(d.sound_kind))), "%s : son d'impact" % d.id
		)
		_check(SfxCatalog.has(StringName("die_" + String(d.sound_kind))), "%s : son de mort" % d.id)


# --- Catalogue sonore -----------------------------------------------------------------------------


func test_sfx_catalog_files_exist_and_are_consistent() -> void:
	var seen: int = 0
	for sound: StringName in SfxCatalog.DEFS:
		var d: Dictionary = SfxCatalog.def(sound)
		for key: String in ["n", "vol", "pitch", "cd", "max", "prio", "bus"]:
			_check(d.has(key), "%s : champ %s" % [sound, key])
		_check(int(d["prio"]) >= 0 and int(d["prio"]) <= 3, "%s : priorité 0..3" % sound)
		_check(int(d["max"]) >= 1, "%s : au moins une instance" % sound)
		for v: int in int(d["n"]):
			var path: String = SfxCatalog.path(sound, v)
			_check(ResourceLoader.exists(path), "fichier présent : %s" % path)
			seen += 1
	_check(seen >= 80, "au moins 80 fichiers sonores (%d)" % seen)
	# Chaque fichier du dossier est référencé par le catalogue (pas de fichier orphelin).
	var dir: DirAccess = DirAccess.open(SfxCatalog.ROOT)
	for f: String in dir.get_files():
		if f.ends_with(".wav"):
			var base: String = f.get_basename()
			var name: String = base.substr(0, base.rfind("_"))
			_check(SfxCatalog.has(StringName(name)), "fichier orphelin : %s" % f)


func test_sfx_files_are_mono_44k_and_not_clipping() -> void:
	for sound: StringName in [&"throw_heavy", &"splash_heavy", &"coin_get", &"player_hurt"]:
		var s: AudioStreamWAV = load(SfxCatalog.path(sound, 0)) as AudioStreamWAV
		_check(s != null, "%s : AudioStreamWAV" % sound)
		_check(not s.stereo, "%s : mono (positionné par le jeu)" % sound)
		_check(s.mix_rate == 44100, "%s : 44,1 kHz" % sound)
		_check(
			s.format == AudioStreamWAV.FORMAT_16_BITS,
			"%s : PCM 16 bits (qualité exacte, aucun décodage)" % sound
		)
		_check(s.get_length() > 0.05 and s.get_length() < 6.0, "%s : durée plausible" % sound)
		var data: PackedByteArray = s.data
		var peak: int = 0
		for i: int in range(0, mini(data.size(), 200000) - 1, 2):
			peak = maxi(peak, absi(data.decode_s16(i)))
		_check(peak < 32700, "%s : pas d'écrêtage (pic %d)" % [sound, peak])


func test_music_stems_have_equal_length_for_sync() -> void:
	for kind: StringName in [&"run", &"boss"]:
		var lens: Array[float] = []
		for p: String in AudioManager.MUSIC_TRACKS[kind]:
			var s: AudioStreamOggVorbis = load(p) as AudioStreamOggVorbis
			_check(s != null, "%s chargé" % p)
			lens.append(s.get_length())
		_check(lens.size() == 3, "%s : trois couches" % kind)
		for l: float in lens:
			_check(absf(l - lens[0]) < 0.01, "%s : couches de même durée (%.3f)" % [kind, l])
	var amb: AudioStreamOggVorbis = load(AudioManager.AMBIENCE_PATH) as AudioStreamOggVorbis
	_check(amb != null and absf(amb.get_length() - 32.0) < 0.05, "ambiance : boucle de 32 s")


func test_pan_index_maps_arena_to_stereo_field() -> void:
	_check(AudioManager.pan_index(-13.0) == 0, "extrême gauche")
	_check(AudioManager.pan_index(-6.0) == 1, "gauche")
	_check(AudioManager.pan_index(0.0) == 2, "centre")
	_check(AudioManager.pan_index(2.0) == 2, "centre élargi")
	_check(AudioManager.pan_index(6.0) == 3, "droite")
	_check(AudioManager.pan_index(13.0) == 4, "extrême droite")
