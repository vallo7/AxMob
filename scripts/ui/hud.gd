class_name Hud
extends Control
## HUD de partie (phase 6, style « bonbon ») : barre de PV avec cœur, fenêtre de combat, vague,
## temps, pièces, bouton pause et accès aux tourelles (pastille rouge quand une amélioration est
## abordable). Annonces sur rubans (vague bleu, boss rouge, boss vaincu jaune). Discret : il ne doit
## pas masquer l'action. L'overlay de mesures n'apparaît que si le réglage « FPS » est actif.

signal pause_pressed
signal upgrades_pressed

const BAR_W: float = 470.0
const DEBUG_REFRESH: float = 0.25
const BANNER_INK: Dictionary = {
	"blue": Color("#0F3C8A"),
	"red": Color("#7E1410"),
	"yellow": Color("#9A5200"),
}

var _ctx: RunContext
var _player: PlayerController
var _projectiles: ProjectileManager
var _upgrades: UpgradeManager
var _hp_bar: AxBar
var _heart: TextureRect
var _window_bar: AxBar
var _wave_pill: AxPill
var _time_pill: AxPill
var _coin_pill: AxPill
var _banner: Control
var _banner_art: TextureRect
var _banner_label: Label
var _debug: Label
var _upgrade_button: AxButton
var _badge: Label
var _badge_bg: TextureRect
var _debug_timer: float = 0.0
var _banner_tween: Tween
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _flash_k: float = 0.0
var _last_time_text: String = ""


func setup(
	ctx: RunContext,
	player: PlayerController,
	projectiles: ProjectileManager,
	upgrades: UpgradeManager
) -> void:
	_ctx = ctx
	_player = player
	_projectiles = projectiles
	_upgrades = upgrades
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.boss_warning.connect(_on_boss_warning)
	EventBus.boss_phase_changed.connect(_on_boss_phase)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	_on_player_damaged(0.0, _player.health.hp)
	_hp_bar.set_ratio(clampf(_player.health.hp / _player.health.max_hp, 0.0, 1.0), false)
	_coin_pill.count_to(_ctx.coins, true)


func _process(delta: float) -> void:
	_update_vignette(delta)
	var t: String = _format_time(_ctx.time)
	if t != _last_time_text:
		_last_time_text = t
		_time_pill.set_text(t, false)
	var window_ratio: float = _ctx.combat.remaining(_ctx.time) / _ctx.config.window_duration
	_window_bar.set_ratio(clampf(window_ratio, 0.0, 1.0), false)
	var affordable: int = _upgrades.affordable_count()
	_badge.visible = affordable > 0
	_badge_bg.visible = affordable > 0
	_badge.text = str(affordable)
	_debug_timer -= delta
	if _debug.visible and _debug_timer <= 0.0:
		_debug_timer = DEBUG_REFRESH
		_debug.text = (
			"%d FPS (%.1f ms)\nennemis %d · haches %d\ndraw calls %d\n%s 3D x%.2f\nmém. vidéo %.0f Mo"
			% [
				Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				_ctx.enemies.count_living(),
				_projectiles.active_count(),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				QualityManager.mode_label(),
				QualityManager.applied_scale,
				Diagnostics.video_mb,
			]
		)


