class_name Arena
extends Node3D
## Décor de la plage : île de sable (modèle Blender arena_beach.glb), mer animée, arrière-plan
## horizon (HorizonBackdrop) et objets de plage (blender/source/decor.py).
##
## Phase 7 : toute l'île est l'arène. Plus de bouée-rebord (le mesh `Rim` du modèle est masqué) ;
## le rivage réel (IslandShape) est la seule limite. L'île est mise à l'échelle de
## `arena_radius / IslandShape.MODEL_PLAY_RADIUS`, le décor garde ses tailles en MÈTRES (système de
## tailles cohérent : voir docs/SIZE_SYSTEM.md).
const MODEL_RADIUS: float = IslandShape.MODEL_PLAY_RADIUS
## Hauteur de la ligne d'eau dans le modèle (la pente de l'île passe dessous) : cf. ground_z() dans
## Blender.
const WATER_LEVEL: float = -0.28
const SAND_TEXTURE: Texture2D = preload("res://assets/textures/sand.png")
const OCEAN_SHADER: Shader = preload("res://assets/shaders/ax_ocean.gdshader")
const WATER_NOISE: Texture2D = preload("res://assets/textures/water_noise.png")

## Décor. `angle` : degrés depuis le haut de l'écran (-Z) vers la droite ; `in` : distance (m) en
## retrait du rivage (négatif = dans l'eau) ; `scale` : échelle du modèle (taille cible en mètres :
## docs/SIZE_SYSTEM.md) ; `solid` : rayon (m) du cercle d'obstacle (0 = traversable).
## Règle de visibilité : la caméra regarde vers le nord (-Z) depuis le sud, donc les éléments HAUTS
## (palmiers, parasols, château) restent dans la moitié nord et sur les côtés ; le sud n'a que du
## bas (serviettes, coquillages, petits rochers) pour ne jamais cacher le joueur.
const DECOR: Array[Dictionary] = [
	{"model": "deco_palm", "angle": -70.0, "in": 2.6, "yaw": 20.0, "scale": 1.05, "solid": 0.45},
	{"model": "deco_palm", "angle": -38.0, "in": 2.2, "yaw": -35.0, "scale": 1.2, "solid": 0.45},
	{"model": "deco_palm", "angle": -8.0, "in": 2.9, "yaw": 80.0, "scale": 0.95, "solid": 0.45},
	{"model": "deco_palm", "angle": 24.0, "in": 2.1, "yaw": 10.0, "scale": 1.15, "solid": 0.45},
	{"model": "deco_palm", "angle": 58.0, "in": 2.7, "yaw": -60.0, "scale": 1.05, "solid": 0.45},
	{"model": "deco_palm", "angle": 92.0, "in": 2.4, "yaw": 40.0, "scale": 0.95, "solid": 0.45},
	{"model": "deco_palm", "angle": -98.0, "in": 2.5, "yaw": 140.0, "scale": 1.0, "solid": 0.45},
	{"model": "deco_umbrella", "angle": -21.0, "in": 5.4, "yaw": 15.0, "scale": 0.78, "solid": 0.3},
	{"model": "deco_towel", "angle": -14.0, "in": 7.6, "yaw": 12.0, "scale": 0.8, "solid": 0.0},
	{
		"model": "deco_sandcastle",
		"angle": 41.0,
		"in": 4.8,
		"yaw": 200.0,
		"scale": 0.58,
		"solid": 1.0
	},
	{"model": "deco_bucket", "angle": 35.0, "in": 7.2, "yaw": 35.0, "scale": 0.55, "solid": 0.0},
	{"model": "deco_rock", "angle": -88.0, "in": 1.6, "yaw": 20.0, "scale": 0.9, "solid": 0.9},
	{"model": "deco_rock", "angle": 77.0, "in": 1.2, "yaw": 200.0, "scale": 0.85, "solid": 0.85},
	{"model": "deco_ball", "angle": -52.0, "in": 4.6, "yaw": 0.0, "scale": 0.8, "solid": 0.0},
	{"model": "deco_starfish", "angle": 8.0, "in": 8.4, "yaw": 40.0, "scale": 0.8, "solid": 0.0},
	{"model": "deco_shell", "angle": -60.0, "in": 6.8, "yaw": 70.0, "scale": 0.6, "solid": 0.0},
	{"model": "deco_surfboard", "angle": 104.0, "in": 3.1, "yaw": 85.0, "scale": 0.9, "solid": 0.0},
	{
		"model": "deco_surfboard",
		"angle": -112.0,
		"in": 2.8,
		"yaw": -80.0,
		"scale": 0.9,
		"solid": 0.0
	},
	{"model": "deco_towel", "angle": 165.0, "in": 6.6, "yaw": -18.0, "scale": 0.8, "solid": 0.0},
	{"model": "deco_towel", "angle": -148.0, "in": 5.6, "yaw": 25.0, "scale": 0.8, "solid": 0.0},
	{"model": "deco_ball", "angle": 138.0, "in": 4.0, "yaw": 0.0, "scale": 0.8, "solid": 0.0},
	{"model": "deco_bucket", "angle": -172.0, "in": 5.0, "yaw": 35.0, "scale": 0.5, "solid": 0.0},
	{"model": "deco_starfish", "angle": 122.0, "in": 5.4, "yaw": 10.0, "scale": 0.75, "solid": 0.0},
	{"model": "deco_starfish", "angle": 202.0, "in": 7.0, "yaw": 100.0, "scale": 0.7, "solid": 0.0},
	{"model": "deco_shell", "angle": 154.0, "in": 3.4, "yaw": 150.0, "scale": 0.6, "solid": 0.0},
	{"model": "deco_shell", "angle": -126.0, "in": 4.2, "yaw": 20.0, "scale": 0.6, "solid": 0.0},
	{"model": "deco_rock", "angle": 180.0, "in": 1.3, "yaw": 90.0, "scale": 0.45, "solid": 0.5},
	{"model": "deco_rock", "angle": -136.0, "in": 1.5, "yaw": 60.0, "scale": 0.5, "solid": 0.55},
	{"model": "deco_rock", "angle": 148.0, "in": 1.4, "yaw": 10.0, "scale": 0.5, "solid": 0.55},
	# Dans l'eau : rochers au large (jamais atteints, ils donnent de la profondeur à la mer).
	{"model": "deco_rock", "angle": 160.0, "in": -4.4, "yaw": 30.0, "scale": 1.0, "solid": 0.0},
	{"model": "deco_rock", "angle": -162.0, "in": -5.4, "yaw": 150.0, "scale": 1.25, "solid": 0.0},
	{"model": "deco_rock", "angle": 14.0, "in": -4.6, "yaw": 80.0, "scale": 1.1, "solid": 0.0},
	{"model": "deco_rock", "angle": -64.0, "in": -6.0, "yaw": 10.0, "scale": 1.4, "solid": 0.0},
]

