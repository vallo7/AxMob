class_name TurretLeveling
extends RefCounted
## Construit la table de niveaux d'une catégorie de tourelle à partir de ses courbes, ou renvoie
## la table écrite à la main. Fonctions pures : testables sans moteur.

const MIN_PIERCE: int = 0


static func build(data: TurretData) -> Array[TurretLevelData]:
	if not data.levels.is_empty():
		return data.levels
	var out: Array[TurretLevelData] = []
	var count: int = maxi(data.max_level, 1)
	for level: int in range(1, count + 1):
		var n: float = float(level - 1)
		var row: TurretLevelData = TurretLevelData.new()
		row.level = level
		row.damage = data.damage * pow(data.damage_growth, n)
		row.fire_rate = data.fire_rate * pow(data.rate_growth, n)
		row.attack_range = data.attack_range * pow(data.range_growth, n)
		row.rotation_speed = data.rotation_speed * pow(data.rotation_growth, n)
		row.projectile_speed_mult = pow(data.projectile_speed_growth, n)
		row.axe_count = _step(data.axe_count_steps, level, data.axe_count)
		row.pierce = _step(data.pierce_steps, level, data.pierce)
		var extra: int = maxi(row.axe_count - maxi(data.axe_count, 1), 0)
		row.fan_angle_deg = data.fan_angle_deg + data.fan_per_extra_deg * float(extra)
		if row.axe_count <= 1:
			row.fan_angle_deg = 0.0
		row.visual_tier = tier_of(data, level)
		if data.projectile != null:
			row.splash_radius = data.projectile.splash_radius * pow(data.splash_growth, n)
		out.append(row)
	return out


static func tier_of(data: TurretData, level: int) -> int:
	var tier: int = 0
	for i: int in data.tier_levels.size():
		if level >= data.tier_levels[i]:
			tier = i
	return tier


static func _step(steps: PackedInt32Array, level: int, fallback: int) -> int:
	if steps.is_empty():
		return fallback
	return steps[mini(level - 1, steps.size() - 1)]


## Lignes lisibles « Dégâts 9.4 → 11.0 » pour l'écran d'amélioration. `next` peut être null
## (niveau maximal) : on n'affiche alors que la valeur actuelle.
static func describe(now: TurretLevelData, next: TurretLevelData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(_line("Dégâts", now.damage, next.damage if next != null else -1.0, "%.1f"))
	lines.append(
		_line("Cadence", now.fire_rate, next.fire_rate if next != null else -1.0, "%.2f/s")
	)
	lines.append(
		_line("Portée", now.attack_range, next.attack_range if next != null else -1.0, "%.1f")
	)
	var next_axes: int = next.axe_count if next != null else -1
	lines.append(_line_int("Haches", now.axe_count, next_axes))
	if now.splash_radius > 0.0:
		lines.append(
			_line("Zone", now.splash_radius, next.splash_radius if next != null else -1.0, "%.1f m")
		)
	if now.pierce > 0 or (next != null and next.pierce > 0):
		var next_pierce: int = next.pierce if next != null else -1
		lines.append(_line_int("Perforation", now.pierce, next_pierce))
	return lines


static func _line(label: String, now_v: float, next_v: float, fmt: String) -> String:
	var a: String = fmt % now_v
	if next_v < 0.0 or is_equal_approx(now_v, next_v):
		return "%s  %s" % [label, a]
	return "%s  %s → %s" % [label, a, fmt % next_v]


static func _line_int(label: String, now_v: int, next_v: int) -> String:
	if next_v < 0 or now_v == next_v:
		return "%s  %d" % [label, now_v]
	return "%s  %d → %d" % [label, now_v, next_v]
