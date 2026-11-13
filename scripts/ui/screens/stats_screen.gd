class_name StatsScreen
extends AxScreen
## Statistiques et records (cahier des charges §7.3 et §10.8), lus dans SaveManager.


func _init() -> void:
	banner = "blue"


func _ready() -> void:
	title = Loc.t("statistics")
	super._ready()


static func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%d:%02d" % [m, total % 60]


func build() -> void:
	var d: SaveData = SaveManager.data
	_section(Loc.t("section_records"))
	_card_rows(
		[
			["trophy", Loc.t("stat_best_wave"), str(d.best_wave)],
			["clock", Loc.t("stat_best_time"), format_time(d.best_time)],
			["coin", Loc.t("stat_best_coins"), str(d.best_coins_run)],
			["skull", Loc.t("stat_best_kills"), str(d.best_kills_run)],
		]
	)
	_section(Loc.t("section_totals"))
	_card_rows(
		[
			["skull", Loc.t("stat_kills"), str(d.total_kills)],
			["coin", Loc.t("stat_coins"), str(d.total_coins_earned)],
			["skull_red", Loc.t("stat_bosses"), str(d.bosses_defeated)],
			["play", Loc.t("stat_games"), str(d.games_played)],
			["clock", Loc.t("stat_playtime"), format_time(d.total_play_time)],
		]
	)
	_section(Loc.t("section_recent"))
	if d.recent_runs.is_empty():
		var none: Label = UiArt.label(
			Loc.t("recent_empty"), 34, UiArt.TEXT_MUTED, Color(1, 1, 1, 0), 0
		)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(none)
	for run: Dictionary in d.recent_runs.slice(0, 5):
		content.add_child(_run_row(run))


## Titre de section : ruban de texte contourné, centré.
func _section(text: String) -> void:
	var l: Label = UiArt.label(text, 40, UiArt.GOLD, UiArt.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 76)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(l)


func _card_rows(entries: Array[Array]) -> void:
	for e: Array in entries:
		var card: Control = Control.new()
		card.custom_minimum_size = Vector2(0, 132)
		card.add_child(UiArt.nine("panels/panel_card", 56, 56, 56, 62))
		var h: HBoxContainer = HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 28.0
		h.offset_right = -34.0
		h.offset_top = 8.0
		h.offset_bottom = -20.0
		h.add_theme_constant_override(&"separation", 22)
		card.add_child(h)
		var ic: TextureRect = UiArt.image("icons/" + str(e[0]), Vector2(84, 84))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l: Label = UiArt.label(str(e[1]), 36, UiArt.TEXT_DARK, Color(1, 1, 1, 0), 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		var v: Label = UiArt.label(str(e[2]), 46, Color("#C46A00"), Color(1, 1, 1, 0), 0)
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(v)
		content.add_child(card)


## Ligne d'historique : vague, durée, éliminations, pièces (alignées en colonnes).
func _run_row(run: Dictionary) -> Control:
	var card: Control = Control.new()
	card.custom_minimum_size = Vector2(0, 112)
	card.add_child(UiArt.nine("panels/panel_card", 56, 56, 56, 62))
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 30.0
	h.offset_right = -30.0
	h.offset_top = 6.0
	h.offset_bottom = -18.0
	h.add_theme_constant_override(&"separation", 12)
	card.add_child(h)
	var cols: Array[Array] = [
		["trophy", Loc.t("wave_short") % int(run["wave"]), 1.0],
		["clock", format_time(float(run["time"])), 1.1],
		["skull", str(int(run["kills"])), 0.9],
		["coin", str(int(run["coins"])), 1.0],
	]
	for c: Array in cols:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_stretch_ratio = c[2] as float
		cell.add_theme_constant_override(&"separation", 6)
		var ic: TextureRect = UiArt.image("icons/" + str(c[0]), Vector2(44, 44))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(ic)
		var l: Label = UiArt.label(str(c[1]), 32, UiArt.TEXT_DARK, Color(1, 1, 1, 0), 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(l)
		h.add_child(cell)
	return card
