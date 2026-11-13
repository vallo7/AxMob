class_name PermanentUpgrades
extends RefCounted
## Améliorations PERMANENTES (menu principal, cahier des charges §7.2) : PV max, puissance initiale
## des tourelles, cadence initiale, bonus de pièces, vitesse de déplacement.
## Coût du niveau n -> n+1 = base x multiplicateur^n (même forme que les tourelles en partie).
## TOUTES ces valeurs sont PROVISOIRES : à régler avec tes parties (équilibrage non testé).

const MAX_LEVEL: int = 10

## id, icône, coût de base, multiplicateur, bonus par niveau, unité d'affichage.
const DEFS: Array[Dictionary] = [
	{"id": "hp", "icon": "heart", "base": 60, "mult": 1.5, "per": 8.0, "unit": "hp"},
	{"id": "power", "icon": "model_axe_heavy", "base": 80, "mult": 1.5, "per": 0.06, "unit": "pct"},
	{"id": "rate", "icon": "bolt", "base": 80, "mult": 1.5, "per": 0.04, "unit": "pct"},
	{"id": "coins", "icon": "coin_plus", "base": 100, "mult": 1.5, "per": 0.05, "unit": "pct"},
	{"id": "speed", "icon": "speed_blue", "base": 70, "mult": 1.5, "per": 0.025, "unit": "pct"},
]


static func count() -> int:
	return DEFS.size()


static func id_of(index: int) -> String:
	return DEFS[index]["id"] as String


static func is_max(level: int) -> bool:
	return level >= MAX_LEVEL


## Coût pour passer de `level` à `level + 1` ; -1 au niveau maximal.
static func cost(index: int, level: int) -> int:
	if is_max(level):
		return -1
	var d: Dictionary = DEFS[index]
	return int(round(float(d["base"]) * pow(float(d["mult"]), float(level))))


## Bonus TOTAL au niveau `level` (PV : points ; autres : fraction, 0.12 = +12 %).
static func total_at(index: int, level: int) -> float:
	return float(DEFS[index]["per"]) * float(clampi(level, 0, MAX_LEVEL))


## Texte du bonus (« +24 PV », « +12 % »).
static func format_total(index: int, level: int) -> String:
	var v: float = total_at(index, level)
	if DEFS[index]["unit"] == "hp":
		return "+%d %s" % [int(round(v)), Loc.t("unit_hp")]
	return "+%d %%" % int(round(v * 100.0))


static func bonuses(levels: PackedInt32Array) -> PermanentBonuses:
	var b: PermanentBonuses = PermanentBonuses.new()
	b.hp_add = total_at(0, _lv(levels, 0))
	b.power_mult = 1.0 + total_at(1, _lv(levels, 1))
	b.rate_mult = 1.0 + total_at(2, _lv(levels, 2))
	b.coin_mult = 1.0 + total_at(3, _lv(levels, 3))
	b.speed_mult = 1.0 + total_at(4, _lv(levels, 4))
	return b


static func _lv(levels: PackedInt32Array, i: int) -> int:
	return levels[i] if i < levels.size() else 0
