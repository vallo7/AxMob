class_name Hud
extends Control
## HUD discret (haut d'écran) : PV, vague, temps, pièces, fenêtre de combat, bouton pause.
## Plus un overlay debug (FPS, ennemis, haches, draw calls) pour les tests sur téléphone.

signal pause_pressed

const BAR_W: float = 560.0
const BAR_H: float = 38.0
const DEBUG_REFRESH: float = 0.25

var _ctx: RunContext
var _player: PlayerController
var _projectiles: ProjectileManager
var _hp_fill: ColorRect
var _window_fill: ColorRect
var _wave_label: Label
var _time_label: Label
var _coins_label: Label
var _banner: Label
var _debug: Label
var _debug_timer: float = 0.0
var _banner_tween: Tween


func setup(ctx: RunContext, player: PlayerController, projectiles: ProjectileManager) -> void:
	_ctx = ctx
	_player = player
	_projectiles = projectiles
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.wave_started.connect(_on_wave_started)
	_on_player_damaged(0.0, _player.health.hp)


func _process(delta: float) -> void:
	_time_label.text = _format_time(_ctx.time)
	var window_ratio: float = _ctx.combat.remaining(_ctx.time) / _ctx.config.window_duration
	_window_fill.size.x = BAR_W * clampf(window_ratio, 0.0, 1.0)
	_debug_timer -= delta
	if _debug_timer <= 0.0:
		_debug_timer = DEBUG_REFRESH
		_debug.text = (
			"%d FPS\nennemis %d\nhaches %d\ndraw calls %d"
			% [
				Engine.get_frames_per_second(),
				_ctx.enemies.count_living(),
				_projectiles.active_count(),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			]
		)


func _build() -> void:
	var top: float = UiKit.top_inset() + 24.0
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
	pause_btn.position = Vector2(get_viewport_rect().size.x - 140.0, top - 6.0)
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause_btn)

	_banner = UiKit.label("", 120, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.position = Vector2(0.0, 560.0)
	_banner.size = Vector2(get_viewport_rect().size.x, 160.0)
	_banner.modulate.a = 0.0
	add_child(_banner)

	_debug = UiKit.label("", 30, Color(0.8, 1.0, 0.8))
	_debug.position = Vector2(30.0, top + BAR_H + 120.0)
	add_child(_debug)


func _on_player_damaged(_amount: float, hp_left: float) -> void:
	_hp_fill.size.x = BAR_W * clampf(hp_left / _player.health.max_hp, 0.0, 1.0)


func _on_coins_changed(total: int) -> void:
	_coins_label.text = str(total)


func _on_wave_started(wave: int) -> void:
	_wave_label.text = "VAGUE %d" % wave
	_banner.text = "VAGUE %d" % wave
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.5)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


static func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
