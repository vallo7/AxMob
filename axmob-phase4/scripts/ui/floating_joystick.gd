class_name FloatingJoystick
extends Control
## Joystick flottant : il apparaît là où le pouce se pose (moitié basse de l'écran), suit le
## pouce au-delà de son rayon, zone morte configurable. Fonctionne à la souris sur PC
## (émulation tactile activée dans les réglages du projet).

var vector: Vector2 = Vector2.ZERO
var enabled: bool = true
## Zones d'écran (panneaux ouverts) où un toucher ne démarre jamais le joystick.
var exclusion_rects: Array[Rect2] = []

var _cfg: GameConfig
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _thumb: Vector2 = Vector2.ZERO


func setup(cfg: GameConfig) -> void:
	_cfg = cfg
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not enabled or _cfg == null:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1 and _in_zone(touch.position):
				_touch_index = touch.index
				_origin = touch.position
				_thumb = touch.position
				_refresh()
		elif touch.index == _touch_index:
			release()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			_thumb = drag.position
			var offset: Vector2 = _thumb - _origin
			if offset.length() > _cfg.joystick_radius_px:
				_origin = _thumb - offset.normalized() * _cfg.joystick_radius_px
			_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_PAUSED:
		release()


func release() -> void:
	_touch_index = -1
	vector = Vector2.ZERO
	queue_redraw()


func _in_zone(p: Vector2) -> bool:
	for rect: Rect2 in exclusion_rects:
		if rect.has_point(p):
			return false
	return p.y > get_viewport_rect().size.y * _cfg.joystick_zone_top


func _refresh() -> void:
	vector = JoystickMath.from_offset(
		_thumb - _origin, _cfg.joystick_radius_px, _cfg.joystick_deadzone
	)
	queue_redraw()


func _draw() -> void:
	if _cfg == null:
		return
	var r: float = _cfg.joystick_radius_px
	if _touch_index == -1:
		var idle: Vector2 = Vector2(r + 60.0, get_viewport_rect().size.y - r - 160.0)
		draw_arc(idle, r, 0.0, TAU, 48, Color(1, 1, 1, 0.16), 6.0)
		draw_circle(idle, r * 0.38, Color(1, 1, 1, 0.1))
		return
	draw_circle(_origin, r, Color(1, 1, 1, 0.1))
	draw_arc(_origin, r, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 6.0)
	var knob: Vector2 = _origin + (_thumb - _origin).limit_length(r)
	draw_circle(knob, r * 0.4, Color(0.93, 0.47, 0.12, 0.75))
