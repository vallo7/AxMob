class_name FxBatch
extends MultiMeshInstance3D
## Lot de particules « tire et oublie » : un MultiMesh, un matériau, UN appel de dessin pour
## toutes les particules du lot. Anneau circulaire d'emplacements : au plafond, la plus ancienne
## est écrasée (jamais d'allocation en jeu). Le mouvement est calculé par le shader à partir de
## l'instant de naissance : le CPU n'écrit qu'une fois par particule, à l'émission.
## Les particules ne sont pas interpolées (elles sont décrites analytiquement dans le temps).

const UNUSED: Color = Color(-1000.0, 1.0, 0.0, 0.0)

var emitted: int = 0

var _mm: MultiMesh
var _capacity: int = 0
var _limit: int = 0
var _next: int = 0
var _material: ShaderMaterial


func setup(mesh: Mesh, material: ShaderMaterial, capacity: int) -> void:
	_capacity = capacity
	_limit = capacity
	_material = material
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = mesh
	_mm.instance_count = capacity
	for i: int in capacity:
		_mm.set_instance_custom_data(i, UNUSED)
	multimesh = _mm
	material_override = material
	custom_aabb = AABB(Vector3(-80.0, -10.0, -80.0), Vector3(160.0, 60.0, 160.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func capacity() -> int:
	return _capacity


func limit() -> int:
	return _limit


## Plafond utile (profil de qualité) : borné par la capacité allouée.
func set_limit(n: int) -> void:
	_limit = clampi(n, 1, _capacity)
	_next = _next % _limit


func set_time(t: float) -> void:
	_material.set_shader_parameter(&"fx_time", t)


func set_param(param: StringName, value: Variant) -> void:
	_material.set_shader_parameter(param, value)


## Émet une particule. `v0..v2` = colonnes de données de la transformation (voir les shaders).
func emit(
	origin: Vector3, v0: Vector3, v1: Vector3, v2: Vector3, color: Color, custom: Color
) -> void:
	_mm.set_instance_transform(_next, Transform3D(Basis(v0, v1, v2), origin))
	_mm.set_instance_color(_next, color)
	_mm.set_instance_custom_data(_next, custom)
	_next = (_next + 1) % _limit
	emitted += 1


## Masque toutes les particules (nouvelle partie, changement de profil).
func clear() -> void:
	for i: int in _capacity:
		_mm.set_instance_custom_data(i, UNUSED)
	_next = 0
