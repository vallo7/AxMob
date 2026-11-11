class_name AxBar
extends Control
## Barre de progression « tube » : cadre sombre, remplissage coloré et traînée claire qui rattrape
## la valeur quand elle baisse (on VOIT les dégâts). `ratio` 0..1. Styles : red, green, yellow,
## blue.

@export var fill_style: String = "red":
	set(v):
		fill_style = v
		_load()
		queue_redraw()
var ratio: float = 1.0
var _ghost: float = 1.0
var _frame: StyleBoxTexture
var _fill: StyleBoxTexture
var _ghost_box: StyleBoxTexture
var _flash: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(300, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_load()


func _load() -> void:
	_frame = _box("bars/bar_frame", 28)
	_fill = _box("bars/bar_" + fill_style, 20)
	_ghost_box = _box("bars/bar_white", 20)


func _box(path: String, margin: int) -> StyleBoxTexture:
	var s: StyleBoxTexture = StyleBoxTexture.new()
	s.texture = UiArt.tex(path)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	return s


func set_ratio(r: float, animate: bool = true) -> void:
	r = clampf(r, 0.0, 1.0)
	if r < ratio and animate:
		_flash = 1.0
	ratio = r
	if r >= _ghost or not animate:
		_ghost = r
	queue_redraw()


func _process(delta: float) -> void:
	if _ghost > ratio:
		# La traînée attend un instant puis rattrape en douceur.
		_ghost = maxf(ratio, _ghost - delta * 0.55)
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		queue_redraw()


func _draw() -> void:
	if _frame == null:
		return
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var inner: Rect2 = Rect2(7, 7, size.x - 14, size.y - 16)
	if _ghost > ratio + 0.002:
		var gw: float = maxf(inner.size.x * _ghost, 0.0)
		_ghost_box.modulate_color = Color(1, 1, 1, 0.92)
		draw_style_box(_ghost_box, Rect2(inner.position, Vector2(gw, inner.size.y)))
	if ratio > 0.001:
		var w: float = maxf(inner.size.x * ratio, 26.0)
		draw_style_box(_fill, Rect2(inner.position, Vector2(w, inner.size.y)))
		if _flash > 0.0:
			_ghost_box.modulate_color = Color(1, 1, 1, 0.65 * _flash)
			draw_style_box(_ghost_box, Rect2(inner.position, Vector2(w, inner.size.y)))
