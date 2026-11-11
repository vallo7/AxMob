class_name AxSlider
extends Control
## Curseur à crans (0..steps) : piste sombre, remplissage jaune, pastille. Glisser ou toucher.
## `value_changed(step)` n'est émis que si le cran change.

signal value_changed(step: int)

@export var steps: int = 10
var value: int = 5:
	set(v):
		value = clampi(v, 0, steps)
		queue_redraw()

var _track: StyleBoxTexture
var _fill: StyleBoxTexture
var _knob: Texture2D


func _init() -> void:
	custom_minimum_size = Vector2(420, 72)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_track = StyleBoxTexture.new()
	_track.texture = UiArt.tex("bars/slider_track")
	_track.texture_margin_left = 22
	_track.texture_margin_right = 22
	_fill = StyleBoxTexture.new()
	_fill.texture = UiArt.tex("bars/bar_yellow")
	_fill.texture_margin_left = 20
	_fill.texture_margin_right = 20
	_knob = UiArt.tex("bars/knob_yellow")


func _pad() -> float:
	return 34.0


func _draw() -> void:
	if _track == null:
		return
	var h: float = 40.0
	var y: float = (size.y - h) * 0.5
	draw_style_box(_track, Rect2(0, y, size.x, h))
	var span: float = size.x - _pad() * 2.0
	var kx: float = _pad() + span * (float(value) / float(maxi(steps, 1)))
	if value > 0:
		draw_style_box(_fill, Rect2(6, y + 6, maxf(kx - 6, 24.0), h - 12))
	var ks: Vector2 = Vector2(64, 70)
	draw_texture_rect(_knob, Rect2(kx - ks.x * 0.5, (size.y - ks.y) * 0.5, ks.x, ks.y), false)


func _gui_input(event: InputEvent) -> void:
	var pos: Vector2 = Vector2.ZERO
	var take: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		pos = (event as InputEventMouseButton).position
		take = true
	elif (
		event is InputEventMouseMotion
		and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	):
		pos = (event as InputEventMouseMotion).position
		take = true
	if not take:
		return
	var span: float = maxf(size.x - _pad() * 2.0, 1.0)
	var step: int = clampi(int(round((pos.x - _pad()) / span * float(steps))), 0, steps)
	if step != value:
		value = step
		value_changed.emit(step)
	accept_event()
