class_name EnemyBars
extends Control
## Barres de vie des ennemis, dessinées en 2D par-dessus la vue 3D (un seul élément de canevas,
## donc peu d'appels de dessin). Une barre apparaît quand l'ennemi est touché (et reste
## ~2,5 s) ; elles sont toujours visibles pour les élites et le boss (bar_always).

const BAR_H: float = 12.0
const MIN_HALF_W: float = 18.0
const LIFT: float = 0.4
const ELITE_COLOR: Color = Color(1.0, 0.8, 0.2)
const NORMAL_COLOR: Color = Color(0.9, 0.25, 0.28)

var _ctx: RunContext
var _camera: Camera3D


func setup(ctx: RunContext, camera: Camera3D) -> void:
	_ctx = ctx
	_camera = camera
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _ctx == null:
		return
	for e: Enemy in _ctx.enemies.slots:
		if not e.is_hittable() or e.is_boss():
			continue  # la barre du boss est en haut d'écran (BossBar)
		if not (e.data.bar_always or _ctx.time < e.bar_until):
			continue
		var top: Vector3 = Vector3(e.pos.x, e.data.height + LIFT, e.pos.y)
		if _camera.is_position_behind(top):
			continue
		var p: Vector2 = _camera.unproject_position(top)
		var edge: Vector2 = _camera.unproject_position(top + Vector3(e.data.radius, 0.0, 0.0))
		var half_w: float = maxf(absf(edge.x - p.x) * 1.25, MIN_HALF_W)
		var frac: float = clampf(e.health.fraction(), 0.0, 1.0)
		var rect: Rect2 = Rect2(p.x - half_w, p.y - BAR_H, half_w * 2.0, BAR_H)
		draw_rect(rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.7))
		var color: Color = ELITE_COLOR if e.data.bar_always else NORMAL_COLOR
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * frac, rect.size.y)), color)
