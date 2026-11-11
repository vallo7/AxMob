extends Node
## Diagnostic et garde anti-plantage (autoload « Diagnostics », phase 6).
##  - témoin de plantage (CrashGuard) : voir crash_guard.gd ;
##  - journal court dans user://diagnostic.log (la session précédente est gardée en .prev : si
##    l'appli plante, le journal de CETTE session-là est lisible au lancement suivant) ;
##  - mesures de mémoire (vidéo, statique) toutes les 2 s, pics retenus, vidage disque toutes les
##  10 s ;
##  - rapport texte copiable (Réglages) : appareil, GPU, profil, plantages, mémoire.
## Aucune donnée personnelle, rien n'est envoyé : le joueur copie le rapport s'il veut le partager.

signal crash_detected(info: Dictionary)

const STATE_PATH: String = "user://crash_state.json"
const LOG_PATH: String = "user://diagnostic.log"
const SAMPLE_INTERVAL: float = 2.0
const FLUSH_INTERVAL: float = 10.0
const MAX_LINES: int = 180
const MB: float = 1048576.0

var guard: CrashGuard
## Résultat de l'analyse de la session précédente : {crashed, tier, mode}.
var previous: Dictionary = {"crashed": false, "tier": 1, "mode": 0}
var video_mb: float = 0.0
var static_mb: float = 0.0
var peak_video_mb: float = 0.0
var peak_static_mb: float = 0.0

var _lines: PackedStringArray = PackedStringArray()
var _t_sample: float = 0.0
var _t_flush: float = 0.0
var _dirty: bool = false
var _previous_log: String = ""
var _started: bool = false
## Faux en headless (tests, simulateur) : ni témoin ni journal sur le disque, aucun faux plantage.
var _persist: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_persist = DisplayServer.get_name() != "headless"
	if _persist and FileAccess.file_exists(LOG_PATH):
		_previous_log = FileAccess.get_file_as_string(LOG_PATH)
	guard = CrashGuard.load_from(STATE_PATH) if _persist else CrashGuard.new()
	previous = guard.detect()
	_save_state()
	log_event("session %d — %s" % [int(guard.state["sessions"]) + 1, _device_line()])
	if bool(previous["crashed"]):
		log_event(
			(
				"PLANTAGE détecté (session précédente : profil %d, mode %d) ; plafond %d"
				% [int(previous["tier"]), int(previous["mode"]), guard.ceiling()]
			)
		)
		crash_detected.emit(previous)
	_flush()


## Pose le témoin : la session est « en cours » avec ce profil et ce mode.
func begin_session(tier: int, mode: int) -> void:
	_started = true
	guard.start(tier, mode)
	_save_state()
	log_event("profil de départ %d, mode %d, plafond %d" % [tier, mode, guard.ceiling()])


## Le profil change en cours de session : le témoin retient le profil réellement actif.
func note_tier(tier: int, reason: String) -> void:
	guard.note_tier(tier)
	if _started:
		_save_state()
	log_event("profil -> %d (%s)" % [tier, reason])


func log_event(text: String) -> void:
	_lines.append("[%7.1f] %s" % [float(Time.get_ticks_msec()) / 1000.0, text])
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_dirty = true
	print("[diag] ", text)


func _process(delta: float) -> void:
	_t_sample += delta
	_t_flush += delta
	if _t_sample >= SAMPLE_INTERVAL:
		_t_sample = 0.0
		_sample()
	if _t_flush >= FLUSH_INTERVAL:
		_t_flush = 0.0
		_flush()


func _sample() -> void:
	video_mb = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB
	static_mb = float(OS.get_static_memory_usage()) / MB
	peak_video_mb = maxf(peak_video_mb, video_mb)
	peak_static_mb = maxf(peak_static_mb, static_mb)
	_dirty = true
	if Engine.get_frames_drawn() % 3 == 0 or video_mb > 0.0:
		_lines.append(
			(
				"[%7.1f] mem vidéo %.0f Mo, statique %.0f Mo, %d i/s"
				% [
					float(Time.get_ticks_msec()) / 1000.0,
					video_mb,
					static_mb,
					Engine.get_frames_per_second()
				]
			)
		)
		while _lines.size() > MAX_LINES:
			_lines.remove_at(0)


