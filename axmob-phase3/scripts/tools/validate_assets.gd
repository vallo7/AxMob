extends SceneTree
## Validation automatique des GLB (plan §6.3) : triangles, dimensions, animations, matériaux.
## godot --headless --script res://scripts/tools/validate_assets.gd   (code 1 si budget dépassé)

const BUDGETS_PATH: String = "res://assets/budgets.json"

var _errors: int = 0


func _initialize() -> void:
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS_PATH))
	for asset_name: String in budgets:
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
	var aabb: AABB = AABB()
	var mats: Dictionary = {}
	for n: Node in _all_nodes(root):
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			var mesh: Mesh = mi.mesh
			var box: AABB = _to_root(mi, root) * mesh.get_aabb()
			aabb = box if aabb.size == Vector3.ZERO else aabb.merge(box)
			for s: int in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += (
					idx.size() / 3
					if idx.size() > 0
					else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				)
				var m: Material = mesh.surface_get_material(s)
				mats[m.resource_name if m != null else "<none>"] = true
	var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	print(
		(
			"[assets] %s: %d tris, taille max %.2f m, %d matériau(x)"
			% [asset_name, tris, longest, mats.size()]
		)
	)
	if tris > int(b["max_tris"]):
		_fail(asset_name, "%d triangles > budget %d" % [tris, int(b["max_tris"])])
	if longest > float(b["max_size"]) or longest < 0.05:
		_fail(asset_name, "dimension %.2f m hors limites" % longest)
	if mats.size() > int(b["max_materials"]):
		_fail(asset_name, "%d matériaux > %d" % [mats.size(), int(b["max_materials"])])
	var player: AnimationPlayer = null
	for n: Node in _all_nodes(root):
		if n is AnimationPlayer:
			player = n as AnimationPlayer
	for anim_name: String in b["animations"]:
		if player == null or not player.has_animation(anim_name):
			_fail(asset_name, "animation '%s' absente" % anim_name)
		elif b["loop"].has(anim_name):
			var anim: Animation = player.get_animation(anim_name)
			var last_key: float = anim.track_get_key_time(0, anim.track_get_key_count(0) - 1)
			if absf(anim.track_get_key_time(0, 0)) > 0.0001:
				_fail(asset_name, "la première clé de '%s' n'est pas à t=0" % anim_name)
			print(
				(
					"[assets]   anim '%s' %.3f s, derniere cle %.3f s, loop_mode=%d"
					% [anim_name, anim.length, last_key, anim.loop_mode]
				)
			)
			if anim.loop_mode == Animation.LOOP_NONE:
				_fail(asset_name, "animation '%s' devrait boucler" % anim_name)
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
