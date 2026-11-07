extends SceneTree
## Validation automatique des GLB (plan §6.3) : triangles, dimensions, animations, matériaux.
## godot --headless --script res://scripts/tools/validate_assets.gd   (code 1 si budget dépassé)

const BUDGETS_PATH: String = "res://assets/budgets.json"

var _errors: int = 0


func _initialize() -> void:
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS_PATH))
	for asset_name: String in budgets:
		if asset_name.begins_with("_"):
			continue
		_check_asset(asset_name, budgets[asset_name])
	print("[assets] %d erreur(s)" % _errors)
	quit(1 if _errors > 0 else 0)


func _fail(asset_name: String, msg: String) -> void:
	_errors += 1
	printerr("[ASSET FAIL] %s: %s" % [asset_name, msg])


func _check_asset(asset_name: String, b: Dictionary) -> void:
	var path: String = "res://assets/models/%s.glb" % asset_name
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		_fail(asset_name, "GLB introuvable ou non importé (%s)" % path)
		return
	var root: Node = scene.instantiate()
	var tris: int = 0
	var surfaces: int = 0
	var aabb: AABB = AABB()
	var mats: Dictionary = {}
	var skinned_meshes: int = 0
	var bad_uv: int = 0
	var names: Dictionary = {}
	for n: Node in _all_nodes(root):
		names[String(n.name)] = true
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			var mesh: Mesh = mi.mesh
			if mi.skin != null:
				skinned_meshes += 1
			var box: AABB = _to_root(mi, root) * mesh.get_aabb()
			aabb = box if aabb.size == Vector3.ZERO else aabb.merge(box)
			for s: int in mesh.get_surface_count():
				surfaces += 1
				var arrays: Array = mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += (
					idx.size() / 3
					if idx.size() > 0
					else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				)
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				for uv: Vector2 in uvs:
					if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
						bad_uv += 1
				var m: Material = mesh.surface_get_material(s)
				mats[m.resource_name if m != null else "<none>"] = true
	var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	print(
		(
			"[assets] %-15s %5d tris, %.2f m, %d surface(s), %d matériau(x)"
			% [asset_name, tris, longest, surfaces, mats.size()]
		)
	)
	if tris > int(b["max_tris"]):
		_fail(asset_name, "%d triangles > budget %d" % [tris, int(b["max_tris"])])
	if longest > float(b["max_size"]) or longest < 0.05:
		_fail(
			asset_name, "dimension %.2f m hors limites (max %.2f)" % [longest, float(b["max_size"])]
		)
	if mats.size() > int(b["max_materials"]):
		_fail(asset_name, "%d matériaux > %d" % [mats.size(), int(b["max_materials"])])
	if bad_uv > 0:
		_fail(asset_name, "%d UV hors de [0,1] (atlas de palette)" % bad_uv)
	# Posé au sol : le bas du modèle est à y ~ 0 (origine au sol, plan §6.2) ; un objet planté
	# dans le sable (parasol, rocher) peut s'enfoncer de 30 cm.
	if bool(b.get("ground_check", true)) and (aabb.position.y < -0.3 or aabb.position.y > 0.3):
		_fail(asset_name, "le modèle n'est pas posé au sol (y min = %.2f)" % aabb.position.y)
	if b.has("max_surfaces") and surfaces > int(b["max_surfaces"]):
		_fail(
			asset_name,
			(
				"%d surfaces > %d (un appel de dessin par personnage)"
				% [surfaces, int(b["max_surfaces"])]
			)
		)
	for required: String in b.get("nodes", []):
		if not names.has(required):
			_fail(asset_name, "noeud '%s' absent" % required)
	var skeleton: Skeleton3D = null
	var player: AnimationPlayer = null
	for n: Node in _all_nodes(root):
		if n is AnimationPlayer:
			player = n as AnimationPlayer
		elif n is Skeleton3D:
			skeleton = n as Skeleton3D
	if bool(b.get("skinned", false)):
		if skeleton == null or skinned_meshes == 0:
			_fail(asset_name, "maillage skinné et squelette attendus")
		elif skeleton.get_bone_count() > int(b["max_bones"]):
			_fail(asset_name, "%d os > %d" % [skeleton.get_bone_count(), int(b["max_bones"])])
		elif skeleton != null:
			print("[assets]   %d os" % skeleton.get_bone_count())
	for anim_name: String in b["animations"]:
		if player == null or not player.has_animation(anim_name):
			_fail(asset_name, "animation '%s' absente" % anim_name)
			continue
		var anim: Animation = player.get_animation(anim_name)
		var should_loop: bool = (b["loop"] as Array).has(anim_name)
		if should_loop and anim.loop_mode == Animation.LOOP_NONE:
			_fail(asset_name, "animation '%s' devrait boucler" % anim_name)
		if not should_loop and anim.loop_mode != Animation.LOOP_NONE:
			_fail(asset_name, "animation '%s' ne devrait pas boucler" % anim_name)
		if anim.length < 0.1 or anim.length > 3.0:
			_fail(
				asset_name, "animation '%s' : durée %.2f s hors limites" % [anim_name, anim.length]
			)
	root.queue_free()


func _all_nodes(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c: Node in n.get_children():
		out.append_array(_all_nodes(c))
	return out


func _to_root(n: Node3D, root: Node) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root.get_parent():
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