func _flush() -> void:
	if not _dirty or not _persist:
		return
	_dirty = false
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines))
		f.close()


func _save_state() -> void:
	if _persist:
		guard.save_to(STATE_PATH)


## Quitter proprement (retour système, quit()) : le témoin est effacé. Un plantage, lui, ne passe
## jamais ici : c'est précisément ce qui le distingue.
func _exit_tree() -> void:
	shutdown()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# En arrière-plan le système peut tuer l'appli : ce n'est pas un plantage.
			guard.set_foreground(false)
			_save_state()
			log_event("mise en arrière-plan")
			_flush()
		NOTIFICATION_APPLICATION_RESUMED:
			if _started:
				guard.set_foreground(true)
				_save_state()
			log_event("retour au premier plan")
		NOTIFICATION_WM_CLOSE_REQUEST:
			shutdown()


## Fermeture propre : le témoin est effacé (appelé avant tout `quit()` du jeu).
func shutdown() -> void:
	if guard == null:
		return
	guard.stop()
	_save_state()
	log_event("fermeture propre")
	_flush()


func _device_line() -> String:
	var v: Dictionary = Engine.get_version_info()
	return (
		"build %s · Godot %s · %s %s · %s · GPU %s"
		% [
			str(ProjectSettings.get_setting("application/config/version", "dev")),
			str(v.get("string", "?")),
			OS.get_name(),
			OS.get_version(),
			OS.get_model_name(),
			RenderingServer.get_video_adapter_name()
		]
	)


## Rapport copiable (Réglages > COPIER LE RAPPORT TECHNIQUE).
func report() -> String:
	var info: Dictionary = OS.get_memory_info()
	var out: PackedStringArray = PackedStringArray()
	out.append("=== AxMob — rapport technique ===")
	out.append(_device_line())
	out.append(
		(
			"GPU : %s (%s) · API %s"
			% [
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_video_adapter_vendor(),
				RenderingServer.get_video_adapter_api_version()
			]
		)
	)
	out.append(
		(
			"écran %s · rendu 3D x%.2f · %d i/s · RAM %s Mo"
			% [
				str(DisplayServer.window_get_size()),
				QualityManager.applied_scale,
				Engine.get_frames_per_second(),
				(
					str(int(float(info.get("physical", -1)) / MB))
					if float(info.get("physical", -1)) > 0.0
					else "?"
				)
			]
		)
	)
	out.append(
		(
			"qualité : %s · plafond %d · plantages %d (dernier profil %d) · séries stables %d%s"
			% [
				QualityManager.mode_label(),
				guard.ceiling(),
				int(guard.state["crashes"]),
				int(guard.state["last_crash_tier"]),
				int(guard.state["clean_streak"]),
				" · VERROUILLÉ" if bool(guard.state["locked"]) else ""
			]
		)
	)
	out.append(
		(
			"mémoire : vidéo %.0f Mo (pic %.0f) · statique %.0f Mo (pic %.0f)"
			% [video_mb, peak_video_mb, static_mb, peak_static_mb]
		)
	)
	out.append("sauvegarde : %s" % SaveManager.load_source)
	out.append("--- journal (session en cours) ---")
	out.append("\n".join(_lines.slice(maxi(_lines.size() - 40, 0))))
	if bool(previous["crashed"]) and _previous_log != "":
		out.append("--- journal de la session qui a PLANTÉ (fin) ---")
		var prev_lines: PackedStringArray = _previous_log.split("\n")
		out.append("\n".join(prev_lines.slice(maxi(prev_lines.size() - 40, 0))))
	return "\n".join(out)
