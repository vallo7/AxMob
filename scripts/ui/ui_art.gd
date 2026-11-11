class_name UiArt
extends RefCounted
## Accès centralisé aux éléments graphiques d'interface (assets/ui/), à la police et à la palette.
## Les textures sont chargées à la demande puis gardées (une seule instance par fichier).

const BASE: String = "res://assets/ui/"
const FONT_PATH: String = "res://assets/fonts/LilitaOne-Regular.ttf"

# Palette de l'interface (celle des éléments fournis : bleu ciel, jaune/orange, rouge, pierre).
const INK: Color = Color("#1B2554")
const INK_SOFT: Color = Color("#27357C")
const WHITE: Color = Color("#FFFFFF")
const CREAM: Color = Color("#FFF3D6")
const GOLD: Color = Color("#FFD43B")
const ORANGE: Color = Color("#FF9A1A")
const SKY: Color = Color("#3FA9FF")
const RED: Color = Color("#F0362C")
const GREEN: Color = Color("#34C759")
const TEXT_DARK: Color = Color("#2A3A86")
const TEXT_MUTED: Color = Color("#6C7AB8")

## Couleur du contour du texte posé sur chaque style de bouton (teinte sombre de la lèvre).
const BUTTON_INK: Dictionary = {
	"green": Color("#14672A"),
	"blue": Color("#0F3C8A"),
	"yellow": Color("#9A5200"),
	"red": Color("#7E1410"),
	"purple": Color("#40208A"),
	"grey": Color("#4F5A70"),
}

static var _cache: Dictionary = {}
static var _font: Font = null


## Texture par chemin relatif sans extension (« buttons/btn_green »).
static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	var t: Texture2D = null
	var full: String = BASE + path + ".png"
	if ResourceLoader.exists(full):
		t = load(full) as Texture2D
	if t == null:
		push_warning("[ui] texture introuvable : %s" % full)
	_cache[path] = t
	return t


static func has_tex(path: String) -> bool:
	return ResourceLoader.exists(BASE + path + ".png")


static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			var f: FontFile = load(FONT_PATH) as FontFile
			# Repli pour les caractères absents (le jeu n'en utilise pas, mais jamais de « ☐ »).
			var fb: FontVariation = FontVariation.new()
			fb.base_font = ThemeDB.fallback_font
			f.fallbacks = [fb]
			_font = f
		else:
			_font = ThemeDB.fallback_font
	return _font


## Précharge toutes les textures d'un dossier (écran de chargement).
static func preload_all() -> int:
	var count: int = 0
	for folder: String in ["buttons", "panels", "bars", "icons", "misc", "brand"]:
		var dir: DirAccess = DirAccess.open(BASE + folder)
		if dir == null:
			continue
		for file: String in dir.get_files():
			if file.ends_with(".png"):
				tex(folder + "/" + file.get_basename())
				count += 1
	return count


## Étiquette habillée : police du jeu, contour sombre.
static func label(
	text: String, size: int = 40, color: Color = WHITE, outline: Color = INK, outline_size: int = -1
) -> Label:
	var l: Label = Label.new()
	style_label(l, size, color, outline, outline_size)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func style_label(
	l: Label, size: int, color: Color, outline: Color = INK, outline_size: int = -1
) -> void:
	l.add_theme_font_override(&"font", font())
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", outline)
	l.add_theme_constant_override(
		&"outline_size", maxi(int(size * 0.16), 3) if outline_size < 0 else outline_size
	)


## Image étirable (9 cases) d'un élément de panneau / bouton / barre.
static func nine(path: String, left: int, top: int, right: int, bottom: int) -> NinePatchRect:
	var n: NinePatchRect = NinePatchRect.new()
	n.texture = tex(path)
	n.patch_margin_left = left
	n.patch_margin_top = top
	n.patch_margin_right = right
	n.patch_margin_bottom = bottom
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return n


static func image(path: String, size: Vector2 = Vector2.ZERO) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = tex(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size != Vector2.ZERO:
		r.custom_minimum_size = size
	return r


## Marge d'écran réservée en haut (encoche / caméra) en pixels de l'interface (1080 de large).
static func top_inset() -> float:
	return UiKit.top_inset()
