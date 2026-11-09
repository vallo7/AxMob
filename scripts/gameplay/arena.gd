class_name Arena
extends Node3D
## Décor de la plage (phase 4) : île de sable, bouée-rebord interrompue aux tourelles, mer
## animée et objets de plage posés HORS de la zone de jeu. Tous les modèles viennent de Blender
## (blender/source/arena_beach.py, decor.py). Le modèle d'arène est dessiné pour un rayon de
## jeu de 13 m : il est mis à l'échelle de `arena_radius / 13` (le décor suit).

const MODEL_RADIUS: float = 13.0
## Hauteur de la ligne d'eau (la pente de l'île passe dessous) : cf. ground_z() dans Blender.
const WATER_LEVEL: float = -0.28
const SAND_TEXTURE: Texture2D = preload("res://assets/textures/sand.png")
const OCEAN_SHADER: Shader = preload("res://assets/shaders/ax_ocean.gdshader")

## Objets de plage. `angle` : degrés depuis le haut de l'écran (-Z) vers la droite ; `r` : distance
## au centre en mètres du modèle d'arène (rayon de jeu 13) ; tous restent hors de la bouée.
const DECOR: Array[Dictionary] = [
	{"model": "deco_palm", "angle": -27.0, "r": 18.2, "yaw": 25.0, "scale": 1.15},
	{"model": "deco_palm", "angle": 31.0, "r": 19.0, "yaw": -60.0, "scale": 1.3},
	{"model": "deco_umbrella", "angle": -7.0, "r": 19.2, "yaw": 15.0, "scale": 1.2},
	{"model": "deco_towel", "angle": -3.0, "r": 16.6, "yaw": 12.0, "scale": 1.0},
	{"model": "deco_sandcastle", "angle": 13.0, "r": 17.3, "yaw": 160.0, "scale": 0.85},
	{"model": "deco_ball", "angle": -17.0, "r": 15.6, "yaw": 0.0, "scale": 1.0},
	{"model": "deco_starfish", "angle": 22.0, "r": 15.5, "yaw": 40.0, "scale": 1.1},
	{"model": "deco_shell", "angle": -40.0, "r": 15.7, "yaw": 70.0, "scale": 1.0},
	{"model": "deco_rock", "angle": -57.0, "r": 17.8, "yaw": 20.0, "scale": 1.1},
	{"model": "deco_palm", "angle": 142.0, "r": 19.3, "yaw": 80.0, "scale": 1.25},
	{"model": "deco_palm", "angle": 207.0, "r": 18.6, "yaw": -20.0, "scale": 1.1},
	{"model": "deco_umbrella", "angle": 163.0, "r": 18.6, "yaw": -25.0, "scale": 1.15},
	{"model": "deco_towel", "angle": 168.0, "r": 16.2, "yaw": -18.0, "scale": 1.0},
	{"model": "deco_bucket", "angle": 193.0, "r": 15.9, "yaw": 35.0, "scale": 1.0},
	{"model": "deco_surfboard", "angle": 181.0, "r": 18.4, "yaw": 5.0, "scale": 1.0},
	{"model": "deco_rock", "angle": 124.0, "r": 18.0, "yaw": 200.0, "scale": 1.2},
	{"model": "deco_starfish", "angle": 152.0, "r": 15.4, "yaw": 10.0, "scale": 1.0},
	{"model": "deco_shell", "angle": 218.0, "r": 15.5, "yaw": 150.0, "scale": 1.0},
	{"model": "deco_ball", "angle": 231.0, "r": 16.4, "yaw": 0.0, "scale": 1.0},
	{"model": "deco_rock", "angle": 245.0, "r": 18.2, "yaw": 90.0, "scale": 1.0},
]

var ocean_material: ShaderMaterial


func setup(cfg: GameConfig) -> void:
	var k: float = cfg.arena_radius / MODEL_RADIUS
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
		var ground_mesh: MeshInstance3D = (
			ground.root.find_child("Ground", true, false) as MeshInstance3D
		)
		if ground_mesh != null:
			ground_mesh.material_override = sand

	ocean_material = ShaderMaterial.new()
	ocean_material.shader = OCEAN_SHADER
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

	for entry: Dictionary in DECOR:
		var rig: ModelRig = ModelRig.create(entry["model"] as String)
		if rig == null:
			continue
		var a: float = deg_to_rad(entry["angle"] as float)
		var r: float = (entry["r"] as float) * k
		rig.root.position = Vector3(sin(a) * r, 0.0, -cos(a) * r)
		rig.root.rotation.y = deg_to_rad(entry["yaw"] as float)
		rig.root.scale = Vector3.ONE * (entry["scale"] as float) * k
		add_child(rig.root)


## Détail de la mer selon le profil de qualité (la mer couvre une grande part de l'écran).
func _apply_quality() -> void:
	ocean_material.set_shader_parameter(&"detail", QualityManager.profile.ocean_detail)
