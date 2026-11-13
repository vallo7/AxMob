class_name AxButton
extends BaseButton
## Bouton « bonbon » AxMob : fond 9 cases (assets/ui/buttons), icône facultative, texte contouré,
## écrasement au toucher avec rebond, son et vibration de tap (Haptics écoute tout BaseButton).
## Styles (palette du logo) : gold (action principale), orange, red, blue, stone, purple, green,
## grey. `small` = version basse (lignes de réglages).
## Désactivé = gris et terne (jamais un bouton décoratif présenté comme actif).

const STYLES: Array[String] = [
	"gold", "orange", "green", "blue", "yellow", "red", "purple", "stone", "grey"
]

@export var text: String = "":
	set(v):
		text = v
		_refresh()
@export var style: String = "blue":
	set(v):
		style = v
		_refresh()
@export var icon_name: String = "":
	set(v):
		icon_name = v
		_refresh()
@export var font_size: int = 48:
	set(v):
		font_size = v
		_refresh()
@export var small: bool = false:
	set(v):
		small = v
		_refresh()
## Disposition verticale : grande icône au-dessus du texte (tuiles du menu principal).
@export var vertical: bool = false:
	set(v):
		vertical = v
		if _box != null:
			_box.vertical = v
		_refresh()

var _bg: NinePatchRect
var _box: BoxContainer
var _icon: TextureRect
var _label: Label
var _tween: Tween
var _shown_disabled: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	_bg = UiArt.nine("buttons/btn_blue", 70, 60, 70, 70)
	add_child(_bg)
	_box = BoxContainer.new()
	_box.vertical = vertical
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override(&"separation", 14)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_box.add_child(_icon)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_box.add_child(_label)
	resized.connect(_on_resized)
	button_down.connect(_squash.bind(true))
	button_up.connect(_squash.bind(false))
	button_down.connect(func() -> void: AudioManager.play_ui(&"ui_down"))
	pressed.connect(func() -> void: AudioManager.play_ui(&"ui_tap"))
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_refresh()
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size * 0.5
	if _box != null:
		# Le visage du bouton occupe le haut : la lèvre (bas) ne porte pas le texte.
		_box.offset_bottom = -(18.0 if not small else 12.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and _bg != null and _shown_disabled != disabled:
		_refresh()


func set_text_key(key: String) -> void:
	text = Loc.t(key)


func _refresh() -> void:
	if _bg == null:
		return
	_shown_disabled = disabled
	var st: String = "grey" if disabled else (style if style in STYLES else "blue")
	_bg.texture = UiArt.tex("buttons/btn%s_%s" % ["_s" if small else "", st])
	if small:
		_bg.patch_margin_left = 44
		_bg.patch_margin_right = 44
		_bg.patch_margin_top = 38
		_bg.patch_margin_bottom = 44
	else:
		_bg.patch_margin_left = 70
		_bg.patch_margin_right = 70
		_bg.patch_margin_top = 60
		_bg.patch_margin_bottom = 70
	var ink: Color = UiArt.BUTTON_INK.get(st, UiArt.INK) as Color
	UiArt.style_label(_label, font_size, Color(1, 1, 1, 0.78) if disabled else UiArt.WHITE, ink)
	_label.text = text
	_label.visible = text != ""
	var has_icon: bool = icon_name != "" and UiArt.has_tex("icons/" + icon_name)
	_icon.visible = has_icon
	if has_icon:
		_icon.texture = UiArt.tex("icons/" + icon_name)
		var s: float = font_size * (5.4 if vertical else 1.45)
		_icon.custom_minimum_size = Vector2(s, s)
		_icon.modulate = Color(1, 1, 1, 0.7) if disabled else Color.WHITE


func _squash(down: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if down:
		# Écrasement net + éclat de lumière : le bouton « s'enfonce ».
		_tween.set_parallel(true)
		_tween.tween_property(self, "scale", Vector2(0.93, 0.9), 0.06).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(self, "self_modulate", Color(1.25, 1.2, 1.1), 0.06)
	else:
		# Rebond élastique avec un léger balancement, puis retour au calme.
		var wiggle: float = 0.035 if not disabled else 0.0
		_tween.set_parallel(true)
		(
			_tween
			. tween_property(self, "scale", Vector2(1.0, 1.0), 0.34)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)
		_tween.tween_property(self, "self_modulate", Color.WHITE, 0.16)
		_tween.tween_property(self, "rotation", wiggle, 0.07).set_trans(Tween.TRANS_SINE)
		_tween.chain().tween_property(self, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_BACK)


func _on_hover(inside: bool) -> void:
	if disabled or button_pressed:
		return
	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector2.ONE * (1.035 if inside else 1.0), 0.12).set_trans(
		Tween.TRANS_SINE
	)


## Apparition « pop » (écrans, menus) : part de petit, dépasse un peu, se pose. `delay` en secondes.
func pop_in(delay: float = 0.0, from: Vector2 = Vector2(0.4, 0.4)) -> void:
	scale = from
	modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_interval(delay)
	t.tween_callback(func() -> void: AudioManager.play_ui(&"ui_pop"))
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


## Petit « battement » d'appel à l'action (bouton JOUER, amélioration achetable).
func start_pulse() -> void:
	var t: Tween = create_tween().set_loops()
	t.tween_property(self, "scale", Vector2(1.045, 1.045), 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)


static func make(
	p_text: String, p_style: String, min_size: Vector2, p_font: int = 48, p_icon: String = ""
) -> AxButton:
	var b: AxButton = AxButton.new()
	b.custom_minimum_size = min_size
	b.style = p_style
	b.font_size = p_font
	b.icon_name = p_icon
	b.text = p_text
	return b
