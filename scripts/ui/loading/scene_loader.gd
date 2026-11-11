extends Node
## Changement de scène avec VRAI chargement (autoload « SceneLoader », phase 6).
##  1. écran de chargement (fondu) ;
##  2. chargement en arrière-plan (ResourceLoader.load_threaded_*) de la scène ET de ses ressources
##     (modèles 3D, shaders, textures d'interface, sons) : la barre suit ce qui est réellement
##     chargé ;
##  3. changement de scène sous l'écran de chargement ;
##  4. préchauffage : quelques images rendues pour compiler les shaders AVANT de découvrir le jeu ;
##  5. fondu de sortie.
## Les ressources chargées sont gardées en cache (aucun à-coup au premier tir ou au premier son).
## Erreur de chargement de la scène : message + RÉESSAYER / MENU (jamais d'écran figé).

signal scene_ready(path: String)

const MIN_FULL: float = 1.2
const MIN_QUICK: float = 0.35
const WARM_FRAMES: int = 4

var busy: bool = false
var last_path: String = ""
var last_error: String = ""

var _screen: LoadingScreen
var _keep: Dictionary = {}  # chemin -> Resource : le cache doit garder les ressources préchargées
var _retry: bool = false
var _to_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = LoadingScreen.new()
	add_child(_screen)
	_screen.retry_pressed.connect(func() -> void: _retry = true)
	_screen.menu_pressed.connect(func() -> void: _to_menu = true)


## opts : first (page blanche au départ), quick (fondu bref : REJOUER).
func go(path: String, opts: Dictionary = {}) -> void:
	if busy:
		return
	busy = true
	last_path = path
	var first: bool = bool(opts.get("first", false))
	var quick: bool = bool(opts.get("quick", false))
	var started: float = Time.get_ticks_msec() / 1000.0
	get_tree().paused = false
	if path == LoadManifest.MENU_SCENE:
		QualityManager.leave_run()
	_screen.open(first, quick)
	await _screen.shown

	var progress: LoadProgress = LoadProgress.new()
	LoadManifest.fill(progress, path)
	var packed: PackedScene = await _load_all(progress, path)
	if packed == null:
		await _handle_error(path, opts)
		return

	_screen.set_progress(0.9, Loc.t("load_scene"))
	get_tree().change_scene_to_packed(packed)
	for i: int in 2:
		await get_tree().process_frame
	# Préchauffage : on laisse le moteur dessiner quelques images (compilation des shaders).
	for i: int in WARM_FRAMES:
		_screen.set_progress(0.9 + 0.1 * float(i) / float(WARM_FRAMES), Loc.t("load_warm"))
		await get_tree().process_frame
	var min_time: float = MIN_QUICK if quick else MIN_FULL
	while Time.get_ticks_msec() / 1000.0 - started < min_time:
		_screen.set_progress(1.0, Loc.t("load_warm"))
		await get_tree().process_frame
	_screen.set_progress(1.0, Loc.t("load_warm"))
	_screen.close()
	await _screen.hidden
	busy = false
	scene_ready.emit(path)


## Charge tout par groupes ; retourne la scène (null si elle n'a pas pu être chargée).
func _load_all(progress: LoadProgress, scene_path: String) -> PackedScene:
	for g: Variant in progress.groups():
		for p: String in progress.paths_of(g as String):
			if not _keep.has(p):
				ResourceLoader.load_threaded_request(p)
	var pending: Dictionary = {}
	for g: Variant in progress.groups():
		pending[g] = progress.paths_of(g as String).duplicate()
	var done: Dictionary = {}
	for g: Variant in progress.groups():
		done[g] = 0
	var scene_failed: bool = false
	while not progress.complete() and not scene_failed:
		for g: Variant in progress.groups():
			var list: Array = pending[g] as Array
			var i: int = list.size() - 1
			while i >= 0:
				var p: String = list[i] as String
				if _keep.has(p):
					list.remove_at(i)
					done[g] = int(done[g]) + 1
				else:
					var st: ResourceLoader.ThreadLoadStatus = (
						ResourceLoader.load_threaded_get_status(p)
					)
					if st == ResourceLoader.THREAD_LOAD_LOADED:
						_keep[p] = ResourceLoader.load_threaded_get(p)
						list.remove_at(i)
						done[g] = int(done[g]) + 1
					elif (
						st == ResourceLoader.THREAD_LOAD_FAILED
						or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
					):
						if p == scene_path:
							scene_failed = true
						push_warning("[loader] échec : %s" % p)
						list.remove_at(i)
						done[g] = int(done[g]) + 1
				i -= 1
			progress.set_done(g as String, int(done[g]))
		var shown: float = progress.step_display(get_process_delta_time())
		var phase: String = (
			Loc.t("load_assets") if progress.ratio() < 0.999 else Loc.t("load_scene")
		)
		_screen.set_progress(minf(shown, 0.9), phase)
		await get_tree().process_frame
	if scene_failed:
		return null
	return _keep.get(scene_path) as PackedScene


func _handle_error(path: String, opts: Dictionary) -> void:
	last_error = "load_failed:" + path
	_retry = false
	_to_menu = false
	_screen.show_error(Loc.t("loading_failed"))
	while not _retry and not _to_menu:
		await get_tree().process_frame
	busy = false
	if _retry:
		go(path, opts)
	else:
		_keep.erase(LoadManifest.MENU_SCENE)
		go(LoadManifest.MENU_SCENE, {"quick": true})
