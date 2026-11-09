class_name TrailBatch
extends MultiMeshInstance3D
## Flux lumineux derrière les haches en vol : UN quad par emplacement de hache dans un seul
## MultiMesh (un seul appel de dessin, aucun nœud par hache). L'index d'instance = l'emplacement
## du pool de haches : il est stable, donc l'interpolation physique du moteur reste correcte.
## Les emplacements inactifs sont rangés sous le sol (hors champ).

const HIDDEN: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, -200.0, 0.0))
const SHADER: Shader = preload("res://assets/shaders/ax_fx_trail.gdshader")

var _mm: MultiMesh
var _capacity: int = 0


func setup(capacity: int) -> void:
	_capacity = capacity
	var quad: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
		[
			Vector3(0.0, 0.0, -1.0),
			Vector3(1.0, 0.0, -1.0),
			Vector3(1.0, 0.0, 1.0),
			Vector3(0.0, 0.0, 1.0),
		]
	)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	quad.surface_set_material(0, mat)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = capacity
	for i: int in capacity:
		_mm.set_instance_transform(i, HIDDEN)
		_mm.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
	multimesh = _mm
	custom_aabb = AABB(Vector3(-60.0, -2.0, -60.0), Vector3(120.0, 6.0, 120.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func capacity() -> int:
	return _capacity


## Place le flux de l'emplacement `slot` : tête en `head`, orienté selon `dir` (plan XZ).
func show_trail(
	slot: int, head: Vector3, dir: Vector2, length: float, width: float, c: Color
) -> void:
	var d: Vector2 = dir.normalized()
	var basis: Basis = Basis(
		Vector3(-d.x * length, 0.0, -d.y * length),
		Vector3(0.0, 1.0, 0.0),
		Vector3(-d.y * width, 0.0, d.x * width)
	)
	_mm.set_instance_transform(slot, Transform3D(basis, head))
	_mm.set_instance_color(slot, c)


func hide_trail(slot: int) -> void:
	_mm.set_instance_transform(slot, HIDDEN)


## À appeler à l'apparition d'une hache dans un emplacement réutilisé : évite qu'un flux
## « glisse » de l'ancienne position vers la nouvelle (interpolation physique).
func reset_trail(slot: int) -> void:
	_mm.reset_instance_physics_interpolation(slot)
