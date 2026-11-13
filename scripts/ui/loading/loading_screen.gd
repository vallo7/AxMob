class_name LoadingScreen
extends CanvasLayer
## Écran de chargement : ciel bleu, rayons qui tournent, logo, hache qui tourne sur la barre de
## progression (RÉELLE : voir LoadProgress), phase en cours, astuce de jeu qui change. En mode
## « first » (tout premier lancement) il part d'une page BLANCHE (plus de flash Android) puis le
## logo apparaît. En mode « quick » (REJOUER) : fondu court, pas d'astuce.

signal shown
signal hidden
signal retry_pressed
signal menu_pressed

const TIP_COUNT: int = 8

var _root: Control
var _white: ColorRect
var _bg: TextureRect
var _rays: TextureRect
var _logo: TextureRect
var _bar: AxBar
var _axe: TextureRect
var _percent: Label
var _phase: Label
var _tip: Label
var _error_box: Control
var _error_label: Label
var _quick: bool = false
var _tip_index: int = 0
var _tip_timer: float = 0.0
var _dots: float = 0.0
var _visible_time: float = 0.0
var _active: bool = false


func _init() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# Fond : dégradé ciel -> mer (texture générée, sans fichier).
	var grad: Gradient = Gradient.new()
	grad.colors = PackedColorArray(
		[Color("#2FB6FF"), Color("#46C8F5"), Color("#7FE3F2"), Color("#FFE9A6")]
	)
	grad.offsets = PackedFloat32Array([0.0, 0.45, 0.8, 1.0])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	_bg = TextureRect.new()
	_bg.texture = gt
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)
	_rays = UiArt.image("misc/rays")
	_rays.set_anchors_preset(Control.PRESET_CENTER)
	_rays.offset_left = -900.0
	_rays.offset_right = 900.0
	_rays.offset_top = -1000.0
	_rays.offset_bottom = 800.0
	_rays.pivot_offset = Vector2(900.0, 1000.0)
	_rays.modulate = Color(1, 1, 1, 0.28)
	_root.add_child(_rays)

	_logo = UiArt.image("brand/logo")
	_logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_logo.anchor_left = 0.5
	_logo.anchor_right = 0.5
	_logo.offset_left = -400.0
	_logo.offset_right = 400.0
	_logo.offset_top = 260.0
	_logo.offset_bottom = 800.0
	_logo.pivot_offset = Vector2(400.0, 270.0)
	_root.add_child(_logo)

	var bottom: Control = Control.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -560.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_phase = UiArt.label("", 40, UiArt.WHITE, Color("#2F2A5C"))
	_phase.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_phase.offset_top = 20.0
	_phase.offset_bottom = 90.0
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_phase)
	_bar = AxBar.new()
	_bar.fill_style = "yellow"
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 120.0
	_bar.offset_right = -120.0
	_bar.offset_top = 110.0
	_bar.offset_bottom = 176.0
	bottom.add_child(_bar)
	_axe = UiArt.image("icons/model_axe_heavy", Vector2(120, 120))
	_axe.size = Vector2(120, 120)
	_axe.pivot_offset = Vector2(60, 60)
	_axe.position = Vector2(60.0, 82.0)
	bottom.add_child(_axe)
	_percent = UiArt.label("0 %", 36, UiArt.WHITE, Color("#2F2A5C"))
	_percent.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_percent.offset_top = 190.0
	_percent.offset_bottom = 250.0
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_percent)
	_tip = UiArt.label("", 34, UiArt.INK, Color(1, 1, 1, 0.0), 0)
	_tip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tip.offset_left = 110.0
	_tip.offset_right = -110.0
	_tip.offset_top = 290.0
	_tip.offset_bottom = 420.0
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_tip)

	# Erreur : message + RÉESSAYER / MENU.
	_error_box = VBoxContainer.new()
	_error_box.set_anchors_preset(Control.PRESET_CENTER)
	_error_box.offset_left = -330.0
	_error_box.offset_right = 330.0
	_error_box.offset_top = -80.0
	_error_box.offset_bottom = 300.0
	_error_box.visible = false
	_root.add_child(_error_box)
	_error_label = UiArt.label("", 40, UiArt.WHITE, Color("#7E1410"))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_box.add_child(_error_label)
	var retry: AxButton = AxButton.make(Loc.t("retry"), "gold", Vector2(0, 120), 46, "replay")
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	_error_box.add_child(retry)
	var menu: AxButton = AxButton.make(Loc.t("main_menu"), "blue", Vector2(0, 104), 40, "home")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	_error_box.add_child(menu)

	_white = ColorRect.new()
	_white.color = Color.WHITE
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_white)


