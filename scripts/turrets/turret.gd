class_name Turret
extends Node3D
## Tourelle fixe : la base reste immobile, seule la partie rotative (Pivot) pivote.
## Machine à états (plan §5.2) : DORMANT -> ACQUIRING -> AIMING -> FIRING -> RELOADING.
## La cible lui est assignée par le TurretManager ; la visée est prédictive.

enum State { DORMANT, ACQUIRING, AIMING, FIRING, RELOADING }

const MUZZLE_DISTANCE: float = 1.1
const RECOIL_DISTANCE: float = 0.22
const RECOIL_RECOVERY: float = 8.0
const FLASH_TIME: float = 0.06
const AIM_DAMPING: float = 12.0
const RANGE_SLACK: float = 1.05

var turret_id: int = 0
var data: TurretData
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
var _barrel: MeshInstance3D
var _flash: MeshInstance3D

@onready var _base: Node3D = $Base
@onready var _pivot: Node3D = $Pivot
@onready var _muzzle: Marker3D = $Pivot/Muzzle


func setup(id: int, p_data: TurretData, ctx: RunContext, position2: Vector2) -> void:
	turret_id = id
	data = p_data
	_ctx = ctx
	pos2 = position2
	position = Planar.to3(pos2)
	_rest_yaw = Planar.yaw_from_dir(-pos2.normalized())
	yaw = _rest_yaw
	_build_placeholder_visuals()
	_apply_visuals()


func muzzle_position() -> Vector2:
	return pos2 + Planar.dir_from_yaw(yaw) * MUZZLE_DISTANCE


func step(dt: float) -> void:
	_cooldown = maxf(_cooldown - dt, 0.0)
	_recoil = maxf(_recoil - dt * RECOIL_RECOVERY, 0.0)
	_flash_left = maxf(_flash_left - dt, 0.0)
	if not _ctx.combat_active():
		target_id = -1
		state = State.DORMANT
		_turn_toward(_rest_yaw, data.rotation_speed * 0.5, dt)
	else:
		_step_active(dt)
	_apply_visuals()


func _step_active(dt: float) -> void:
	var target: Enemy = _current_target()
	if target == null:
		target_id = -1
		state = State.ACQUIRING
		return
	var speed_eff: float = data.projectile.speed + data.projectile.acceleration * 0.3
	var aim: Vector2 = Intercept.aim_point(muzzle_position(), target.pos, target.vel, speed_eff)
	var desired_yaw: float = Planar.yaw_from_dir(aim - pos2)
	_turn_toward(desired_yaw, data.rotation_speed, dt)
	var error: float = absf(angle_difference(yaw, desired_yaw))
	if _cooldown > 0.0:
		state = State.RELOADING
	elif error <= deg_to_rad(_ctx.config.fire_tolerance_deg):
		_fire()
	else:
		state = State.AIMING


func _fire() -> void:
	state = State.FIRING
	_cooldown = 1.0 / data.fire_rate
	_recoil = 1.0
	_flash_left = FLASH_TIME
	EventBus.turret_fired.emit(turret_id, data, muzzle_position(), Planar.dir_from_yaw(yaw))


func _current_target() -> Enemy:
	if target_id < 0:
		return null
	var e: Enemy = _ctx.enemies.slots[target_id]
	if not e.is_hittable():
		return null
	if e.pos.distance_to(pos2) > data.attack_range * RANGE_SLACK:
		return null
	return e


## Rotation à vitesse limitée avec amortissement près de la cible.
func _turn_toward(desired_yaw: float, max_speed: float, dt: float) -> void:
	var diff: float = angle_difference(yaw, desired_yaw)
	var max_step: float = max_speed * dt
	yaw = wrapf(yaw + clampf(diff * AIM_DAMPING * dt, -max_step, max_step), -PI, PI)


func _apply_visuals() -> void:
	_pivot.rotation.y = yaw
	_barrel.position.z = -0.55 + _recoil * RECOIL_DISTANCE
	_flash.visible = _flash_left > 0.0


func _build_placeholder_visuals() -> void:
	var color: Color = data.color
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 0.85
	base_mesh.bottom_radius = 1.0
	base_mesh.height = 0.7
	base_mesh.radial_segments = 14
	var base: MeshInstance3D = MeshInstance3D.new()
	base.mesh = base_mesh
	base.position.y = 0.35
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.21, 0.25)
	base.material_override = dark
	_base.add_child(base)
	var head_mesh: CylinderMesh = CylinderMesh.new()
	head_mesh.top_radius = 0.6
	head_mesh.bottom_radius = 0.7
	head_mesh.height = 0.5
	head_mesh.radial_segments = 12
	var head: MeshInstance3D = MeshInstance3D.new()
	head.mesh = head_mesh
	head.position.y = 0.95
	var tint: StandardMaterial3D = StandardMaterial3D.new()
	tint.albedo_color = color
	head.material_override = tint
	_pivot.add_child(head)
	var barrel_mesh: BoxMesh = BoxMesh.new()
	barrel_mesh.size = Vector3(0.35, 0.35, 1.1)
	_barrel = MeshInstance3D.new()
	_barrel.mesh = barrel_mesh
	_barrel.position = Vector3(0.0, 1.0, -0.55)
	_barrel.material_override = tint
	_pivot.add_child(_barrel)
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
