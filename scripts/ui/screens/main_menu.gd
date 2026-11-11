class_name MainMenu
extends Node3D
## Menu principal (cahier §10.2) : le héros en 3D sur la plage (animation « idle », caméra qui
## flotte doucement), logo, solde de pièces, JOUER, AMÉLIORATIONS, STATISTIQUES et RÉGLAGES.
## Tous les boutons ouvrent un vrai écran ou lancent une vraie partie (aucun bouton décoratif).
## Bouton retour du téléphone : « Appuyez encore pour quitter » (double appui).

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


func _build_world() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("#1E8FF0")
	mat.sky_horizon_color = Color("#BDEBFF")
	mat.ground_horizon_color = Color("#BDEBFF")
	mat.ground_bottom_color = Color("#6FD0F0")
	mat.sky_curve = 0.18
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.86, 0.96)
	env.ambient_light_energy = 0.6
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 32.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 0.9
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
	_camera = Camera3D.new()
	_camera.fov = 44.0
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
	_wallet = AxPill.make("icons/coin", 300.0, 96.0, 52)
	_wallet.position = Vector2(24.0, top)
	_wallet.set_color(UiArt.GOLD)
	_wallet.count_to(SaveManager.coins(), true)
	_root.add_child(_wallet)
	var gear: AxRoundButton = AxRoundButton.make("blue", "gear", 112.0)
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -136.0
	gear.offset_right = -24.0
	gear.offset_top = top - 6.0
	gear.offset_bottom = top + 116.0
	gear.pressed.connect(func() -> void: _root.add_child(SettingsScreen.new()))
	_root.add_child(gear)

	_logo = UiArt.image("brand/logo")
	_logo.anchor_left = 0.5
	_logo.anchor_right = 0.5
	_logo.offset_left = -400.0
	_logo.offset_right = 400.0
	_logo.offset_top = top + 130.0
	_logo.offset_bottom = top + 130.0 + 530.0
	_logo.pivot_offset = Vector2(400.0, 265.0)
	_logo_base_y = _logo.position.y
	_root.add_child(_logo)

	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 90.0
	bottom.offset_right = -90.0
	bottom.offset_top = -640.0
	bottom.offset_bottom = -110.0
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override(&"separation", 26)
	_root.add_child(bottom)

	_best = _build_best()
	bottom.add_child(_best)
	_play = AxButton.make(Loc.t("play"), "green", Vector2(0, 200), 84, "play")
	_play.pressed.connect(_on_play)
	bottom.add_child(_play)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 22)
	bottom.add_child(row)
	var up: AxButton = AxButton.make(Loc.t("upgrades"), "yellow", Vector2(0, 132), 34, "axe")
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.pressed.connect(func() -> void: _root.add_child(UpgradesScreen.new()))
	row.add_child(up)
	var st: AxButton = AxButton.make(Loc.t("statistics"), "blue", Vector2(0, 132), 34, "chart")
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.pressed.connect(func() -> void: _root.add_child(StatsScreen.new()))
	row.add_child(st)
	_entrance = [_best, _play, row]
	_refresh_best()

	var ver: Label = UiArt.label(
		"v" + str(ProjectSettings.get_setting("application/config/version", "dev")),
		26,
		Color(1, 1, 1, 0.75),
		UiArt.INK
	)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 24.0
	ver.offset_top = -64.0
	ver.offset_bottom = -20.0
	_root.add_child(ver)


func _build_best() -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, 112)
	var rib: TextureRect = UiArt.image("brand/banner_yellow")
	rib.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rib.stretch_mode = TextureRect.STRETCH_SCALE
	c.add_child(rib)
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 130.0
	h.offset_right = -130.0
	h.offset_top = 4.0
	h.offset_bottom = -24.0
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override(&"separation", 10)
	c.add_child(h)
	h.add_child(UiArt.image("icons/trophy_s", Vector2(66, 66)))
	var l: Label = UiArt.label("", 40, UiArt.WHITE, Color("#9A5200"))
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


func _animate_in() -> void:
	_logo.scale = Vector2.ZERO
	var lt: Tween = create_tween()
	lt.tween_property(_logo, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	for i: int in _entrance.size():
		var c: Control = _entrance[i]
		c.modulate.a = 0.0
		var t: Tween = create_tween()
		t.tween_interval(0.25 + 0.1 * float(i))
		t.tween_property(c, "modulate:a", 1.0, 0.2)
	_play.start_pulse()


func _on_play() -> void:
	SceneLoader.go(LoadManifest.GAMEPLAY_SCENE)


func _on_back() -> bool:
	if _quit_press.press(Time.get_ticks_msec() / 1000.0):
		Diagnostics.shutdown()
		get_tree().quit()
	else:
		UIManager.toast(Loc.t("quit_hint"))
	return true
