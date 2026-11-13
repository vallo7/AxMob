class_name FloatingJoystick
extends Control
## Joystick flottant : il apparaît là où le pouce se pose (moitié basse de l'écran), suit le
## pouce au-delà de son rayon, zone morte configurable. Fonctionne à la souris sur PC
## (émulation tactile activée dans les réglages du projet).

var vector: Vector2 = Vector2.ZERO
var enabled: bool = true
## Zones d'écran (panneaux ouverts) où un toucher ne démarre jamais le joystick.
var exclusion_rects: Array[Rect2] = []
## Zones calculées à la demande (la barre des tourelles : sa taille n'est connue qu'après mise en
## page).
var dynamic_exclusions: Array[Callable] = []

var _cfg: GameConfig
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _thumb: Vector2 = Vector2.ZERO
var _shown: float = 0.0


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
			if offset.length() > _radius():
				_origin = _thumb - offset.normalized() * _radius()
			_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_PAUSED:
		release()


func release() -> void:
	_touch_index = -1
	vector = Vector2.ZERO
	_thumb = _origin
	queue_redraw()


func _in_zone(p: Vector2) -> bool:
	for rect: Rect2 in exclusion_rects:
		if rect.has_point(p):
			return false
	for provider: Callable in dynamic_exclusions:
		if (provider.call() as Rect2).has_point(p):
			return false
	return p.y > get_viewport_rect().size.y * _cfg.joystick_zone_top


func _refresh() -> void:
	vector = JoystickMath.from_offset(_thumb - _origin, _radius(), _cfg.joystick_deadzone)
	queue_redraw()


func _process(delta: float) -> void:
	# Phase 7 : AUCUN repère au repos. Le joystick apparaît (fondu + petit rebond) sous le pouce et
	# s'efface en douceur au relâchement, à l'endroit où il était.
	var target: float = 1.0 if _touch_index != -1 else 0.0
	var speed: float = 14.0 if target > _shown else 8.0
	var before: float = _shown
	_shown = move_toward(_shown, target, delta * speed)
	if _shown != before or _touch_index != -1:
		queue_redraw()


## Visibilité 0..1 (tests : 0 tant que le pouce n'est pas posé).
func visibility() -> float:
	return _shown


func _draw() -> void:
	if _cfg == null or _shown <= 0.01:
		return
	var r: float = _radius()
	var base: Texture2D = UiArt.tex("misc/joy_base")
	var knob_tex: Texture2D = UiArt.tex("misc/joy_knob")
	var pop: float = 0.82 + 0.18 * ease(_shown, -1.8) if _touch_index != -1 else 0.9 + 0.1 * _shown
	var rr: float = r * pop
	draw_texture_rect(
		base,
		Rect2(_origin - Vector2.ONE * rr, Vector2.ONE * rr * 2.0),
		false,
		Color(1, 1, 1, 0.9 * _shown)
	)
	var knob: Vector2 = _origin + (_thumb - _origin).limit_length(r)
	draw_texture_rect(
		knob_tex,
		Rect2(knob - Vector2(0.45, 0.47) * rr, Vector2(0.9, 0.94) * rr),
		false,
		Color(1, 1, 1, _shown)
	)


## Rayon effectif : plus la sensibilité est haute, plus la course du pouce est courte.
func _radius() -> float:
	return _cfg.joystick_radius_px / UserSettings.joystick_sensitivity()
