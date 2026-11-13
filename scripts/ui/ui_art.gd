class_name UiArt
extends RefCounted
## Accès centralisé aux éléments graphiques d'interface (assets/ui/), à la police et à la palette.
## Les textures sont chargées à la demande puis gardées (une seule instance par fichier).

const BASE: String = "res://assets/ui/"
const FONT_PATH: String = "res://assets/fonts/LilitaOne-Regular.ttf"

# Palette de l'interface (phase 7) : tirée du LOGO — or / orange / rouge des lettres et du ruban,
# pierre violette du socle, bleu clair de la lueur des haches, crème. Contour brun très sombre.
const INK: Color = Color("#2E1712")
const INK_SOFT: Color = Color("#4A2A22")
const WHITE: Color = Color("#FFFFFF")
const CREAM: Color = Color("#FFF3D6")
const GOLD: Color = Color("#FFD43B")
const ORANGE: Color = Color("#FF8A24")
const SKY: Color = Color("#5CD0FF")
const RED: Color = Color("#E0302B")
const GREEN: Color = Color("#58BE3E")
const STONE: Color = Color("#6A66A6")
const STONE_DARK: Color = Color("#3B3768")
const TEXT_DARK: Color = Color("#3B2A5E")
const TEXT_MUTED: Color = Color("#7C6FA3")

## Couleur du contour du texte posé sur chaque style de bouton (teinte sombre de la lèvre).
const BUTTON_INK: Dictionary = {
	"gold": Color("#8A4208"),
	"yellow": Color("#8A4208"),
	"orange": Color("#7A2A0C"),
	"green": Color("#1F5E26"),
	"blue": Color("#123F8A"),
	"red": Color("#6E1219"),
	"purple": Color("#34247A"),
	"stone": Color("#2F2A5C"),
	"grey": Color("#4B4766"),
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
	var os: int = maxi(int(size * 0.18), 4) if outline_size < 0 else outline_size
	l.add_theme_constant_override(&"outline_size", os)
	# Ombre portée nette sous les textes contourés : relief « dessin animé », lisible sur tout fond.
	if os > 0:
		l.add_theme_color_override(&"font_shadow_color", Color(0.1, 0.04, 0.02, 0.5))
		l.add_theme_constant_override(&"shadow_offset_x", 0)
		l.add_theme_constant_override(&"shadow_offset_y", maxi(int(size * 0.07), 2))
		l.add_theme_constant_override(&"shadow_outline_size", maxi(os - 1, 1))


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
