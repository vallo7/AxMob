class_name Turret
extends Node3D
## Tourelle fixe : la base reste immobile, seule la partie rotative (Pivot) pivote.
## Machine à états (plan §5.2) : DORMANT -> ACQUIRING -> AIMING -> FIRING -> RELOADING.
## La cible lui est assignée par le TurretManager ; la visée est prédictive.
## Les statistiques viennent du niveau courant (TurretLevelData) ; les paliers de niveau
## activent les pièces visuelles Tier_1..Tier_3 du modèle Blender (phase 4).

enum State { DORMANT, ACQUIRING, AIMING, FIRING, RELOADING }

## Distance de la bouche au centre si le modèle n'a pas de noeud Muzzle.
const DEFAULT_MUZZLE_DISTANCE: float = 1.1
const RECOIL_DISTANCE: float = 0.22
const RECOIL_RECOVERY: float = 8.0
const FLASH_TIME: float = 0.06
const AIM_DAMPING: float = 12.0
const RANGE_SLACK: float = 1.05
const PULSE_TIME: float = 0.5

var turret_id: int = 0
var data: TurretData
var level: int = 1
var stats: TurretLevelData
var state: State = State.DORMANT
var target_id: int = -1
var target_since: float = 0.0
var pos2: Vector2 = Vector2.ZERO
var yaw: float = 0.0

var _ctx: RunContext
var _rest_yaw: float = 0.0
var _cooldown: float = 0.0
var _recoil: float = 0.0
var _flash_left: float = 0.0
var _pulse_left: float = 0.0
var _barrel: Node3D
var _barrel_rest: Vector3 = Vector3.ZERO
var _flash: MeshInstance3D
var _pulse_ring: MeshInstance3D
var _pulse_mat: StandardMaterial3D
var _tiers: Array[Node3D] = []
var _muzzle_distance: float = DEFAULT_MUZZLE_DISTANCE
var _rig: ModelRig
var _base: Node3D
var _pivot: Node3D
var _muzzle: Node3D


func setup(id: int, p_data: TurretData, ctx: RunContext, position2: Vector2) -> void:
	turret_id = id
	data = p_data
	_ctx = ctx
	pos2 = position2
	position = Planar.to3(pos2)
	_rest_yaw = Planar.yaw_from_dir(-pos2.normalized())
	yaw = _rest_yaw
	_build_model()
	apply_level(ctx.turret_levels[id], false)
	_apply_visuals()


## Applique un niveau : statistiques et palier visuel. `animate` déclenche l'impulsion.
func apply_level(new_level: int, animate: bool = true) -> void:
	level = new_level
	stats = _ctx.turret_stats(turret_id, new_level)
	for i: int in _tiers.size():
		_tiers[i].visible = stats.visual_tier > i
	if animate:
		_pulse_left = PULSE_TIME


func muzzle_position() -> Vector2:
	return pos2 + Planar.dir_from_yaw(yaw) * _muzzle_distance


func step(dt: float) -> void:
	_cooldown = maxf(_cooldown - dt, 0.0)
	_recoil = maxf(_recoil - dt * RECOIL_RECOVERY, 0.0)
	_flash_left = maxf(_flash_left - dt, 0.0)
	_pulse_left = maxf(_pulse_left - dt, 0.0)
	if not _ctx.combat_active():
		target_id = -1
		state = State.DORMANT
		_turn_toward(_rest_yaw, stats.rotation_speed * 0.5, dt)
	else:
		_step_active(dt)
	_apply_visuals()


func _step_active(dt: float) -> void:
	var target: Enemy = _current_target()
	if target == null:
		target_id = -1
		state = State.ACQUIRING
		return
	var p: ProjectileData = data.projectile
	var speed_eff: float = (p.speed + p.acceleration * 0.3) * stats.projectile_speed_mult
	var aim: Vector2 = Intercept.aim_point(muzzle_position(), target.pos, target.vel, speed_eff)
	var desired_yaw: float = Planar.yaw_from_dir(aim - pos2)
	_turn_toward(desired_yaw, stats.rotation_speed, dt)
	var error: float = absf(angle_difference(yaw, desired_yaw))
	if _cooldown > 0.0:
		state = State.RELOADING
	elif error <= deg_to_rad(_ctx.config.fire_tolerance_deg):
		_fire()
	else:
		state = State.AIMING


