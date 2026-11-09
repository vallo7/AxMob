class_name Hud
extends Control
## HUD discret : PV, vague, temps, pièces, fenêtre de combat, bouton pause, bouton « tourelles »
## (avec pastille quand une amélioration est abordable) et overlay debug pour les tests.

signal pause_pressed
signal upgrades_pressed

const BAR_W: float = 560.0
const BAR_H: float = 38.0
const DEBUG_REFRESH: float = 0.25

var _ctx: RunContext
var _player: PlayerController
var _projectiles: ProjectileManager
var _upgrades: UpgradeManager
var _hp_fill: ColorRect
var _window_fill: ColorRect
var _wave_label: Label
var _time_label: Label
var _coins_label: Label
var _banner: Label
var _debug: Label
var _upgrade_button: Button
var _badge: Label
var _debug_timer: float = 0.0
var _banner_tween: Tween
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _flash_k: float = 0.0
var _coin_tween: Tween


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
	set_anchors_preset(Control.PRESET_FULL_RECT)
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


func _process(delta: float) -> void:
	_update_vignette(delta)
	_time_label.text = _format_time(_ctx.time)
	var window_ratio: float = _ctx.combat.remaining(_ctx.time) / _ctx.config.window_duration
	_window_fill.size.x = BAR_W * clampf(window_ratio, 0.0, 1.0)
	var affordable: int = _upgrades.affordable_count()
	_badge.visible = affordable > 0
	_badge.text = str(affordable)
	_debug_timer -= delta
	if _debug_timer <= 0.0:
		_debug_timer = DEBUG_REFRESH
		_debug.text = (
			"%d FPS (%.1f ms)\nennemis %d\nhaches %d\ndraw calls %d\nrythme %.2f\nqualité %s 3D x%.2f"
			% [
				Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				_ctx.enemies.count_living(),
				_projectiles.active_count(),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				_ctx.pacing,
				QualityManager.mode_label(),
				QualityManager.applied_scale,
			]
		)


func _build() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = preload("res://assets/shaders/ax_vignette.gdshader")
	_vignette.material = _vignette_mat
	add_child(_vignette)
	var top: float = UiKit.top_inset() + 24.0
	var width: float = get_viewport_rect().size.x
	var height: float = get_viewport_rect().size.y
	var hp_bg: ColorRect = ColorRect.new()
	hp_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	hp_bg.position = Vector2(30.0, top)
	hp_bg.size = Vector2(BAR_W, BAR_H)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.85, 0.22, 0.25)
	_hp_fill.size = Vector2(BAR_W, BAR_H)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(_hp_fill)
	var window_bg: ColorRect = ColorRect.new()
	window_bg.color = Color(0.0, 0.0, 0.0, 0.4)
	window_bg.position = Vector2(30.0, top + BAR_H + 8.0)
	window_bg.size = Vector2(BAR_W, 12.0)
	window_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window_bg)
	_window_fill = ColorRect.new()
	_window_fill.color = UiKit.ACCENT
	_window_fill.size = Vector2(0.0, 12.0)
	_window_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_bg.add_child(_window_fill)

	_wave_label = UiKit.label("VAGUE 0", 46)
	_wave_label.position = Vector2(30.0, top + BAR_H + 30.0)
	add_child(_wave_label)
	_time_label = UiKit.label("0:00", 46, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_time_label.position = Vector2(290.0, top + BAR_H + 30.0)
	_time_label.size = Vector2(200.0, 60.0)
	add_child(_time_label)
	_coins_label = UiKit.label("0", 50, Color(1.0, 0.82, 0.25), HORIZONTAL_ALIGNMENT_RIGHT)
	_coins_label.position = Vector2(620.0, top - 4.0)
	_coins_label.size = Vector2(200.0, 60.0)
	add_child(_coins_label)

	var pause_btn: Button = UiKit.button("II", Vector2(110.0, 90.0), 48)
	pause_btn.position = Vector2(width - 140.0, top - 6.0)
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause_btn)

	# Bouton d'accès aux tourelles, en bas à droite (le joystick est en bas à gauche).
	_upgrade_button = UiKit.button("TOURELLES", Vector2(320.0, 150.0), 40)
	_upgrade_button.position = Vector2(width - 350.0, height - 290.0)
	_upgrade_button.pressed.connect(func() -> void: upgrades_pressed.emit())
	add_child(_upgrade_button)
	_badge = UiKit.label("0", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_badge.add_theme_stylebox_override("normal", UiKit.button_box(Color(0.85, 0.2, 0.2)))
	_badge.position = _upgrade_button.position + Vector2(260.0, -24.0)
	_badge.size = Vector2(64.0, 60.0)
	_badge.visible = false
	add_child(_badge)

	_banner = UiKit.label("", 120, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.position = Vector2(0.0, 340.0)
	_banner.size = Vector2(width, 160.0)
	_banner.modulate.a = 0.0
	add_child(_banner)

	_debug = UiKit.label("", 30, Color(0.8, 1.0, 0.8))
	_debug.position = Vector2(30.0, top + BAR_H + 200.0)
	add_child(_debug)


func _on_player_damaged(amount: float, hp_left: float) -> void:
	_hp_fill.size.x = BAR_W * clampf(hp_left / _player.health.max_hp, 0.0, 1.0)
	if amount > 0.0:
		_flash_k = 1.0
		_pop(_hp_fill.get_parent() as Control, 1.06)


## Vignette : flash rouge à chaque coup subi + pulsation douce quand les PV sont bas.
func _update_vignette(delta: float) -> void:
	_flash_k = maxf(_flash_k - delta * 2.4, 0.0)
	var frac: float = _ctx.player_hp_fraction
	var low: float = 0.0
	if _ctx.player_alive and frac < 0.3:
		low = 0.22 * (1.0 - frac / 0.3) * (0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.0055))
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
	_coins_label.text = str(total)


## Une pièce cosmétique arrive au joueur : le compteur rebondit (plus fort sur les séries).
func _on_coin_collected(streak: int) -> void:
	_pop(_coins_label, 1.0 + 0.10 * minf(float(streak), 4.0) * 0.5 + 0.08)


func _on_wave_started(wave: int) -> void:
	_wave_label.text = "VAGUE %d" % wave
	_pop(_wave_label, 1.35)
	_show_banner("VAGUE %d" % wave, UiKit.ACCENT, 120, 0.5)


func _on_boss_warning(_wave: int, seconds: float, _position: Vector2) -> void:
	_show_banner("BOSS !", Color(1.0, 0.25, 0.2), 150, seconds)


func _on_boss_phase(_id: int, phase: int) -> void:
	_show_banner("PHASE %d" % phase, Color(1.0, 0.35, 0.2), 110, 0.6)


func _on_boss_defeated(_id: int, reward: int) -> void:
	_show_banner("BOSS VAINCU  +%d" % reward, Color(1.0, 0.82, 0.25), 80, 1.6)


func _show_banner(text: String, color: Color, font_size: int, hold: float) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.add_theme_font_size_override("font_size", font_size)
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


static func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
