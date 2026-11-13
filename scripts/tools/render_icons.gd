extends SceneTree
## Outil (phase 7) : rend les modèles 3D des haches et des tourelles en icônes PNG transparentes
## (assets/ui/icons/model_*.png). Les icônes d'interface des haches SONT donc les modèles du jeu.
## Lancer avec un rendu (pas --headless) :
## xvfb-run -a godot --rendering-driver opengl3 --path . --script
## res://scripts/tools/render_icons.gd

const OUT_DIR: String = "res://assets/ui/icons/"
const SIZE: int = 320
## nom du modèle -> [sortie, yaw (°), pitch (°), roulis écran (°)]
const JOBS: Array[Array] = [
	["axe_light", "model_axe_rapid", 38.0, 52.0, 32.0],
	["axe_heavy", "model_axe_heavy", 38.0, 52.0, 32.0],
	["axe_multi", "model_axe_multi", 38.0, 52.0, 32.0],
	["axe_pierce", "model_axe_pierce", 38.0, 52.0, 32.0],
	["turret_rapid", "model_turret_rapid", -35.0, 34.0, 0.0],
	["turret_heavy", "model_turret_heavy", -35.0, 34.0, 0.0],
	["turret_multi", "model_turret_multi", -35.0, 34.0, 0.0],
	["turret_pierce", "model_turret_pierce", -35.0, 34.0, 0.0],
]

var _done: bool = false


func _initialize() -> void:
	root.transparent_bg = true


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	_render_all()
	return false


func _render_all() -> void:
	for job: Array in JOBS:
		await _render(
			job[0] as String, job[1] as String, job[2] as float, job[3] as float, job[4] as float
		)
	print("[icons] terminé")
	quit()


func _render(model: String, out_name: String, yaw: float, pitch: float, roll: float) -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var rig: ModelRig = ModelRig.create(model)
	if rig == null:
		push_error("modèle introuvable : %s" % model)
		vp.queue_free()
		return
	var holder: Node3D = Node3D.new()
	vp.add_child(holder)
	holder.add_child(rig.root)
	# Pas de palier/pièce cachée : on montre le modèle de base (tourelle : tous les paliers visibles).
	for tier: String in ["Tier_1", "Tier_2", "Tier_3"]:
		var part: Node = rig.root.find_child(tier, true, false)
		if part is Node3D:
			(part as Node3D).visible = tier != "Tier_3"
	holder.rotation_degrees = Vector3(0.0, yaw, 0.0)
	var box: AABB = _bounds(holder)
	var center: Vector3 = box.get_center()
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.97, 0.9)
	e.ambient_light_energy = 0.42
	env.environment = e
	vp.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.light_energy = 1.25
	vp.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var dir: Vector3 = Vector3(0.0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch)))
	cam.position = center + dir * 10.0
	vp.add_child(cam)
	cam.look_at(center, Vector3.UP)
	cam.rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(roll))
	cam.current = true
	# Cadrage serré : on projette les 8 coins de la boîte dans le plan de la caméra.
	var inv: Transform3D = cam.global_transform.affine_inverse()
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for corner_i: int in 8:
		var c: Vector3 = (
			box.position
			+ Vector3(
				box.size.x * float(corner_i & 1),
				box.size.y * float((corner_i >> 1) & 1),
				box.size.z * float((corner_i >> 2) & 1)
			)
		)
		var q: Vector3 = inv * c
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	cam.size = maxf(hi.x - lo.x, hi.y - lo.y) * 1.14
	cam.position += (
		cam.global_transform.basis.x * ((lo.x + hi.x) * 0.5)
		+ cam.global_transform.basis.y * ((lo.y + hi.y) * 0.5)
	)
	for i: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + out_name + ".png"))
	print("[icons] ", out_name, " ", img.get_size())
	vp.queue_free()


func _bounds(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box
