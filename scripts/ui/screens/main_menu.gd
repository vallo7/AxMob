class_name MainMenu
extends Node3D
## Menu principal (cahier §10.2) : le héros en 3D sur la plage (animation « idle », caméra qui
## flotte doucement), logo, solde de pièces, JOUER, AMÉLIORATIONS, STATISTIQUES et RÉGLAGES.
## Tous les boutons ouvrent un vrai écran ou lancent une vraie partie (aucun bouton décoratif).
## Bouton retour du téléphone : « Appuyez encore pour quitter » (double appui).

## Largeur des tuiles latérales (AMÉLIORATIONS / STATISTIQUES), en pixels du viewport.
const TILE_W: float = 256.0
const HERO_SCALE: float = 1.65
const CAM_TARGET: Vector3 = Vector3(0.0, 1.6, -1.0)

var _hero: ModelRig
var _camera: Camera3D
var _time: float = 0.0
var _ui: CanvasLayer
var _root: Control
var _wallet: AxPill
var _logo: TextureRect
var _play: AxButton
var _best: Control
var _tile_up: AxButton
var _tile_stats: AxButton
var _badge: TextureRect
var _badge_label: Label
var _halo: Sprite3D
var _quit_press: DoublePress = DoublePress.new(2.0)
var _entrance: Array[Control] = []
var _logo_base_y: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	_build_world()
	_build_ui()
	AudioManager.play_music(&"menu")
	UIManager.push_back(self, _on_back)
	SaveManager.changed.connect(_on_save_changed)
	_animate_in()
	if not SaveManager.recovered_run.is_empty():
		var banked: int = int((SaveManager.recovered_run["result"] as Dictionary).get("banked", 0))
		SaveManager.recovered_run = {}
		UIManager.toast(Loc.t("run_recovered") % banked)
	if QualityManager.crash_notice_pending:
		QualityManager.crash_notice_pending = false
		UIManager.toast(Loc.t("crash_notice"))


func _process(delta: float) -> void:
	_time += delta
	if _hero != null:
		_hero.advance(delta)
	# Caméra : flottement lent autour du héros.
	var a: float = sin(_time * 0.22) * 0.16
	var dist: float = 8.2
	_camera.position = (
		CAM_TARGET + Vector3(sin(a) * dist, 1.9 + sin(_time * 0.31) * 0.12, cos(a) * dist)
	)
	_camera.look_at(CAM_TARGET + Vector3(0.0, 0.2, 0.0), Vector3.UP)
	if _logo != null:
		_logo.position.y = _logo_base_y + sin(_time * 1.6) * 7.0
	if _halo != null:
		_halo.scale = Vector3.ONE * (1.0 + 0.05 * sin(_time * 1.1))
		_halo.modulate.a = 0.7 + 0.15 * sin(_time * 1.7)


func _build_world() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#FFE8B8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.9, 0.98)
	env.ambient_light_energy = 0.62
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, 28.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 0.95
	sun.shadow_enabled = false
	add_child(sun)
	var arena: Arena = Arena.new()
	add_child(arena)
	arena.setup(DataRegistry.config())
	_hero = ModelRig.create("char_player")
	if _hero != null:
		_hero.root.scale = Vector3.ONE * HERO_SCALE
		_hero.root.rotation_degrees.y = 180.0 - 20.0
		add_child(_hero.root)
		_hero.play(&"idle", 1.0, true)
	# Halo doré derrière le héros (rayons du ruban de victoire) : le personnage « sort » du décor.
	_halo = Sprite3D.new()
	_halo.texture = UiArt.tex("misc/rays")
	_halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_halo.shaded = false
	_halo.transparent = true
	_halo.pixel_size = 0.021
	_halo.modulate = Color(1.0, 0.86, 0.45, 0.85)
	_halo.position = Vector3(0.0, 1.9, -2.4)
	add_child(_halo)
	_camera = Camera3D.new()
	_camera.fov = 44.0
	_camera.far = 4000.0
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.current = true
	add_child(_camera)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)
	var top: float = UiKit.top_inset() + 24.0

	# Barre du haut : pièces à gauche, réglages à droite (disposition des jeux mobiles à succès).
	_wallet = AxPill.make("icons/coin", 320.0, 96.0, 52)
	_wallet.position = Vector2(24.0, top)
	_wallet.set_color(UiArt.GOLD)
	_wallet.count_to(SaveManager.coins(), true)
	_root.add_child(_wallet)
	var gear: AxRoundButton = AxRoundButton.make("stone", "gear", 112.0)
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -136.0
	gear.offset_right = -24.0
	gear.offset_top = top - 6.0
	gear.offset_bottom = top + 116.0
	gear.pressed.connect(func() -> void: _open_screen(SettingsScreen.new()))
	_root.add_child(gear)

	# Logo flottant sous la barre du haut.
	_logo = UiArt.image("brand/logo")
	_logo.anchor_left = 0.5
	_logo.anchor_right = 0.5
	_logo.offset_left = -390.0
	_logo.offset_right = 390.0
	_logo.offset_top = top + 118.0
	_logo.offset_bottom = top + 118.0 + 516.0
	_logo.pivot_offset = Vector2(390.0, 258.0)
	_logo_base_y = _logo.position.y
	_root.add_child(_logo)

	# Tuiles latérales, de part et d'autre du héros : AMÉLIORATIONS à gauche, STATISTIQUES à droite.
	_tile_up = _make_tile("upgrades", "orange", "model_axe_rapid", false)
	_tile_up.pressed.connect(func() -> void: _open_screen(UpgradesScreen.new()))
	_root.add_child(_tile_up)
	_tile_stats = _make_tile("statistics", "blue", "chart", true)
	_tile_stats.pressed.connect(func() -> void: _open_screen(StatsScreen.new()))
	_root.add_child(_tile_stats)
	_badge = UiArt.image("misc/badge_red", Vector2(70, 74))
	_badge.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_root.add_child(_badge)
	_badge_label = UiArt.label("!", 38, UiArt.WHITE, Color("#6E1219"))
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_child(_badge_label)
	_badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Bas : ruban du record, énorme bouton JOUER, version.
	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 110.0
	bottom.offset_right = -110.0
	bottom.offset_top = -430.0
	bottom.offset_bottom = -96.0
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override(&"separation", 22)
	_root.add_child(bottom)
	_best = _build_best()
	bottom.add_child(_best)
	_play = AxButton.make(Loc.t("play"), "gold", Vector2(0, 214), 92, "play")
	_play.pressed.connect(_on_play)
	bottom.add_child(_play)
	_entrance = [_best, _play]

	var ver: Label = UiArt.label(
		"v" + str(ProjectSettings.get_setting("application/config/version", "dev")),
		26,
		Color(1, 1, 1, 0.8),
		UiArt.INK
	)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 28.0
	ver.offset_top = -64.0
	ver.offset_bottom = -20.0
	_root.add_child(ver)
	_layout_tiles()
	_refresh_best()


