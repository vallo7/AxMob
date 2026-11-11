class_name AxPill
extends Control
## Pastille de HUD : capsule sombre + icône + texte (PV, vague, temps, pièces). `set_text()` fait
## « rebondir » la pastille quand la valeur change ; `count_to()` anime un compteur de pièces.

var _icon: TextureRect
var _label: Label
var _value: float = 0.0
var _shown: int = 0
var _tween: Tween
var _bump: Tween


static func make(icon_path: String, min_w: float, h: float = 84.0, font: int = 44) -> AxPill:
	var p: AxPill = AxPill.new()
	p.custom_minimum_size = Vector2(min_w, h)
	p._build(icon_path, font)
	return p


func _build(icon_path: String, font: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiArt.nine("panels/plate_dark", 46, 40, 46, 46))
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -22.0
	row.offset_bottom = -6.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = UiArt.image(
		icon_path, Vector2(custom_minimum_size.y * 0.82, custom_minimum_size.y * 0.82)
	)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_label = UiArt.label("", font, UiArt.WHITE, UiArt.INK)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_label)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func set_icon(path: String) -> void:
	_icon.texture = UiArt.tex(path)


func text() -> String:
	return _label.text


func set_text(t: String, bump: bool = true) -> void:
	if _label.text == t:
		return
	_label.text = t
	if bump:
		pop()


func set_color(c: Color) -> void:
	_label.add_theme_color_override(&"font_color", c)


func pop() -> void:
	if _bump != null and _bump.is_valid():
		_bump.kill()
	scale = Vector2(1.12, 1.12)
	_bump = create_tween()
	_bump.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


## Compteur qui défile vers `target` (pièces). `instant` : saute directement.
func count_to(target: int, instant: bool = false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant or target == _shown:
		_shown = target
		_label.text = str(target)
		return
	var from: int = _shown
	_tween = create_tween()
	_tween.tween_method(
		func(v: float) -> void:
			_shown = int(round(v))
			_label.text = str(_shown),
		float(from),
		float(target),
		clampf(absf(float(target - from)) * 0.01 + 0.25, 0.25, 0.8)
	)
	_tween.tween_callback(func() -> void: _shown = target)
	if target > from:
		pop()
