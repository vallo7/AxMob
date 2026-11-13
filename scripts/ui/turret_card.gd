class_name TurretCard
extends Control
## Carte d'une catégorie de tourelle (phase 6) : icône de hache, nom, niveau, statistiques
## actuelles → suivantes (aperçu du changement), bouton d'amélioration avec le coût en pièces.

signal upgrade_pressed(turret_id: int)

const CARD_SIZE: Vector2 = Vector2(500.0, 336.0)
const MAX_LINES: int = 5
const ICONS: Array[String] = [
	"model_axe_rapid", "model_axe_heavy", "model_axe_multi", "model_axe_pierce"
]

var turret_id: int = 0

var _data: TurretData
var _name: Label
var _level: Label
var _lines: Array[Label] = []
var _button: AxButton
var _shown_level: int = -1


func setup(id: int, data: TurretData) -> void:
	turret_id = id
	_data = data
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	add_child(UiArt.nine("panels/panel_card", 56, 56, 56, 62))
	var icon: TextureRect = UiArt.image("icons/" + ICONS[id % ICONS.size()], Vector2(92, 92))
	icon.position = Vector2(20.0, 14.0)
	icon.size = Vector2(92, 92)
	add_child(icon)
	_name = UiArt.label(
		(
			Loc.t("tur_name_" + str(data.id)).to_upper()
			if Loc.has_key("tur_name_" + str(data.id))
			else data.display_name.to_upper()
		),
		34,
		UiArt.TEXT_DARK,
		Color(1, 1, 1, 0),
		0
	)
	_name.position = Vector2(116.0, 16.0)
	_name.size = Vector2(250.0, 44.0)
	_name.clip_text = true
	add_child(_name)
	_level = UiArt.label("", 30, data.color.darkened(0.25), Color(1, 1, 1, 0), 0)
	_level.position = Vector2(116.0, 58.0)
	_level.size = Vector2(250.0, 40.0)
	add_child(_level)
	for i: int in MAX_LINES:
		var line: Label = UiArt.label("", 25, UiArt.TEXT_DARK, Color(1, 1, 1, 0), 0)
		line.position = Vector2(30.0, 102.0 + 28.0 * float(i))
		line.size = Vector2(CARD_SIZE.x - 60.0, 30.0)
		add_child(line)
		_lines.append(line)
	_button = AxButton.make("", "gold", Vector2(CARD_SIZE.x - 36.0, 84.0), 34, "coin_s")
	_button.small = true
	_button.position = Vector2(18.0, CARD_SIZE.y - 98.0)
	_button.pressed.connect(func() -> void: upgrade_pressed.emit(turret_id))
	add_child(_button)


func refresh(ctx: RunContext, upgrades: UpgradeManager) -> void:
	var level: int = ctx.turret_levels[turret_id]
	var max_level: int = ctx.turret_max_level(turret_id)
	_level.text = Loc.t("tur_level", [level, max_level])
	if _shown_level >= 0 and level > _shown_level:
		pivot_offset = size * 0.5
		scale = Vector2(1.06, 1.06)
		(
			create_tween()
			. tween_property(self, "scale", Vector2.ONE, 0.3)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	_shown_level = level
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
		_button.icon_name = ""
		_button.text = Loc.t("tur_max")
		_button.disabled = true
		return
	_button.disabled = false
	_button.icon_name = "coin_s"
	_button.text = "%d" % cost
	# Pas assez de pièces : le bouton reste actif (le toast explique), mais passe en rouge.
	_button.style = "gold" if upgrades.can_upgrade(turret_id) else "stone"
