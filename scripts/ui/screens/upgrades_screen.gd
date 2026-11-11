class_name UpgradesScreen
extends AxScreen
## Améliorations PERMANENTES (cahier des charges §10.3) : pour chacune, nom, description, niveau,
## valeur actuelle → suivante, coût et bouton. Le bouton est grisé sans assez de pièces ; l'achat
## débite le solde, augmente le niveau et SAUVEGARDE tout de suite (SaveManager.buy_permanent).
## L'effet est réel : il s'applique à la partie suivante (RunContext.bonuses).

signal purchased(index: int)

var _wallet: AxPill
var _rows: Array[Dictionary] = []


func _init() -> void:
	banner = "yellow"


func _ready() -> void:
	title = Loc.t("upgrades")
	super._ready()


func build() -> void:
	_wallet = AxPill.make("icons/coin", 330.0, 96.0, 52)
	_wallet.set_color(UiArt.GOLD)
	_wallet.count_to(SaveManager.coins(), true)
	var wrap: CenterContainer = CenterContainer.new()
	wrap.add_child(_wallet)
	content.add_child(wrap)
	for i: int in PermanentUpgrades.count():
		_rows.append(_make_row(i))
	SaveManager.changed.connect(_refresh_all)
	_refresh_all()


func _make_row(i: int) -> Dictionary:
	var id: String = PermanentUpgrades.id_of(i)
	var card: Control = Control.new()
	card.custom_minimum_size = Vector2(0, 232)
	card.add_child(UiArt.nine("panels/panel_card", 56, 56, 56, 62))
	var icon: TextureRect = UiArt.image(
		"icons/" + str(PermanentUpgrades.DEFS[i]["icon"]), Vector2(112, 112)
	)
	icon.position = Vector2(26.0, 30.0)
	icon.size = Vector2(112, 112)
	card.add_child(icon)
	var name: Label = UiArt.label(
		Loc.t("perm_%s_name" % id), 40, UiArt.TEXT_DARK, Color(1, 1, 1, 0), 0
	)
	name.position = Vector2(156.0, 16.0)
	name.size = Vector2(500.0, 52.0)
	name.clip_text = true
	card.add_child(name)
	var desc: Label = UiArt.label(
		Loc.t("perm_%s_desc" % id), 26, UiArt.TEXT_MUTED, Color(1, 1, 1, 0), 0
	)
	desc.position = Vector2(156.0, 66.0)
	desc.size = Vector2(500.0, 34.0)
	desc.clip_text = true
	card.add_child(desc)
	var level_bar: AxBar = AxBar.new()
	level_bar.fill_style = "blue"
	level_bar.position = Vector2(156.0, 108.0)
	level_bar.size = Vector2(300.0, 36.0)
	card.add_child(level_bar)
	var level: Label = UiArt.label("", 28, UiArt.TEXT_DARK, Color(1, 1, 1, 0), 0)
	level.position = Vector2(468.0, 104.0)
	level.size = Vector2(190.0, 40.0)
	card.add_child(level)
	var effect: Label = UiArt.label("", 30, Color("#1E8F3A"), Color(1, 1, 1, 0), 0)
	effect.position = Vector2(156.0, 150.0)
	effect.size = Vector2(500.0, 40.0)
	effect.clip_text = true
	card.add_child(effect)
	var buy: AxButton = AxButton.make("", "yellow", Vector2(250.0, 132.0), 38, "coin_s")
	buy.small = true
	buy.anchor_left = 1.0
	buy.anchor_right = 1.0
	buy.offset_left = -270.0
	buy.offset_right = -22.0
	buy.offset_top = 44.0
	buy.offset_bottom = 176.0
	buy.pressed.connect(_on_buy.bind(i))
	card.add_child(buy)
	content.add_child(card)
	return {"card": card, "bar": level_bar, "level": level, "effect": effect, "buy": buy}


func _refresh_all() -> void:
	if not is_inside_tree():
		return
	_wallet.count_to(SaveManager.coins())
	for i: int in _rows.size():
		var r: Dictionary = _rows[i]
		var lv: int = SaveManager.perm_level(i)
		(r["bar"] as AxBar).set_ratio(float(lv) / float(PermanentUpgrades.MAX_LEVEL), false)
		(r["level"] as Label).text = Loc.t("level_of", [lv, PermanentUpgrades.MAX_LEVEL])
		var buy: AxButton = r["buy"] as AxButton
		var effect: Label = r["effect"] as Label
		if PermanentUpgrades.is_max(lv):
			effect.text = "%s  ·  %s" % [PermanentUpgrades.format_total(i, lv), Loc.t("max_level")]
			buy.icon_name = ""
			buy.text = Loc.t("max")
			buy.disabled = true
		else:
			effect.text = Loc.t(
				"now_next",
				[PermanentUpgrades.format_total(i, lv), PermanentUpgrades.format_total(i, lv + 1)]
			)
			buy.icon_name = "coin_s"
			buy.text = str(SaveManager.perm_cost(i))
			buy.disabled = false
			buy.style = "yellow" if SaveManager.can_buy(i) else "red"


func _on_buy(i: int) -> void:
	if SaveManager.buy_permanent(i):
		AudioManager.play_ui(&"ui_buy")
		var card: Control = _rows[i]["card"] as Control
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(1.04, 1.04)
		(
			create_tween()
			. tween_property(card, "scale", Vector2.ONE, 0.3)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		purchased.emit(i)
	else:
		AudioManager.play_ui(&"ui_denied")
		UIManager.toast(Loc.t("not_enough"))
		var card2: Control = _rows[i]["card"] as Control
		var base: float = card2.position.x
		var t: Tween = create_tween()
		for dx: float in [14.0, -14.0, 9.0, -9.0, 0.0]:
			t.tween_property(card2, "position:x", base + dx, 0.04)
