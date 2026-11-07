class_name TurretUpgradePanel
extends Control
## Panneau d'amélioration des tourelles en partie : feuille en bas d'écran, 2×2 cartes.
## Le comportement du jeu pendant qu'il est ouvert (arrêt total, ralenti, aucune pause) est
## décidé par Gameplay ; le panneau n'affiche que l'état et relaie les achats.

signal upgrade_pressed(turret_id: int)
signal close_pressed

const SHEET: Rect2 = Rect2(20.0, 1170.0, 1040.0, 710.0)
const GAP: float = 20.0

var _ctx: RunContext
var _upgrades: UpgradeManager
var _cards: Array[TurretCard] = []
var _coins: Label


func setup(ctx: RunContext, upgrades: UpgradeManager) -> void:
	_ctx = ctx
	_upgrades = upgrades
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var sheet: Panel = Panel.new()
	sheet.position = SHEET.position
	sheet.size = SHEET.size
	sheet.add_theme_stylebox_override("panel", UiKit.panel_box())
	add_child(sheet)
	var title: Label = UiKit.label("TOURELLES", 44, UiKit.ACCENT)
	title.position = SHEET.position + Vector2(28.0, 8.0)
	add_child(title)
	_coins = UiKit.label("0", 44, Color(1.0, 0.82, 0.25), HORIZONTAL_ALIGNMENT_RIGHT)
	_coins.position = SHEET.position + Vector2(420.0, 8.0)
	_coins.size = Vector2(300.0, 56.0)
	add_child(_coins)
	var close: Button = UiKit.button("FERMER", Vector2(250.0, 64.0), 34)
	close.position = SHEET.position + Vector2(SHEET.size.x - 270.0, 6.0)
	close.pressed.connect(func() -> void: close_pressed.emit())
	add_child(close)
	for i: int in ctx.turret_data.size():
		var card: TurretCard = TurretCard.new()
		add_child(card)
		card.setup(i, ctx.turret_data[i])
		var col: int = i % 2
		var row: int = i / 2
		card.position = (
			SHEET.position
			+ Vector2(
				GAP + float(col) * (TurretCard.CARD_SIZE.x + GAP),
				80.0 + float(row) * (TurretCard.CARD_SIZE.y + GAP)
			)
		)
		card.upgrade_pressed.connect(func(id: int) -> void: upgrade_pressed.emit(id))
		_cards.append(card)
	EventBus.coins_changed.connect(func(_t: int) -> void: refresh())
	EventBus.turret_upgraded.connect(func(_i: int, _l: int) -> void: refresh())


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


## Zone occupée par la feuille (le joystick n'y démarre pas).
func sheet_rect() -> Rect2:
	return SHEET


func refresh() -> void:
	if not visible and _ctx == null:
		return
	_coins.text = "%d pièces" % _ctx.coins
	for card: TurretCard in _cards:
		card.refresh(_ctx, _upgrades)
