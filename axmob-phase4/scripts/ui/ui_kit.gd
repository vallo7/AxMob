class_name UiKit
extends RefCounted
## Petits utilitaires d'interface (prototype). Style sobre, lisible sur 1080 px de large.

const TEXT: Color = Color(0.95, 0.94, 0.9)
const ACCENT: Color = Color(0.93, 0.47, 0.12)
const PANEL: Color = Color(0.1, 0.11, 0.14, 0.92)


static func label(
	text: String,
	font_size: int,
	color: Color = TEXT,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	l.add_theme_constant_override("outline_size", maxi(font_size / 8, 2))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, min_size: Vector2, font_size: int = 44) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_stylebox_override("normal", _box(Color(0.2, 0.22, 0.28)))
	b.add_theme_stylebox_override("hover", _box(Color(0.26, 0.28, 0.35)))
	b.add_theme_stylebox_override("pressed", _box(ACCENT))
	b.add_theme_stylebox_override("focus", _box(Color(0.2, 0.22, 0.28)))
	return b


static func panel_box() -> StyleBoxFlat:
	return _box(PANEL, 28)


## Fond de bouton d'une couleur donnée (états normal / inactif des cartes).
static func button_box(color: Color) -> StyleBoxFlat:
	return _box(color)


static func _box(color: Color, radius: int = 18) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 24.0
	s.content_margin_right = 24.0
	s.content_margin_top = 14.0
	s.content_margin_bottom = 14.0
	return s


## Marge haute à respecter (encoche / barre d'état), convertie en pixels du viewport.
static func top_inset() -> float:
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window_w: int = maxi(DisplayServer.window_get_size().x, 1)
	var viewport_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	return float(safe.position.y) * viewport_w / float(window_w)
