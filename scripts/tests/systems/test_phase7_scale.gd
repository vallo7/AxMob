extends RefCounted
## Phase 7 : système de tailles cohérent (docs/SIZE_SYSTEM.md). On mesure les VRAIS modèles (boîtes
## englobantes des GLB) et on vérifie les rapports entre le héros, les ennemis, les canons et le
## décor
## (1 unité = 1 mètre). Les zones de collision correspondent à ce qu'on voit.

const HERO_MIN: float = 1.9
const HERO_MAX: float = 2.5

var t: Object


func _size_of(model: String) -> Vector3:
	var rig: ModelRig = ModelRig.create(model)
	if rig == null:
		return Vector3.ZERO
	var box: AABB = AABB()
	var first: bool = true
	for n: Node in rig.root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var xf: Transform3D = Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != rig.root:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	rig.root.free()
	return box.size


func _hero_height() -> float:
	return _size_of("char_player").y * PlayerController.VISUAL_SCALE


func test_hero_height_is_the_unit_of_the_scale_system() -> void:
	var h: float = _hero_height()
	print("[scale] héros : %.2f m" % h)
	t.call(
		"check",
		h >= HERO_MIN and h <= HERO_MAX,
		"héros : %.2f m (%.1f à %.1f)" % [h, HERO_MIN, HERO_MAX]
	)
	t.call(
		"check",
		absf(DataRegistry.config().player_radius * 2.0 - 1.0) < 0.2,
		"hitbox du héros : environ 1 m de diamètre"
	)


func test_enemy_footprints_match_their_hitboxes_and_ordering() -> void:
	var hero: float = _hero_height()
	var heights: Dictionary = {}
	for data: EnemyData in DataRegistry.enemies():
		var size: Vector3 = _size_of(data.model()) * data.visual_scale
		var small: float = minf(size.x, size.z)
		var large: float = maxf(size.x, size.z)
		var diameter: float = data.radius * 2.0
		print(
			(
				"[scale] %s : %.2f x %.2f x %.2f m, rayon %.2f"
				% [data.id, size.x, size.y, size.z, data.radius]
			)
		)
		t.call(
			"check",
			small / diameter >= 0.8 and small / diameter <= 1.6,
			"%s : empreinte %.2f m pour une hitbox de %.2f m" % [data.id, small, diameter]
		)
		t.call(
			"check",
			large / diameter <= 2.3,
			"%s : pas de membres démesurés (%.2f)" % [data.id, large / diameter]
		)
		t.call(
			"check",
			absf(data.height - size.y) <= maxf(0.35, size.y * 0.3),
			"%s : hauteur de barre de vie cohérente (%.2f / %.2f)" % [data.id, data.height, size.y]
		)
		heights[data.id] = size.y
	for id: Variant in heights.keys():
		t.call("check", float(heights[id]) <= hero * 1.0, "%s plus bas que le héros" % str(id))
	var boss: EnemyData = DataRegistry.wave_table().boss
	var boss_size: Vector3 = _size_of(boss.model()) * boss.visual_scale
	print(
		(
			"[scale] boss : %.2f x %.2f x %.2f m, rayon %.2f"
			% [boss_size.x, boss_size.y, boss_size.z, boss.radius]
		)
	)
	t.call(
		"check",
		boss_size.y >= hero * 1.5,
		"le boss domine le héros (%.1f m, >= 1,5x)" % boss_size.y
	)
	var bd: float = boss.radius * 2.0
	t.call(
		"check",
		minf(boss_size.x, boss_size.z) / bd >= 0.8 and maxf(boss_size.x, boss_size.z) / bd <= 2.3,
		"boss : empreinte cohérente avec sa hitbox"
	)


func test_turrets_and_decor_scale() -> void:
	var hero: float = _hero_height()
	for model: String in ["turret_rapid", "turret_heavy", "turret_multi", "turret_pierce"]:
		var size: Vector3 = _size_of(model) * Turret.TURRET_SCALE
		var width: float = maxf(size.x, size.z)
		t.call("check", width >= 2.2 and width <= 3.2, "%s : %.2f m de large" % [model, width])
		t.call(
			"check",
			size.y >= hero * 0.8 and size.y <= hero * 1.35,
			"%s : %.2f m de haut, comparable au héros" % [model, size.y]
		)
	var cfg: GameConfig = DataRegistry.config()
	t.call(
		"check",
		cfg.turret_collision_radius * 2.0 >= 2.0 and cfg.turret_collision_radius * 2.0 <= 2.8,
		"collision de la tourelle ~ son socle"
	)
	var props: Dictionary = {}
	for entry: Dictionary in Arena.DECOR:
		props[entry["model"]] = entry
	var palm: float = _size_of("deco_palm").y * float((props["deco_palm"] as Dictionary)["scale"])
	t.call(
		"check",
		palm >= hero * 2.0 and palm <= hero * 3.2,
		"palmier : %.1f m (2 à 3 fois le héros)" % palm
	)
	var umbrella: float = (
		_size_of("deco_umbrella").y * float((props["deco_umbrella"] as Dictionary)["scale"])
	)
	t.call(
		"check", umbrella >= hero * 0.9 and umbrella <= hero * 1.5, "parasol : %.1f m" % umbrella
	)
	for entry: Dictionary in Arena.DECOR:
		var solid: float = entry["solid"] as float
		if solid <= 0.0:
			continue
		var size: Vector3 = _size_of(entry["model"] as String) * float(entry["scale"])
		var foot: float = minf(size.x, size.z)
		t.call(
			"check",
			solid <= maxf(foot, 0.9) * 0.9 and solid >= 0.1,
			"%s : obstacle de rayon %.2f pour une base de %.2f m" % [entry["model"], solid, foot]
		)
	# Les haches sont lisibles à l'écran : ni minuscules ni plus grandes que le héros.
	for turret_data: TurretData in DataRegistry.turrets():
		var axe: ProjectileData = turret_data.projectile
		var axe_size: float = _size_of(axe.model()).length() * axe.visual_scale
		t.call(
			"check",
			axe_size >= 0.5 and axe_size <= hero * 1.1,
			"hache %s : %.2f m" % [turret_data.id, axe_size]
		)
