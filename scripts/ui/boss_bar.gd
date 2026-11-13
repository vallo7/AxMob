class_name BossBar
extends Control
## Barre de vie dédiée du boss (haut de l'écran) et avertissement d'apparition : bandeau,
## repère directionnel vers le point d'apparition et liseré rouge (≈ 2 s avant le boss).

const BAR_W: float = 1020.0
const BAR_H: float = 36.0
const MARKER_MARGIN: float = 90.0
const FONT_SIZE: int = 30

var _ctx: RunContext
var _camera: Camera3D
var _warning_left: float = 0.0
var _warning_pos: Vector2 = Vector2.ZERO
var _phase: int = 1
var _flash: float = 0.0
var _top: float = 0.0


func setup(ctx: RunContext, camera: Camera3D) -> void:
	_ctx = ctx
	_camera = camera
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sous le bloc du HUD (PV, vague, temps) : jamais sous ses éléments (phase 7).
	_top = UiKit.top_inset() + 22.0 + 128.0 + 84.0 + 34.0
	EventBus.boss_warning.connect(_on_warning)
	EventBus.boss_spawned.connect(func(_id: int) -> void: _warning_left = 0.0)
	EventBus.boss_phase_changed.connect(_on_phase)


func _on_warning(_wave: int, seconds: float, position: Vector2) -> void:
	_warning_left = seconds
	_warning_pos = position


func _on_phase(_id: int, phase: int) -> void:
	_phase = phase
	_flash = 0.5


func _process(delta: float) -> void:
	_warning_left = maxf(_warning_left - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _ctx == null:
		return
	if _warning_left > 0.0:
		_draw_warning()
	if _ctx.boss_id >= 0:
		_draw_bar(_ctx.enemies.slots[_ctx.boss_id])


func _draw_bar(e: Enemy) -> void:
	var x: float = (get_viewport_rect().size.x - BAR_W) * 0.5
	var back: Rect2 = Rect2(x, _top, BAR_W, BAR_H)
	draw_rect(back.grow(3.0), Color(0.0, 0.0, 0.0, 0.75))
	var frac: float = clampf(e.health.fraction(), 0.0, 1.0)
	var color: Color = Color(0.85, 0.15, 0.2).lerp(Color.WHITE, _flash)
	draw_rect(Rect2(back.position, Vector2(BAR_W * frac, BAR_H)), color)
	for threshold: float in e.boss.data.phase_thresholds:
		var tx: float = x + BAR_W * threshold
		draw_rect(Rect2(tx - 2.0, _top - 4.0, 4.0, BAR_H + 8.0), Color(1.0, 1.0, 1.0, 0.8))
	var label: String = "%s  ·  PHASE %d" % [e.data.display_name.to_upper(), e.boss.phase]
	_text(label, Vector2(x, _top + BAR_H - 6.0), BAR_W, Color.WHITE)


func _draw_warning() -> void:
	var size_v: Vector2 = get_viewport_rect().size
	var pulse: float = 0.5 + 0.5 * sin(_warning_left * 14.0)
	var edge: Color = Color(1.0, 0.1, 0.1, 0.25 + 0.3 * pulse)
	var t: float = 26.0
	draw_rect(Rect2(0.0, 0.0, size_v.x, t), edge)
	draw_rect(Rect2(0.0, size_v.y - t, size_v.x, t), edge)
	draw_rect(Rect2(0.0, 0.0, t, size_v.y), edge)
	draw_rect(Rect2(size_v.x - t, 0.0, t, size_v.y), edge)
	var world: Vector3 = Planar.to3(_warning_pos)
	var screen: Vector2 = _camera.unproject_position(world)
	if _camera.is_position_behind(world):
		screen = Vector2(size_v.x * 0.5, size_v.y * 0.5)
	var marker: Vector2 = Vector2(
		clampf(screen.x, MARKER_MARGIN, size_v.x - MARKER_MARGIN),
		clampf(screen.y, MARKER_MARGIN + 200.0, size_v.y - MARKER_MARGIN - 300.0)
	)
	draw_circle(marker, 52.0, Color(0.9, 0.1, 0.1, 0.85))
	draw_arc(marker, 52.0, 0.0, TAU, 32, Color.WHITE, 5.0)
	_text("!", marker + Vector2(-50.0, 22.0), 100.0, Color.WHITE, 72)


func _text(
	text: String, pos: Vector2, width: float, color: Color, font_size: int = FONT_SIZE
) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(
		font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 8, Color.BLACK
	)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
