class_name GameOverScreen
extends Control
## Écran de défaite (cahier §10.7) : ruban rouge, résultats (vague, temps, éliminations, pièces),
## badge NOUVEAU RECORD, pièces conservées, boutons REJOUER / MENU PRINCIPAL.
## RÉANIMER (publicité récompensée) n'apparaît QUE si `set_revive_available(true)` : le système
## publicitaire est la phase 8 ; aucun bouton factice n'est montré.

signal play_again_pressed
signal menu_pressed
signal revive_pressed

var _panel: Control
var _rib: TextureRect
var _title: Label
var _rows: Array[Control] = []
var _record: Control
var _banked: Label
var _revive: AxButton
var _rays: TextureRect
var _revive_available: bool = false
var _wave_v: Label
var _time_v: Label
var _kills_v: Label
var _coins_v: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.12, 0.03, 0.1, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_rays = UiArt.image("misc/rays")
	_rays.set_anchors_preset(Control.PRESET_CENTER)
	_rays.offset_left = -620.0
	_rays.offset_right = 620.0
	_rays.offset_top = -900.0
	_rays.offset_bottom = 340.0
	_rays.pivot_offset = Vector2(620.0, 620.0)
	_rays.modulate = Color(1.0, 0.55, 0.45, 0.35)
	add_child(_rays)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -420.0
	_panel.offset_right = 420.0
	_panel.offset_top = -560.0
	_panel.offset_bottom = 640.0
	_panel.pivot_offset = Vector2(420.0, 560.0)
	add_child(_panel)
	_panel.add_child(UiArt.nine("panels/panel_light", 78, 78, 78, 84))
	_rib = UiArt.image("brand/banner_red")
	_rib.position = Vector2(70.0, -128.0)
	_rib.size = Vector2(700.0, 234.0)
	_rib.stretch_mode = TextureRect.STRETCH_SCALE
	_panel.add_child(_rib)
	_title = UiArt.label(Loc.t("defeat"), 70, UiArt.WHITE, Color("#7E1410"))
	_title.position = Vector2(130.0, -66.0)
	_title.size = Vector2(580.0, 130.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_title)

	var y: float = 150.0
	_wave_v = _stat_row("trophy", Loc.t("res_wave"), y)
	_time_v = _stat_row("clock", Loc.t("res_time"), y + 118.0)
	_kills_v = _stat_row("skull", Loc.t("res_kills"), y + 236.0)
	_coins_v = _stat_row("coin", Loc.t("res_coins"), y + 354.0)
	_banked = UiArt.label("", 32, UiArt.TEXT_MUTED, Color(1, 1, 1, 0), 0)
	_banked.position = Vector2(60.0, y + 480.0)
	_banked.size = Vector2(720.0, 44.0)
	_banked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_banked)

	_record = Control.new()
	_record.position = Vector2(150.0, y + 524.0)
	_record.size = Vector2(540.0, 96.0)
	_record.visible = false
	_panel.add_child(_record)
	_record.add_child(UiArt.nine("panels/panel_gold", 56, 56, 56, 62))
	var rt: TextureRect = UiArt.image("icons/trophy_s", Vector2(80, 80))
	rt.position = Vector2(24.0, 4.0)
	rt.size = Vector2(80, 80)
	_record.add_child(rt)
	var rl: Label = UiArt.label(Loc.t("new_record"), 40, UiArt.WHITE, Color("#9A5200"))
	rl.position = Vector2(112.0, 0.0)
	rl.size = Vector2(410.0, 88.0)
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_record.add_child(rl)
	_record.pivot_offset = _record.size * 0.5

	var bx: VBoxContainer = VBoxContainer.new()
	bx.position = Vector2(80.0, y + 650.0)
	bx.size = Vector2(680.0, 330.0)
	bx.add_theme_constant_override(&"separation", 18)
	_panel.add_child(bx)
	_revive = AxButton.make(Loc.t("revive"), "purple", Vector2(0, 118), 46, "video")
	_revive.visible = false
	_revive.pressed.connect(func() -> void: revive_pressed.emit())
	bx.add_child(_revive)
	var again: AxButton = AxButton.make(Loc.t("play_again"), "gold", Vector2(0, 140), 54, "replay")
	again.pressed.connect(func() -> void: play_again_pressed.emit())
	bx.add_child(again)
	var menu: AxButton = AxButton.make(Loc.t("main_menu"), "blue", Vector2(0, 112), 42, "home")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	bx.add_child(menu)


func _stat_row(icon: String, label_text: String, y: float) -> Label:
	var card: Control = Control.new()
	card.position = Vector2(50.0, y)
	card.size = Vector2(740.0, 106.0)
	_panel.add_child(card)
	card.add_child(UiArt.nine("panels/panel_card", 56, 56, 56, 62))
	var ic: TextureRect = UiArt.image("icons/" + icon, Vector2(72, 72))
	ic.position = Vector2(22.0, 6.0)
	ic.size = Vector2(72, 72)
	card.add_child(ic)
	var l: Label = UiArt.label(label_text, 32, UiArt.TEXT_DARK, Color(1, 1, 1, 0), 0)
	l.position = Vector2(108.0, 0.0)
	l.size = Vector2(360.0, 90.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(l)
	var v: Label = UiArt.label("", 46, Color("#C46A00"), Color(1, 1, 1, 0), 0)
	v.position = Vector2(440.0, 0.0)
	v.size = Vector2(270.0, 90.0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(v)
	_rows.append(card)
	return v


func _process(delta: float) -> void:
	if visible:
		_rays.rotation += delta * 0.18


## Le bouton RÉANIMER n'existe visuellement que si une publicité récompensée est disponible.
func set_revive_available(on: bool) -> void:
	_revive_available = on
	if _revive != null:
		_revive.visible = on


## `result` : retour de SaveManager.record_run (new_best_*, banked...). Optionnel (tests,
## simulateur).
func show_results(ctx: RunContext, result: Dictionary = {}) -> void:
	var total: int = int(ctx.time)
	_wave_v.text = str(ctx.wave)
	_time_v.text = "%d:%02d" % [total / 60, total % 60]
	_kills_v.text = str(ctx.kills)
	_coins_v.text = str(ctx.coins + ctx.coins_spent)
	var banked: int = int(result.get("banked", 0))
	_banked.text = Loc.t("res_banked") + ": +%d" % banked if banked > 0 else ""
	var is_record: bool = (
		bool(result.get("new_best_wave", false)) or bool(result.get("new_best_time", false))
	)
	_record.visible = is_record
	_revive.visible = _revive_available
	visible = true
	_animate_in(is_record)


func _animate_in(is_record: bool) -> void:
	_panel.scale = Vector2(0.8, 0.8)
	_panel.modulate.a = 0.0
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	t.tween_property(_panel, "modulate:a", 1.0, 0.18)
	for i: int in _rows.size():
		var r: Control = _rows[i]
		r.pivot_offset = r.size * 0.5
		r.scale = Vector2(0.6, 0.6)
		var rt: Tween = create_tween()
		rt.tween_interval(0.25 + 0.12 * float(i))
		rt.tween_property(r, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT
		)
	if is_record:
		_record.scale = Vector2.ZERO
		var rr: Tween = create_tween()
		rr.tween_interval(0.85)
		(
			rr
			. tween_property(_record, "scale", Vector2.ONE, 0.4)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)
