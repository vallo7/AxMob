extends Node3D
## Feuilles de contrôle des modèles (rendu logiciel : xvfb + OpenGL), avec le MÊME matériau que
## le jeu. Pour chaque asset : vue 3/4, vue de face, vue de dessus et vue « caméra de jeu ».
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 640x640 --path . \
##     res://scenes/tools/asset_preview.tscn -- /tmp/previews crab[:anim[:t]] turtle ...
## Un asset peut être suivi d'une animation et d'un instant (en s) : `crab:run:0.2`.
## Sert au contrôle visuel ; ne remplace pas un test sur téléphone.

const VIEW: int = 400
const PALETTE: ShaderMaterial = preload("res://assets/materials/ax_palette.tres")

var _out_dir: String = "/tmp/axmob_previews"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_build_stage()
	for i: int in range(1, args.size()):
		await _shoot(args[i])
	get_tree().quit()


func _build_stage() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.86, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.86, 0.95)
	env.ambient_light_energy = 0.62
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	sun.light_energy = 0.9
	add_child(sun)


func _shoot(spec: String) -> void:
	var parts: PackedStringArray = spec.split(":")
	var asset: String = parts[0]
	var anim: String = parts[1] if parts.size() > 1 else ""
	var at: float = float(parts[2]) if parts.size() > 2 else 0.0
	var scene: PackedScene = load("res://assets/models/%s.glb" % asset) as PackedScene
	if scene == null:
		printerr("[preview] introuvable : %s" % asset)
		return
	var root: Node3D = scene.instantiate() as Node3D
	add_child(root)
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = PALETTE
	if anim != "":
		var player: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play(anim)
		player.advance(at)
	var box: AABB = _bounds(root)
	var center: Vector3 = box.get_center()
	var size: float = maxf(box.size.length(), 0.5)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var sheet: Image = Image.create(VIEW * 2, VIEW * 2, false, Image.FORMAT_RGB8)
	var views: Array[Vector3] = [
		Vector3(0.9, 0.7, 1.1),  # 3/4
		Vector3(0.0, 0.25, 1.0),  # face (l'avant du modèle est -Z : on voit le dos ; voir la 3/4)
		Vector3(0.0, 1.0, 0.001),  # dessus
		Vector3(0.0, 0.94, 0.34),  # caméra de jeu (pitch 70°)
	]
	views[1] = Vector3(0.0, 0.25, -1.0)
	for i: int in views.size():
		var dist: float = size * (1.9 if i < 3 else 1.5)
		cam.position = center + views[i].normalized() * dist
		cam.look_at(center, Vector3.UP if i != 2 else Vector3(0, 0, -1))
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var side: int = mini(img.get_width(), img.get_height())
		var crop: Image = img.get_region(
			Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side)
		)
		crop.resize(VIEW, VIEW, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(crop, Rect2i(0, 0, VIEW, VIEW), Vector2i((i % 2) * VIEW, (i / 2) * VIEW))
	var name: String = asset if anim == "" else "%s_%s_%.2f" % [asset, anim, at]
	sheet.save_png("%s/%s.png" % [_out_dir, name])
	print(
		(
			"[preview] %s/%s.png (%.2f x %.2f x %.2f m)"
			% [_out_dir, name, box.size.x, box.size.y, box.size.z]
		)
	)
	cam.queue_free()
	root.queue_free()


func _bounds(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var box: AABB = mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
