class_name AxScreen
extends Control
## Fenêtre modale « feuille » (améliorations, statistiques, réglages, pause) : fond assombri, grand
## panneau crème, bandeau bleu du titre qui déborde en haut, bouton rouge de fermeture.
## Répond au bouton retour du téléphone (UIManager). Fonctionne en pause (process ALWAYS).
## Les écrans concrets remplissent `content` (VBoxContainer dans un ScrollContainer).

signal closed

@export var title: String = ""
@export var banner: String = "blue"
@export var closable: bool = true

var content: VBoxContainer
var dim: ColorRect
var sheet: Control
var title_label: Label
var _scroll: ScrollContainer
var _closing: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	# Les ancres sont posées ICI (dans l'arbre) : posées dans _init, la taille du parent est inconnue.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim = ColorRect.new()
	dim.color = Color(0.04, 0.07, 0.2, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var top: float = 190.0 + UiKit.top_inset()
	sheet = Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.offset_left = 44.0
	sheet.offset_right = -44.0
	sheet.offset_top = top
	sheet.offset_bottom = -150.0
	add_child(sheet)
	sheet.add_child(UiArt.nine("panels/panel_light", 78, 78, 78, 84))

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 52.0
	_scroll.offset_right = -52.0
	_scroll.offset_top = 150.0
	_scroll.offset_bottom = -64.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 20)
	_scroll.add_child(content)

	var rib: TextureRect = UiArt.image("brand/banner_" + banner)
	rib.set_anchors_preset(Control.PRESET_CENTER_TOP)
	rib.anchor_left = 0.5
	rib.anchor_right = 0.5
	rib.offset_left = -400.0
	rib.offset_right = 400.0
	rib.offset_top = -118.0
	rib.offset_bottom = 142.0
	rib.stretch_mode = TextureRect.STRETCH_SCALE
	sheet.add_child(rib)
	var t: Label = UiArt.label(title, 62, UiArt.WHITE, Color("#0F3C8A"))
	title_label = t
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.anchor_left = 0.5
	t.anchor_right = 0.5
	t.offset_left = -330.0
	t.offset_right = 330.0
	t.offset_top = -62.0
	t.offset_bottom = 70.0
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.clip_text = true
	sheet.add_child(t)
	if closable:
		var x: AxRoundButton = AxRoundButton.make("red", "close", 112.0)
		x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		x.offset_left = -92.0
		x.offset_right = 20.0
		x.offset_top = -46.0
		x.offset_bottom = 76.0
		x.pressed.connect(close)
		sheet.add_child(x)
	build()
	UIManager.push_back(self, _on_back)
	_animate_in()


## À surcharger : remplit `content`.
func build() -> void:
	pass


func _on_back() -> bool:
	if closable:
		close()
	return true


func _animate_in() -> void:
	sheet.pivot_offset = Vector2(sheet.size.x * 0.5, 120.0)
	sheet.scale = Vector2(0.88, 0.88)
	sheet.modulate.a = 0.0
	dim.modulate.a = 0.0
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(sheet, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	t.tween_property(sheet, "modulate:a", 1.0, 0.16)
	t.tween_property(dim, "modulate:a", 1.0, 0.2)


func close() -> void:
	if _closing:
		return
	_closing = true
	UIManager.pop_back(self)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(sheet, "scale", Vector2(0.92, 0.92), 0.14)
	t.tween_property(sheet, "modulate:a", 0.0, 0.14)
	t.tween_property(dim, "modulate:a", 0.0, 0.16)
	t.chain().tween_callback(
		func() -> void:
			closed.emit()
			queue_free()
	)


func set_title(text: String) -> void:
	title = text
	if title_label != null:
		title_label.text = text


## Ligne « empilée » : titre au-dessus, commande large dessous (sélecteurs à plusieurs choix).
static func stacked_row(label_text: String, control: Control, sub: String = "") -> Control:
	var card: Control = Control.new()
	card.custom_minimum_size = Vector2(0, 196 if sub == "" else 224)
	card.add_child(UiArt.nine("panels/panel_card", 56, 56, 56, 62))
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 34.0
	v.offset_right = -34.0
	v.offset_top = 16.0
	v.offset_bottom = -26.0
	v.add_theme_constant_override(&"separation", 6)
	card.add_child(v)
	v.add_child(UiArt.label(label_text, 38, UiArt.TEXT_DARK, Color(1, 1, 1, 0), 0))
	if sub != "":
		var s: Label = UiArt.label(sub, 27, UiArt.TEXT_MUTED, Color(1, 1, 1, 0), 0)
		s.name = "Sub"
		v.add_child(s)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(control)
	return card


## Ligne de réglage : titre à gauche, commande à droite.
static func row(label_text: String, control: Control, sub: String = "") -> Control:
	var card: Control = Control.new()
	card.custom_minimum_size = Vector2(0, 132 if sub == "" else 150)
	card.add_child(UiArt.nine("panels/panel_card", 56, 56, 56, 62))
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 34.0
	h.offset_right = -34.0
	h.offset_top = 10.0
	h.offset_bottom = -22.0
	h.add_theme_constant_override(&"separation", 16)
	card.add_child(h)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override(&"separation", 0)
	var l: Label = UiArt.label(label_text, 38, UiArt.TEXT_DARK, Color(1, 1, 1, 0), 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	if sub != "":
		var s: Label = UiArt.label(sub, 28, UiArt.TEXT_MUTED, Color(1, 1, 1, 0), 0)
		s.name = "Sub"
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	h.add_child(v)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(control)
	return card