var ocean_material: ShaderMaterial
var backdrop: HorizonBackdrop


## `ctx` (facultatif) : reçoit les obstacles solides du décor. Le menu principal appelle sans
## contexte.
func setup(cfg: GameConfig, ctx: RunContext = null) -> void:
	var k: float = cfg.island_scale()
	var shape: IslandShape = ctx.shape if ctx != null else IslandShape.new(k)
	var island: Node3D = Node3D.new()
	island.name = "Island"
	island.scale = Vector3.ONE * k
	add_child(island)

	var ground: ModelRig = ModelRig.create("arena_beach")
	if ground != null:
		island.add_child(ground.root)
		var sand: ShaderMaterial = ModelRig.PALETTE.duplicate() as ShaderMaterial
		sand.set_shader_parameter(&"albedo_tex", SAND_TEXTURE)
		sand.set_shader_parameter(&"rim_strength", 0.06)
		sand.set_shader_parameter(&"spec_strength", 0.0)
		sand.set_shader_parameter(&"saturation", 1.0)
		sand.set_shader_parameter(&"brightness", 0.86)
		# pas de contour sur le sol (la coque inversée ne vaut que pour les personnages)
		sand.next_pass = null
		var ground_mesh: MeshInstance3D = (
			ground.root.find_child("Ground", true, false) as MeshInstance3D
		)
		if ground_mesh != null:
			ground_mesh.material_override = sand
		# Phase 7 : plus de bordure d'arène. La bouée-rebord du modèle est retirée.
		var rim: Node = ground.root.find_child("Rim", true, false)
		if rim != null:
			rim.queue_free()

	ocean_material = ShaderMaterial.new()
	ocean_material.shader = OCEAN_SHADER
	ocean_material.set_shader_parameter(&"noise_tex", WATER_NOISE)
	ocean_material.set_shader_parameter(&"model_scale", k)
	_apply_quality()
	EventBus.quality_changed.connect(func(_t: int) -> void: _apply_quality())
	var sea: ModelRig = ModelRig.create("ocean")
	if sea != null:
		for n: Node in sea.root.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).material_override = ocean_material
		sea.root.position.y = WATER_LEVEL * k
		sea.root.scale = Vector3.ONE * k
		add_child(sea.root)

	backdrop = HorizonBackdrop.new()
	add_child(backdrop)
	backdrop.setup(WATER_LEVEL * k)

	for entry: Dictionary in DECOR:
		var rig: ModelRig = ModelRig.create(entry["model"] as String)
		if rig == null:
			continue
		var theta: float = deg_to_rad(entry["angle"] as float)
		var r: float = shape.edge(theta) - (entry["in"] as float)
		var pos: Vector2 = IslandShape.point(theta, r)
		rig.root.position = Vector3(pos.x, 0.0, pos.y)
		rig.root.rotation.y = deg_to_rad(entry["yaw"] as float)
		rig.root.scale = Vector3.ONE * (entry["scale"] as float)
		add_child(rig.root)
		if ctx != null and (entry["solid"] as float) > 0.0:
			ctx.obstacles.add(pos, entry["solid"] as float)


## Détail de la mer selon le profil de qualité (la mer couvre une grande part de l'écran).
func _apply_quality() -> void:
	ocean_material.set_shader_parameter(&"detail", QualityManager.profile.ocean_detail)
	ocean_material.set_shader_parameter(
		&"sparkle", 1.0 if QualityManager.profile.water_sparkles else 0.0
	)
