class_name TurretCard
extends Control
## Carte d'une catégorie de tourelle : nom, niveau, statistiques actuelles → suivantes
## (aperçu du changement), coût et bouton d'amélioration.

signal upgrade_pressed(turret_id: int)

const CARD_SIZE: Vector2 = Vector2(500.0, 300.0)
const MAX_LINES: int = 5

var turret_id: int = 0

var _data: TurretData
var _name: Label
var _level: Label
var _lines: Array[Label] = []
var _button: Button


func setup(id: int, data: TurretData) -> void:
	turret_id = id
	_data = data
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	var bg: Panel = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UiKit.panel_box())
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var strip: ColorRect = ColorRect.new()
	strip.color = data.color
	strip.position = Vector2(0.0, 18.0)
	strip.size = Vector2(10.0, CARD_SIZE.y - 36.0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	_name = UiKit.label(data.display_name.to_upper(), 40, data.color.lightened(0.25))
	_name.position = Vector2(28.0, 10.0)
	add_child(_name)
	_level = UiKit.label("", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_level.position = Vector2(CARD_SIZE.x - 200.0, 14.0)
	_level.size = Vector2(180.0, 44.0)
	add_child(_level)
	for i: int in MAX_LINES:
		var line: Label = UiKit.label("", 27)
		line.position = Vector2(28.0, 54.0 + 30.0 * float(i))
		add_child(line)
		_lines.append(line)
	_button = UiKit.button("", Vector2(CARD_SIZE.x - 40.0, 64.0), 36)
	_button.position = Vector2(20.0, CARD_SIZE.y - 76.0)
	_button.pressed.connect(func() -> void: upgrade_pressed.emit(turret_id))
	add_child(_button)


func refresh(ctx: RunContext, upgrades: UpgradeManager) -> void:
	var level: int = ctx.turret_levels[turret_id]
	var max_level: int = ctx.turret_max_level(turret_id)
	_level.text = "NIV %d/%d" % [level, max_level]
	var now: TurretLevelData = ctx.turret_stats(turret_id)
	var next: TurretLevelData = null
	if level < max_level:
		next = ctx.turret_stats(turret_id, level + 1)
	var text: PackedStringArray = TurretLeveling.describe(now, next)
	for i: int in MAX_LINES:
		_lines[i].visible = i < text.size()
		if i < text.size():
			_lines[i].text = text[i]
	var cost: int = upgrades.cost_to_upgrade(turret_id)
	if cost < 0:
		_button.text = "NIVEAU MAX"
		_button.disabled = true
		return
	_button.disabled = false
	_button.text = "AMÉLIORER   %d" % cost
	var ok: bool = upgrades.can_upgrade(turret_id)
	var pressed_box: StyleBoxFlat = UiKit.panel_box()
	_button.add_theme_color_override("font_color", UiKit.TEXT if ok else Color(0.85, 0.4, 0.4))
	_button.add_theme_stylebox_override(
		"normal", UiKit.button_box(Color(0.82, 0.4, 0.1) if ok else Color(0.16, 0.17, 0.21))
	)
	_button.add_theme_stylebox_override(
		"pressed", pressed_box if not ok else UiKit.button_box(UiKit.ACCENT)
	)