## Tuile carrée : grande icône + libellé. `right` : ancrée à droite de l'écran.
func _make_tile(key: String, style: String, icon: String, right: bool) -> AxButton:
	var b: AxButton = AxButton.make(Loc.t(key), style, Vector2(TILE_W, 262.0), 24, icon)
	b.vertical = true
	b.set_meta(&"right", right)
	return b


func _layout_tiles() -> void:
	# À mi-hauteur, de chaque côté du héros (qui reste au centre, jamais masqué).
	for tile: AxButton in [_tile_up, _tile_stats]:
		var right: bool = tile.get_meta(&"right") as bool
		tile.set_anchors_preset(
			Control.PRESET_CENTER_RIGHT if right else Control.PRESET_CENTER_LEFT
		)
		tile.offset_left = -(TILE_W + 30.0) if right else 30.0
		tile.offset_right = -30.0 if right else 30.0 + TILE_W
		tile.offset_top = 120.0
		tile.offset_bottom = 382.0
	_badge.offset_left = 30.0 + TILE_W - 48.0
	_badge.offset_right = _badge.offset_left + 70.0
	_badge.offset_top = 120.0 - 26.0
	_badge.offset_bottom = _badge.offset_top + 74.0


func _build_best() -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, 104)
	var rib: TextureRect = UiArt.image("brand/banner_yellow")
	rib.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rib.stretch_mode = TextureRect.STRETCH_SCALE
	c.add_child(rib)
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 130.0
	h.offset_right = -130.0
	h.offset_top = 4.0
	h.offset_bottom = -22.0
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override(&"separation", 10)
	c.add_child(h)
	h.add_child(UiArt.image("icons/trophy_s", Vector2(62, 62)))
	var l: Label = UiArt.label("", 38, UiArt.WHITE, Color("#8A4208"))
	l.name = "BestLabel"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return c


func _refresh_best() -> void:
	var w: int = SaveManager.data.best_wave
	_best.visible = w > 0
	var l: Label = _best.find_child("BestLabel", true, false) as Label
	if l != null:
		l.text = Loc.t("best_wave", [w])


func _on_save_changed() -> void:
	_wallet.count_to(SaveManager.coins())
	_refresh_best()
	_refresh_badge()


## Pastille rouge sur AMÉLIORATIONS : au moins une amélioration permanente est abordable.
func _refresh_badge() -> void:
	var n: int = 0
	for i: int in PermanentUpgrades.count():
		if SaveManager.can_buy(i):
			n += 1
	_badge.visible = n > 0
	_badge_label.text = str(n)


## Ouvre un écran modal avec un petit « coup de zoom » du décor (fluidité des transitions).
func _open_screen(screen: AxScreen) -> void:
	_root.add_child(screen)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_logo, "modulate:a", 0.0, 0.18)
	screen.closed.connect(
		func() -> void:
			var back: Tween = create_tween()
			back.tween_property(_logo, "modulate:a", 1.0, 0.25)
	)


func _animate_in() -> void:
	# Entrée en cascade : logo élastique, tuiles qui glissent depuis les côtés, ruban et JOUER qui
	# montent du bas avec rebond ; puis le bouton JOUER bat doucement.
	_logo.scale = Vector2.ZERO
	var lt: Tween = create_tween()
	lt.tween_property(_logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	_slide_in(_tile_up, Vector2(-320.0, 0.0), 0.28)
	_slide_in(_tile_stats, Vector2(320.0, 0.0), 0.38)
	_slide_in(_best, Vector2(0.0, 200.0), 0.46)
	_play.pop_in(0.56, Vector2(0.5, 0.5))
	_play.start_pulse()
	_refresh_badge()


func _slide_in(c: Control, from: Vector2, delay: float) -> void:
	var rest: Vector2 = c.position
	c.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_interval(delay)
	t.tween_callback(func() -> void: c.position = rest + from)
	t.set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, 0.16)
	t.tween_property(c, "position", rest, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_play() -> void:
	SceneLoader.go(LoadManifest.GAMEPLAY_SCENE)


func _on_back() -> bool:
	if _quit_press.press(Time.get_ticks_msec() / 1000.0):
		Diagnostics.shutdown()
		get_tree().quit()
	else:
		UIManager.toast(Loc.t("quit_hint"))
	return true
