class_name PlayerController
extends Node3D
## Contrôleur cinématique maison : un cercle sur le plan XZ, limité par l'arène.
## Accélération/décélération courtes, rotation lissée, invulnérabilité clignotante.

const TURN_EPSILON: float = 0.3
const KNOCKBACK_SPEED: float = 4.0
const DEATH_FALL_TIME: float = 0.4

var health: HealthComponent

var _ctx: RunContext
var _cfg: GameConfig
var _pos: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO
var _yaw: float = 0.0
var _run_phase: float = 0.0
var _squash: float = 0.0
var _death_time: float = 0.0
var _model: Node3D
var _body: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	_cfg = ctx.config
	health = HealthComponent.new(_cfg.player_hp, _cfg.invuln_time)
	_ctx.player_alive = true
	_build_visuals()
	EventBus.enemy_attack_landed.connect(_on_attack_landed)
	_publish()
	_apply_visuals(0.0)


func step(dt: float, input_vec: Vector2) -> void:
	if not _ctx.player_alive:
		_death_time += dt
		_apply_visuals(dt)
		return
	health.tick(dt)
	var speed: float = _cfg.player_speed
	var desired: Vector2 = input_vec.limit_length(1.0) * speed
	_vel = Steering.approach_asymmetric(
		_vel, desired, speed / _cfg.accel_time, speed / _cfg.decel_time, dt
	)
	_pos += _vel * dt
	var clamped: Vector2 = Steering.clamp_to_arena(_pos, _cfg.player_radius, _cfg.arena_radius)
	if clamped != _pos:
		# Glisse le long du bord : on retire la composante de vitesse qui sort de l'arène.
		var outward: Vector2 = clamped.normalized()
		_vel -= outward * maxf(_vel.dot(outward), 0.0)
		_pos = clamped
	if _vel.length() > TURN_EPSILON:
		_yaw = lerp_angle(_yaw, Planar.yaw_from_dir(_vel), 1.0 - exp(-_cfg.turn_speed * dt))
	_run_phase += _vel.length() * dt * 2.4
	_publish()
	_apply_visuals(dt)


func _publish() -> void:
	_ctx.player_pos = _pos
	_ctx.player_vel = _vel


func _on_attack_landed(damage: float, source: Vector2) -> void:
	if not _ctx.player_alive:
		return
	var applied: float = health.apply_damage(damage)
	if applied <= 0.0:
		return
	_squash = 1.0
	var away: Vector2 = _pos - source
	if away.length() > 0.001:
		_vel += away.normalized() * KNOCKBACK_SPEED
	EventBus.player_damaged.emit(applied, health.hp)
	if health.is_dead():
		_ctx.player_alive = false
		_death_time = 0.0
		EventBus.player_died.emit()


func _apply_visuals(dt: float) -> void:
	position = Vector3(_pos.x, 0.0, _pos.y)
	_squash = maxf(_squash - dt * 6.0, 0.0)
	var speed_ratio: float = clampf(_vel.length() / _cfg.player_speed, 0.0, 1.0)
	var bob: float = absf(sin(_run_phase)) * 0.12 * speed_ratio
	_model.rotation = Vector3(0.12 * speed_ratio, _yaw, 0.0)
	_model.position.y = bob
	_model.scale = Vector3(1.0 + 0.25 * _squash, 1.0 - 0.2 * _squash, 1.0 + 0.25 * _squash)
	if not _ctx.player_alive:
		var fall: float = clampf(_death_time / DEATH_FALL_TIME, 0.0, 1.0)
		_model.rotation.x = lerpf(0.12, PI * 0.5, fall)
		_model.position.y = lerpf(0.0, 0.3, fall)
		_body.visible = true
	else:
		_body.visible = health.invuln_left <= 0.0 or int(health.invuln_left * 20.0) % 2 == 0
	var active: bool = _ctx.combat_active()
	_ring.visible = _ctx.player_alive
	_ring_mat.albedo_color = Color(1.0, 0.55, 0.15, 0.55) if active else Color(1.0, 1.0, 1.0, 0.18)
	_ring_mat.emission_enabled = active


func _build_visuals() -> void:
	_model = Node3D.new()
	add_child(_model)
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = _cfg.player_radius
	capsule.height = 1.5
	capsule.radial_segments = 14
	capsule.rings = 5
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.position.y = 0.75
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.92, 0.88, 0.76)
	_body.material_override = body_mat
	_model.add_child(_body)
	var nose: MeshInstance3D = MeshInstance3D.new()
	var nose_mesh: BoxMesh = BoxMesh.new()
	nose_mesh.size = Vector3(0.28, 0.28, 0.4)
	nose.mesh = nose_mesh
	var nose_mat: StandardMaterial3D = StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.93, 0.47, 0.12)
	nose.material_override = nose_mat
	_body.add_child(nose)
	nose.position = Vector3(0.0, 0.25, -_cfg.player_radius - 0.05)
	# Anneau de déclenchement (indicatif : joueur + ennemi basique + tolérance).
	var ring_radius: float = _cfg.player_radius + 0.4 + _cfg.contact_tolerance
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = ring_radius - 0.05
	torus.outer_radius = ring_radius
	torus.rings = 32
	torus.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.position.y = 0.06
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.emission = Color(1.0, 0.55, 0.15)
	_ring.material_override = _ring_mat
	add_child(_ring)