## `first` : part d'une page blanche (premier lancement). `quick` : fondu bref, sans astuce.
func open(first: bool, quick: bool) -> void:
	_quick = quick
	_active = true
	_visible_time = 0.0
	visible = true
	_error_box.visible = false
	_bar.set_ratio(0.0, false)
	_percent.text = "0 %"
	_phase.text = Loc.t("loading")
	_tip.visible = not quick
	_bar.visible = true
	_axe.visible = true
	_logo.visible = not quick
	_rays.visible = not quick
	_pick_tip(true)
	if first:
		_white.visible = true
		_white.modulate.a = 1.0
		_logo.modulate.a = 0.0
		_logo.scale = Vector2(0.7, 0.7)
		_bg.modulate.a = 0.0
		var t: Tween = create_tween()
		t.tween_interval(0.12)
		t.tween_property(_white, "modulate:a", 0.0, 0.35)
		t.parallel().tween_property(_bg, "modulate:a", 1.0, 0.35)
		t.parallel().tween_property(_logo, "modulate:a", 1.0, 0.3)
		(
			t
			. parallel()
			. tween_property(_logo, "scale", Vector2.ONE, 0.5)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		t.tween_callback(func() -> void: shown.emit())
	else:
		_white.visible = false
		_root.modulate.a = 0.0
		_logo.modulate.a = 1.0
		_logo.scale = Vector2.ONE
		_bg.modulate.a = 1.0
		var t2: Tween = create_tween()
		t2.tween_property(_root, "modulate:a", 1.0, 0.12 if quick else 0.22)
		t2.tween_callback(func() -> void: shown.emit())


func set_progress(ratio: float, phase_text: String) -> void:
	_bar.set_ratio(ratio, false)
	_percent.text = "%d %%" % int(round(ratio * 100.0))
	var dots: String = ".".repeat(int(_dots) % 4)
	_phase.text = phase_text + dots
	_axe.position.x = 60.0 + (_bar.size.x + 120.0 - 120.0) * ratio - 30.0


func close() -> void:
	var t: Tween = create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.16 if _quick else 0.28)
	t.tween_callback(
		func() -> void:
			visible = false
			_active = false
			_root.modulate.a = 1.0
			hidden.emit()
	)


func show_error(text: String) -> void:
	_error_box.visible = true
	_error_label.text = text
	_bar.visible = false
	_axe.visible = false
	_percent.text = ""
	_phase.text = ""


func _process(delta: float) -> void:
	if not _active:
		return
	_visible_time += delta
	_dots += delta * 3.0
	_axe.rotation += delta * 7.0
	_rays.rotation += delta * 0.12
	if not _quick:
		_tip_timer += delta
		if _tip_timer >= 3.2:
			_pick_tip(false)


func _pick_tip(first: bool) -> void:
	_tip_timer = 0.0
	if first:
		_tip_index = int(Time.get_ticks_usec() % TIP_COUNT)
	else:
		_tip_index = (_tip_index + 1) % TIP_COUNT
	if _tip == null:
		return
	_tip.text = Loc.t("tip_%d" % (_tip_index + 1))
	_tip.modulate.a = 0.0
	create_tween().tween_property(_tip, "modulate:a", 1.0, 0.4)
