class_name TurretUpgradePanel
extends Control
## Panneau d'amélioration des tourelles en partie (phase 6) : feuille crème en bas d'écran, 2×2
## cartes. Le comportement du jeu pendant qu'il est ouvert (arrêt total, ralenti, aucune pause)
## est décidé par Gameplay ; le panneau n'affiche que l'état et relaie les achats.

signal upgrade_pressed(turret_id: int)
signal close_pressed

const SHEET: Rect2 = Rect2(20.0, 1070.0, 1040.0, 830.0)
const GAP: float = 20.0

var _ctx: RunContext
var _upgrades: UpgradeManager
var _cards: Array[TurretCard] = []
var _coins: AxPill
var _sheet_tween: Tween
var _root: Control


func setup(ctx: RunContext, upgrades: UpgradeManager) -> void:
	_ctx = ctx
	_upgrades = upgrades
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# Tout le contenu vit dans `_root` (positionné comme la feuille) : on l'anime d'un bloc.
	_root = Control.new()
	_root.position = SHEET.position
	_root.size = SHEET.size
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.add_child(UiArt.nine("panels/panel_light", 78, 78, 78, 84))
	var rib: TextureRect = UiArt.image("brand/banner_yellow")
	rib.position = Vector2((SHEET.size.x - 520.0) * 0.5, -66.0)
	rib.size = Vector2(520.0, 176.0)
	rib.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(rib)
	var title: Label = UiArt.label(Loc.t("turrets"), 46, UiArt.WHITE, Color("#9A5200"))
	title.position = rib.position + Vector2(60.0, 18.0)
	title.size = Vector2(400.0, 80.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(title)
	_coins = AxPill.make("icons/coin_s", 250.0, 76.0, 40)
	_coins.position = Vector2(34.0, 30.0)
	_coins.set_color(UiArt.GOLD)
	_root.add_child(_coins)
	var close: AxRoundButton = AxRoundButton.make("red", "close", 96.0)
	close.position = Vector2(SHEET.size.x - 120.0, 14.0)
	close.pressed.connect(func() -> void: close_pressed.emit())
	_root.add_child(close)
	for i: int in ctx.turret_data.size():
		var card: TurretCard = TurretCard.new()
		_root.add_child(card)
		card.setup(i, ctx.turret_data[i])
		var col: int = i % 2
		@warning_ignore("integer_division")
		var row: int = i / 2
		card.position = Vector2(
			GAP + 5.0 + float(col) * (TurretCard.CARD_SIZE.x + GAP),
			120.0 + float(row) * (TurretCard.CARD_SIZE.y + GAP)
		)
		card.upgrade_pressed.connect(func(id: int) -> void: upgrade_pressed.emit(id))
		_cards.append(card)
	EventBus.coins_changed.connect(func(_t: int) -> void: refresh())
	EventBus.turret_upgraded.connect(func(_i: int, _l: int) -> void: refresh())


func open() -> void:
	visible = true
	refresh()
	_coins.count_to(_ctx.coins, true)
	if _sheet_tween != null and _sheet_tween.is_valid():
		_sheet_tween.kill()
	_root.position = SHEET.position + Vector2(0.0, 80.0)
	_root.modulate.a = 0.0
	_sheet_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	(
		_sheet_tween
		. tween_property(_root, "position", SHEET.position, 0.22)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_sheet_tween.tween_property(_root, "modulate:a", 1.0, 0.14)


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
	_coins.count_to(_ctx.coins)
	for card: TurretCard in _cards:
		card.refresh(_ctx, _upgrades)