func _build() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = preload("res://assets/shaders/ax_vignette.gdshader")
	_vignette.material = _vignette_mat
	add_child(_vignette)
	var top: float = UiKit.top_inset() + 22.0
	var width: float = get_viewport_rect().size.x
	var height: float = get_viewport_rect().size.y

	# PV : cœur + tube rouge.
	_hp_bar = AxBar.new()
	_hp_bar.fill_style = "red"
	_hp_bar.position = Vector2(92.0, top + 14.0)
	_hp_bar.size = Vector2(BAR_W, 58.0)
	add_child(_hp_bar)
	_heart = UiArt.image("icons/heart", Vector2(104, 104))
	_heart.position = Vector2(24.0, top - 6.0)
	_heart.size = Vector2(104, 104)
	_heart.pivot_offset = _heart.size * 0.5
	add_child(_heart)
	# Fenêtre de combat : fin tube jaune sous la barre de PV (reste d'activation des tourelles).
	_window_bar = AxBar.new()
	_window_bar.fill_style = "yellow"
	_window_bar.position = Vector2(112.0, top + 78.0)
	_window_bar.size = Vector2(BAR_W - 40.0, 34.0)
	add_child(_window_bar)

	_wave_pill = AxPill.make("icons/skull", 300.0, 84.0, 42)
	_wave_pill.position = Vector2(24.0, top + 128.0)
	_wave_pill.set_text(Loc.t("wave_fmt", [0]), false)
	add_child(_wave_pill)
	_time_pill = AxPill.make("icons/clock", 230.0, 84.0, 42)
	_time_pill.position = Vector2(340.0, top + 128.0)
	_time_pill.set_text("0:00", false)
	add_child(_time_pill)

	_coin_pill = AxPill.make("icons/coin", 270.0, 92.0, 48)
	_coin_pill.position = Vector2(width - 112.0 - 24.0 - 270.0 - 8.0, top + 2.0)
	_coin_pill.set_color(UiArt.GOLD)
	add_child(_coin_pill)
	var pause_btn: AxRoundButton = AxRoundButton.make("blue", "pause", 104.0)
	pause_btn.position = Vector2(width - 104.0 - 24.0, top - 2.0)
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause_btn)

	# Accès aux tourelles, en bas à droite (le joystick est en bas à gauche).
	_upgrade_button = AxButton.make(Loc.t("turrets"), "yellow", Vector2(360.0, 138.0), 40, "axe")
	_upgrade_button.position = Vector2(width - 384.0, height - 300.0)
	_upgrade_button.pressed.connect(func() -> void: upgrades_pressed.emit())
	add_child(_upgrade_button)
	_badge_bg = UiArt.image("misc/badge_red", Vector2(76, 80))
	_badge_bg.position = _upgrade_button.position + Vector2(318.0, -34.0)
	_badge_bg.size = Vector2(76, 80)
	_badge_bg.visible = false
	add_child(_badge_bg)
	_badge = UiArt.label("0", 38, UiArt.WHITE, Color("#7E1410"))
	_badge.position = _badge_bg.position
	_badge.size = _badge_bg.size
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.visible = false
	add_child(_badge)

	# Ruban d'annonce (vague, boss).
	_banner = Control.new()
	_banner.position = Vector2((width - 880.0) * 0.5, 330.0)
	_banner.size = Vector2(880.0, 292.0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_art = UiArt.image("brand/banner_blue")
	_banner_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_art.stretch_mode = TextureRect.STRETCH_SCALE
	_banner.add_child(_banner_art)
	_banner_label = UiArt.label("", 96, UiArt.WHITE, Color("#0F3C8A"))
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_label.offset_left = 120.0
	_banner_label.offset_right = -120.0
	_banner_label.offset_top = 8.0
	_banner_label.offset_bottom = -52.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)

	_debug = UiArt.label("", 28, Color(0.8, 1.0, 0.8), Color(0, 0, 0, 0.9), 5)
	_debug.position = Vector2(30.0, top + 240.0)
	_debug.visible = UserSettings.show_fps()
	add_child(_debug)


func _on_player_damaged(amount: float, hp_left: float) -> void:
	_hp_bar.set_ratio(clampf(hp_left / _player.health.max_hp, 0.0, 1.0))
	if amount > 0.0:
		_flash_k = 1.0
		_pop(_heart, 1.3)


## Vignette : flash rouge à chaque coup subi + pulsation douce quand les PV sont bas.
func _update_vignette(delta: float) -> void:
	_flash_k = maxf(_flash_k - delta * 2.4, 0.0)
	var frac: float = _ctx.player_hp_fraction
	var low: float = 0.0
	if _ctx.player_alive and frac < 0.3:
		low = 0.22 * (1.0 - frac / 0.3) * (0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.0055))
		# Le cœur bat quand les PV sont bas.
		_heart.scale = Vector2.ONE * (1.0 + 0.08 * maxf(sin(Time.get_ticks_msec() * 0.011), 0.0))
	elif _heart.scale != Vector2.ONE and not _heart.has_meta(&"popping"):
		_heart.scale = Vector2.ONE
	_vignette_mat.set_shader_parameter(&"intensity", maxf(_flash_k * 0.85, low))


## Petit « pop » élastique d'un élément d'interface.
func _pop(node: Control, amount: float) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * amount
	var tw: Tween = create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _on_coins_changed(total: int) -> void:
	_coin_pill.count_to(total)


## Une pièce cosmétique arrive au joueur : le compteur rebondit.
func _on_coin_collected(streak: int) -> void:
	_pop(_coin_pill, 1.06 + 0.03 * minf(float(streak), 4.0))


func _on_wave_started(wave: int) -> void:
	_wave_pill.set_text(Loc.t("wave_fmt", [wave]))
	_show_banner(Loc.t("wave_fmt", [wave]), "blue", 96, 0.5)


func _on_boss_warning(_wave: int, seconds: float, _position: Vector2) -> void:
	_show_banner(Loc.t("boss_alert"), "red", 120, seconds)


func _on_boss_phase(_id: int, phase: int) -> void:
	_show_banner(Loc.t("phase_fmt", [phase]), "red", 96, 0.6)


func _on_boss_defeated(_id: int, reward: int) -> void:
	_show_banner("%s  +%d" % [Loc.t("boss_down"), reward], "yellow", 62, 1.6)


func _show_banner(text: String, kind: String, font_size: int, hold: float) -> void:
	_banner_art.texture = UiArt.tex("brand/banner_" + kind)
	UiArt.style_label(_banner_label, font_size, UiArt.WHITE, BANNER_INK[kind] as Color)
	_banner_label.text = text
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	# Entrée élastique (rebond) puis maintien et fondu.
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 0.45
	_banner_tween = create_tween()
	(
		_banner_tween
		. tween_property(_banner, "scale", Vector2.ONE, 0.38)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


## Rend l'overlay de mesures visible/invisible (Réglages).
func set_debug_visible(on: bool) -> void:
	_debug.visible = on


static func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 60, total % 60]
