class_name TurretDock
extends Control
## Barre des quatre tourelles, en bas de l'écran de jeu (phase 7) : un bouton par tourelle, avec le
## modèle 3D du canon, son niveau et le prix de la prochaine amélioration. Toucher = acheter
## l'amélioration tout de suite (accès rapide, sans ouvrir de menu ni mettre en pause) ; appui long
## = ouvrir le détail des statistiques. Un bouton doré qui bat = amélioration abordable.

signal buy_requested(turret_id: int)
signal details_requested

const SLOT_H: float = 232.0
const GAP: float = 14.0
const SIDE: float = 26.0
const HOLD_TIME: float = 0.45
const ICONS: Array[String] = [
	"model_turret_rapid", "model_turret_heavy", "model_turret_multi", "model_turret_pierce"
]

var _ctx: RunContext
var _upgrades: UpgradeManager
var _slots: Array[DockSlot] = []


func setup(ctx: RunContext, upgrades: UpgradeManager) -> void:
	_ctx = ctx
	_upgrades = upgrades
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = SIDE
	offset_right = -SIDE
	offset_bottom = -(26.0 + UiKit.bottom_inset())
	offset_top = offset_bottom - SLOT_H
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override(&"separation", int(GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i: int in 4:
		var slot: DockSlot = DockSlot.new()
		slot.turret_id = i
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size = Vector2(0.0, SLOT_H)
		slot.setup(ICONS[i])
		slot.tapped.connect(func() -> void: _on_tapped(i))
		slot.held.connect(func() -> void: details_requested.emit())
		row.add_child(slot)
		_slots.append(slot)
	EventBus.turret_upgraded.connect(_on_upgraded)
	refresh()


func _process(_delta: float) -> void:
	if _upgrades != null:
		refresh()


## Rectangle d'écran occupé par la barre : un toucher ici ne démarre jamais le joystick.
func screen_rect() -> Rect2:
	return get_global_rect()


func slot_count() -> int:
	return _slots.size()


func slot(i: int) -> DockSlot:
	return _slots[i]


func refresh() -> void:
	for i: int in _slots.size():
		_slots[i].show_state(
			_upgrades.level_of(i),
			_upgrades.cost_to_upgrade(i),
			_upgrades.can_upgrade(i),
			_upgrades.is_max(i)
		)


func _on_tapped(turret_id: int) -> void:
	buy_requested.emit(turret_id)


func _on_upgraded(turret_id: int, _level: int) -> void:
	if turret_id >= 0 and turret_id < _slots.size():
		_slots[turret_id].celebrate()


## Bouton d'une tourelle.
class DockSlot:
	extends BaseButton

	signal tapped
	signal held

	var turret_id: int = 0
	var _bg: NinePatchRect
	var _icon: TextureRect
	var _level: Label
	var _cost: Label
	var _coin: TextureRect
	var _state: String = ""
	var _tween: Tween
	var _press_time: float = -1.0
	var _long: bool = false
	var _afford: bool = false

	func setup(icon_name: String) -> void:
		focus_mode = Control.FOCUS_NONE
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_bg = UiArt.nine("buttons/btn_stone", 70, 60, 70, 70)
		add_child(_bg)
		_icon = UiArt.image("icons/" + icon_name)
		_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon.offset_left = 18.0
		_icon.offset_right = -18.0
		_icon.offset_top = 6.0
		_icon.offset_bottom = -72.0
		add_child(_icon)
		_level = UiArt.label("", 30, UiArt.WHITE, Color("#2F2A5C"))
		_level.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_level.offset_left = 24.0
		_level.offset_top = 14.0
		_level.offset_right = 140.0
		_level.offset_bottom = 54.0
		add_child(_level)
		var cost_row: HBoxContainer = HBoxContainer.new()
		cost_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cost_row.offset_left = 10.0
		cost_row.offset_right = -10.0
		cost_row.offset_bottom = -26.0
		cost_row.offset_top = -86.0
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_theme_constant_override(&"separation", 6)
		cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cost_row)
		_coin = UiArt.image("icons/coin_s", Vector2(46.0, 46.0))
		_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost_row.add_child(_coin)
		_cost = UiArt.label("", 40, UiArt.WHITE, Color("#6E4A08"))
		_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_row.add_child(_cost)
		resized.connect(func() -> void: pivot_offset = size * 0.5)
		button_down.connect(_on_down)
		button_up.connect(_on_up)
		pressed.connect(_on_pressed)

	func show_state(level: int, cost: int, can_buy: bool, is_max: bool) -> void:
		var key: String = "max" if is_max else ("gold" if can_buy else "stone")
		_afford = can_buy
		_level.text = "%d/10" % level if not is_max else "MAX"
		_coin.visible = not is_max
		_cost.text = "" if is_max else str(cost)
		_cost.add_theme_color_override(&"font_color", UiArt.WHITE if can_buy else Color("#FFB3A8"))
		if key == _state:
			return
		_state = key
		_bg.texture = UiArt.tex(
			"buttons/btn_" + ("grey" if is_max else ("gold" if can_buy else "stone"))
		)
		_icon.modulate = Color(1, 1, 1, 1) if not is_max else Color(1, 1, 1, 0.85)
		if can_buy:
			_start_pulse()
		else:
			_stop_pulse()

	func _process(delta: float) -> void:
		if _press_time >= 0.0 and not _long:
			_press_time += delta
			if _press_time >= HOLD_TIME:
				_long = true
				AudioManager.play_ui(&"ui_pop")
				held.emit()

	func _on_down() -> void:
		_press_time = 0.0
		_long = false
		AudioManager.play_ui(&"ui_down")
		_kill()
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(self, "scale", Vector2(0.92, 0.9), 0.06)

	func _on_up() -> void:
		_press_time = -1.0
		_kill()
		_tween = create_tween()
		(
			_tween
			. tween_property(self, "scale", Vector2.ONE, 0.32)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)

	func _on_pressed() -> void:
		if _long:
			return
		tapped.emit()
		if not _afford:
			shake()

	## Achat réussi : saut élastique + lueur dorée.
	func celebrate() -> void:
		_kill()
		scale = Vector2.ONE * 1.18
		_tween = create_tween()
		(
			_tween
			. tween_property(self, "scale", Vector2.ONE, 0.45)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)
		_level.pivot_offset = _level.size * 0.5
		_level.scale = Vector2.ONE * 1.5
		(
			create_tween()
			. tween_property(_level, "scale", Vector2.ONE, 0.4)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		_icon.pivot_offset = _icon.size * 0.5
		_icon.rotation = -0.18
		(
			create_tween()
			. tween_property(_icon, "rotation", 0.0, 0.5)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)

	## Refus (pas assez de pièces) : petite secousse horizontale.
	func shake() -> void:
		_kill()
		var base: float = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "rotation", 0.05, 0.04)
		_tween.tween_property(self, "rotation", -0.05, 0.07)
		_tween.tween_property(self, "rotation", 0.03, 0.06)
		_tween.tween_property(self, "rotation", base, 0.06)

	func _start_pulse() -> void:
		_stop_pulse()
		_tween = create_tween().set_loops()
		_tween.tween_property(self, "scale", Vector2.ONE * 1.04, 0.5).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

	func _stop_pulse() -> void:
		_kill()
		scale = Vector2.ONE

	func _kill() -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()
