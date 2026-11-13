class_name HorizonBackdrop
extends Node3D
## Arrière-plan de la scène 3D (phase 7) : tout ce qu'on voit APRÈS la mer de l'île.
## - ciel dégradé aux couleurs du logo (or/crème à l'horizon, pervenche puis indigo), soleil
## cartoon ;
##  - mer lointaine qui prolonge la mer animée jusqu'à l'horizon, noyée dans une brume dorée ;
##  - petites îles lointaines (silhouettes pâles, perspective atmosphérique) ;
##  - nuages dessinés qui dérivent très lentement.
## Le dôme et la mer lointaine suivent la caméra (ils paraissent infiniment loin) ; les îles et les
## nuages restent à leur place. Tout est procédural (aucun modèle) : coût négligeable.

const SKY_SHADER: Shader = preload("res://assets/shaders/ax_sky.gdshader")
const SEA_SHADER: Shader = preload("res://assets/shaders/ax_far_sea.gdshader")
const ISLAND_SHADER: Shader = preload("res://assets/shaders/ax_island_far.gdshader")
const CLOUD_TEXTURE: Texture2D = preload("res://assets/textures/clouds.png")

const DOME_RADIUS: float = 900.0
const SEA_RADIUS: float = 1500.0
## (angle depuis le haut de l'écran en degrés, distance m, rayon de base m, hauteur m, graine)
const ISLANDS: Array[Array] = [
	[-52.0, 150.0, 34.0, 26.0, 11],
	[-18.0, 205.0, 46.0, 38.0, 23],
	[22.0, 170.0, 30.0, 22.0, 37],
	[58.0, 235.0, 50.0, 34.0, 41],
	[-88.0, 260.0, 52.0, 30.0, 53],
	[96.0, 190.0, 28.0, 18.0, 67],
]
## (angle, distance, hauteur, largeur, forme 0..2)
const CLOUDS: Array[Array] = [
	[-70.0, 430.0, 95.0, 120.0, 0],
	[-38.0, 520.0, 130.0, 160.0, 1],
	[-10.0, 470.0, 105.0, 130.0, 2],
	[18.0, 540.0, 140.0, 170.0, 0],
	[46.0, 450.0, 100.0, 125.0, 1],
	[74.0, 500.0, 120.0, 150.0, 2],
	[-100.0, 480.0, 110.0, 140.0, 1],
	[102.0, 520.0, 125.0, 150.0, 0],
]

var _dome: MeshInstance3D
var _sea: MeshInstance3D
var _clouds: Node3D
var _sea_y: float = 0.0


## `sea_y` : hauteur de la mer (m). `sun_plan` : direction du soleil sur le plan XZ.
func setup(sea_y: float) -> void:
	_sea_y = sea_y
	name = "HorizonBackdrop"
	_build_dome()
	_build_far_sea()
	_build_islands()
	_build_clouds()


func _process(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var c: Vector3 = cam.global_position
		_dome.global_position = c
		_sea.global_position = Vector3(c.x, _sea_y - 0.06, c.z)
	_clouds.rotation.y += delta * 0.0016


func _build_dome() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = DOME_RADIUS
	sphere.height = DOME_RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.render_priority = -100
	_dome = MeshInstance3D.new()
	_dome.name = "Sky"
	_dome.mesh = sphere
	_dome.material_override = mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dome.extra_cull_margin = 16384.0
	add_child(_dome)


func _build_far_sea() -> void:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = SEA_RADIUS
	disc.bottom_radius = SEA_RADIUS
	disc.height = 0.01
	disc.radial_segments = 48
	disc.rings = 1
	disc.cap_bottom = false
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SEA_SHADER
	mat.render_priority = -50
	_sea = MeshInstance3D.new()
	_sea.name = "FarSea"
	_sea.mesh = disc
	_sea.material_override = mat
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sea.extra_cull_margin = 16384.0
	add_child(_sea)


func _build_islands() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "FarIslands"
	add_child(holder)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = ISLAND_SHADER
	for def: Array in ISLANDS:
		var angle: float = deg_to_rad(def[0] as float)
		var dist: float = def[1] as float
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.mesh = _island_mesh(def[2] as float, def[3] as float, def[4] as int)
		inst.material_override = mat
		inst.position = Vector3(sin(angle) * dist, _sea_y, -cos(angle) * dist)
		inst.rotation.y = float(def[4] as int) * 0.7
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(inst)


## Île en forme de cône bosselé : couronnes concentriques, rayon et hauteur modulés par un bruit
## simple.
func _island_mesh(base_radius: float, height: float, seed_value: int) -> ArrayMesh:
	var rings: int = 7
	var segs: int = 20
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var phase: Array[float] = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var peaks: Array[Vector3] = []
	for i: int in 3:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(0.0, base_radius * 0.35)
		peaks.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[Array] = []
	for ri: int in rings + 1:
		var row: Array[Vector3] = []
		var t: float = float(ri) / float(rings)
		for si: int in segs:
			var a2: float = TAU * float(si) / float(segs)
			var wob: float = 1.0 + 0.16 * sin(a2 * 3.0 + phase[0]) + 0.08 * sin(a2 * 5.0 + phase[1])
			var radius: float = base_radius * wob * (1.0 - t * 0.92)
			var x: float = cos(a2) * radius
			var z: float = sin(a2) * radius
			var hgt: float = 0.0
			if ri > 0:
				var best: float = 0.0
				for k: int in 3:
					var d: float = Vector2(x - peaks[k].x, z - peaks[k].z).length() / base_radius
					best = maxf(best, (1.0 - clampf(d * 1.15, 0.0, 1.0)) * (1.0 - 0.28 * float(k)))
				hgt = height * pow(best, 0.85) * smoothstep(0.0, 0.25, t)
			row.append(Vector3(x, hgt - (0.8 if ri == 0 else 0.0), z))
		grid.append(row)
	for ri2: int in rings:
		for si2: int in segs:
			var s2: int = (si2 + 1) % segs
			var a: Vector3 = grid[ri2][si2]
			var b: Vector3 = grid[ri2][s2]
			var c: Vector3 = grid[ri2 + 1][s2]
			var d2: Vector3 = grid[ri2 + 1][si2]
			for v: Vector3 in [a, c, b, a, d2, c]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _build_clouds() -> void:
	_clouds = Node3D.new()
	_clouds.name = "Clouds"
	add_child(_clouds)
	var mats: Array[StandardMaterial3D] = []
	for i: int in 3:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = CLOUD_TEXTURE
		m.uv1_scale = Vector3(1.0 / 3.0, 1.0, 1.0)
		m.uv1_offset = Vector3(float(i) / 3.0, 0.0, 0.0)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.94)
		mats.append(m)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.5)
	for def: Array in CLOUDS:
		var angle: float = deg_to_rad(def[0] as float)
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.mesh = quad
		inst.material_override = mats[def[4] as int]
		var width: float = def[3] as float
		inst.scale = Vector3(width, width, 1.0)
		var dist: float = def[1] as float
		inst.position = Vector3(sin(angle) * dist, _sea_y + (def[2] as float), -cos(angle) * dist)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_clouds.add_child(inst)
