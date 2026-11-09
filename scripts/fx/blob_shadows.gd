class_name BlobShadows
extends MultiMeshInstance3D
## Fausses ombres (taches douces) sous le joueur, les ennemis et les tourelles : un seul MultiMesh,
## un seul appel de dessin. Elles ancrent les personnages au sol (gros gain de lisibilité en vue
## plongée) pour presque rien : aucun calcul d'ombres dynamiques, donc aucune ombre portée à
## activer sur le GPU. Index d'instance stable (0 = joueur, 1..N = ennemis par identifiant,
## ensuite les tourelles) pour que l'interpolation physique du moteur reste correcte.

const SHADER: Shader = preload("res://assets/shaders/ax_fx_shadow.gdshader")
const HIDDEN: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, -200.0, 0.0))
const GROUND_Y: float = 0.045
const PLAYER_RADIUS: float = 0.78
const ENEMY_SCALE: float = 1.3
const TURRET_RADIUS: float = 1.5
const ALPHA: float = 0.36

var enabled: bool = true

var _ctx: RunContext
var _mm: MultiMesh
var _turret_slots: int = 0
var _visible_prev: PackedByteArray = PackedByteArray()


func setup(ctx: RunContext, turret_positions: Array[Vector2]) -> void:
	_ctx = ctx
	_turret_slots = turret_positions.size()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.render_priority = -4
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = plane
	var total: int = 1 + ctx.enemies.capacity() + _turret_slots
	_mm.instance_count = total
	_visible_prev.resize(total)
	for i: int in total:
		_mm.set_instance_transform(i, HIDDEN)
		_mm.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
	for t: int in _turret_slots:
		var p: Vector2 = turret_positions[t]
		var basis: Basis = Basis.from_scale(Vector3(TURRET_RADIUS, 1.0, TURRET_RADIUS))
		_mm.set_instance_transform(
			1 + ctx.enemies.capacity() + t, Transform3D(basis, Vector3(p.x, GROUND_Y, p.y))
		)
		_mm.set_instance_color(1 + ctx.enemies.capacity() + t, Color(1.0, 1.0, 1.0, ALPHA))
	multimesh = _mm
	material_override = mat
	custom_aabb = AABB(Vector3(-60.0, -2.0, -60.0), Vector3(120.0, 6.0, 120.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on


## Un appel par tick de simulation : replace les ombres du joueur et des ennemis actifs.
func update(player_visible: bool) -> void:
	if not enabled:
		return
	_place(0, _ctx.player_pos, PLAYER_RADIUS, ALPHA if player_visible else 0.0, true)
	for e: Enemy in _ctx.enemies.slots:
		var slot: int = 1 + e.id
		if e.state == Enemy.State.INACTIVE:
			_place(slot, e.pos, 0.0, 0.0, false)
			continue
		var scale_f: float = e.data.radius * e.data.visual_scale * ENEMY_SCALE
		var alpha: float = ALPHA
		match e.state:
			Enemy.State.SPAWNING:
				var u: float = clampf(e.state_time / maxf(_ctx.config.spawn_invuln, 0.01), 0.0, 1.0)
				alpha *= u
				scale_f *= lerpf(0.4, 1.0, u)
			Enemy.State.DYING:
				var k: float = clampf(e.state_time / maxf(_ctx.config.death_time, 0.01), 0.0, 1.0)
				alpha *= 1.0 - k
		_place(slot, e.pos, maxf(scale_f, 0.35), alpha, true)


func _place(slot: int, pos: Vector2, radius: float, alpha: float, shown: bool) -> void:
	if not shown or alpha <= 0.001:
		if _visible_prev[slot] != 0:
			_mm.set_instance_transform(slot, HIDDEN)
			_visible_prev[slot] = 0
		return
	var basis: Basis = Basis.from_scale(Vector3(radius, 1.0, radius))
	_mm.set_instance_transform(slot, Transform3D(basis, Vector3(pos.x, GROUND_Y, pos.y)))
	_mm.set_instance_color(slot, Color(1.0, 1.0, 1.0, alpha))
	if _visible_prev[slot] == 0:
		# Réapparition (emplacement recyclé) : pas d'interpolation depuis la position cachée.
		_mm.reset_instance_physics_interpolation(slot)
		_visible_prev[slot] = 1