func _fire() -> void:
	state = State.FIRING
	_cooldown = 1.0 / stats.fire_rate
	_recoil = 1.0
	_flash_left = FLASH_TIME
	EventBus.turret_fired.emit(turret_id, data, muzzle_position(), Planar.dir_from_yaw(yaw))


func _current_target() -> Enemy:
	if target_id < 0:
		return null
	var e: Enemy = _ctx.enemies.slots[target_id]
	if not e.is_hittable():
		return null
	if e.pos.distance_to(pos2) > stats.attack_range * RANGE_SLACK:
		return null
	return e


## Rotation à vitesse limitée avec amortissement près de la cible.
func _turn_toward(desired_yaw: float, max_speed: float, dt: float) -> void:
	var diff: float = angle_difference(yaw, desired_yaw)
	var max_step: float = max_speed * dt
	yaw = wrapf(yaw + clampf(diff * AIM_DAMPING * dt, -max_step, max_step), -PI, PI)


func _apply_visuals() -> void:
	_pivot.rotation.y = yaw
	_barrel.position.z = _barrel_rest.z + _recoil * RECOIL_DISTANCE
	_flash.visible = _flash_left > 0.0
	var p: float = _pulse_left / PULSE_TIME
	_pivot.scale = Vector3.ONE * (1.0 + 0.22 * sin(p * PI))
	_pulse_ring.visible = _pulse_left > 0.0
	if _pulse_left > 0.0:
		var grow: float = 1.0 + (1.0 - p) * 1.8
		_pulse_ring.scale = Vector3(grow, 1.0, grow)
		_pulse_mat.albedo_color.a = 0.8 * p


## Instancie le modèle Blender de cette catégorie (assets/models/turret_<id>.glb) : Base fixe,
## Pivot tournant (Head, Barrel > Muzzle, Tier_2, Tier_3) et Tier_1 sur la base.
func _build_model() -> void:
	_rig = ModelRig.create(data.model())
	if _rig == null:
		return
	add_child(_rig.root)
	_base = _rig.find_node("Base")
	_pivot = _rig.find_node("Pivot")
	_barrel = _rig.find_node("Barrel")
	_muzzle = _rig.find_node("Muzzle")
	_barrel_rest = _barrel.position
	_muzzle_distance = _planar_distance_from_center(_muzzle)
	_tiers = []
	for tier_name: String in ["Tier_1", "Tier_2", "Tier_3"]:
		var part: Node3D = _rig.find_node(tier_name)
		part.visible = false
		_tiers.append(part)
	# Le dernier palier brille (doré) : paramètre d'instance du shader, pas de matériau en plus.
	for n: Node in _tiers[2].find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).set_instance_shader_parameter(&"glow", 0.35)
	var flash_mesh: SphereMesh = SphereMesh.new()
	flash_mesh.radius = 0.28
	flash_mesh.height = 0.56
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	_flash = MeshInstance3D.new()
	_flash.mesh = flash_mesh
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.85, 0.4)
	_flash.material_override = glow
	_flash.visible = false
	_muzzle.add_child(_flash)
	_build_pulse_ring(data.color)


## Distance horizontale d'un noeud du modèle à l'axe de la tourelle (au repos, avant rotation).
func _planar_distance_from_center(node: Node3D) -> float:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return Vector2(t.origin.x, t.origin.z).length()


func _build_pulse_ring(color: Color) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.3
	torus.rings = 28
	torus.ring_segments = 4
	_pulse_ring = MeshInstance3D.new()
	_pulse_ring.mesh = torus
	_pulse_mat = StandardMaterial3D.new()
	_pulse_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pulse_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pulse_mat.albedo_color = Color(color.lightened(0.4), 0.8)
	_pulse_ring.material_override = _pulse_mat
	_pulse_ring.position.y = 0.1
	_pulse_ring.visible = false
	_base.add_child(_pulse_ring)
