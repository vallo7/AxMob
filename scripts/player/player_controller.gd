class_name PlayerController
extends Node3D
## Contrôleur cinématique maison : un cercle sur le plan XZ, limité par l'arène.
## Accélération/décélération courtes, rotation lissée, invulnérabilité clignotante.

const TURN_EPSILON: float = 0.3
const KNOCKBACK_SPEED: float = 4.0
const HIT_ANIM_TIME: float = 0.3
## Agrandissement du héros à l'écran (lisibilité en vue de dessus) ;
## le rayon de collision ne change pas.
const VISUAL_SCALE: float = 1.2
## Le héros court à vitesse maximale : le clip « run » est calé dessus.
const RUN_SPEED_SCALE: float = 1.15
## Pas par seconde à pleine vitesse (rebond de course + son de pas) et amplitude du rebond.
const STEP_HZ: float = 2.7
const BOUNCE_HEIGHT: float = 0.07
const BOUNCE_SQUASH: float = 0.07
const HIT_SQUASH: float = 0.28
const IDLE_BREATH: float = 0.018

var health: HealthComponent
## Vitesse maximale de CETTE partie (vitesse de base x bonus permanent).
var _max_speed: float = 5.0

var _ctx: RunContext
var _cfg: GameConfig
var _pos: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO
var _yaw: float = 0.0
var _hit_left: float = 0.0
var _death_time: float = 0.0
var _was_alive: bool = true
var _run_phase: float = 0.0
var _idle_phase: float = 0.0
var _model: Node3D
var _rig: ModelRig
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	_cfg = ctx.config
	_max_speed = _cfg.player_speed * _ctx.bonuses.speed_mult
	health = HealthComponent.new(_cfg.player_hp + _ctx.bonuses.hp_add, _cfg.invuln_time)
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
	var speed: float = _max_speed
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
	_publish()
	_apply_visuals(dt)


## Place le joueur (tests, mise en scène) : vitesse remise à zéro.
func teleport(position: Vector2) -> void:
	_pos = position
	_vel = Vector2.ZERO
	_publish()


func _publish() -> void:
	_ctx.player_pos = _pos
	_ctx.player_vel = _vel


func _on_attack_landed(damage: float, source: Vector2) -> void:
	if not _ctx.player_alive:
		return
	var applied: float = health.apply_damage(damage)
	if applied <= 0.0:
		return
	_hit_left = HIT_ANIM_TIME
	_rig.play(&"hit", 1.0, true)
	var away: Vector2 = _pos - source
	if away.length() > 0.001:
		_vel += away.normalized() * KNOCKBACK_SPEED
	_ctx.player_hp_fraction = health.fraction()
	EventBus.player_damaged.emit(applied, health.hp)
	if health.is_dead():
		_ctx.player_alive = false
		_death_time = 0.0
		EventBus.player_died.emit()


func _apply_visuals(dt: float) -> void:
	position = Vector3(_pos.x, 0.0, _pos.y)
	_apply_juice(dt)
	if _ctx.player_alive:
		_hit_left = maxf(_hit_left - dt, 0.0)
		if _hit_left <= 0.0:
			var speed_ratio: float = clampf(_vel.length() / _max_speed, 0.0, 1.0)
			if speed_ratio > 0.08:
				_rig.play(&"run", maxf(speed_ratio * RUN_SPEED_SCALE, 0.45))
			else:
				_rig.play(&"idle", 1.0)
		_rig.set_flash(0.6 if _hit_left > HIT_ANIM_TIME * 0.6 else 0.0)
		# Invulnérabilité : le héros clignote (visuellement identifiable, plan §3.2).
		_rig.set_visible(health.invuln_left <= 0.0 or int(health.invuln_left * 20.0) % 2 == 0)
	else:
		if _was_alive:
			_rig.play(&"death", 1.0, true)
		_rig.set_visible(true)
		_rig.set_flash(0.0)
	_was_alive = _ctx.player_alive
	_rig.advance(dt)
	var active: bool = _ctx.combat_active()
	_ring.visible = _ctx.player_alive
	_ring_mat.albedo_color = Color(1.0, 0.55, 0.15, 0.55) if active else Color(1.0, 1.0, 1.0, 0.18)
	_ring_mat.emission_enabled = active


## Animation procédurale du héros par-dessus les clips : rebond et balancement synchronisés sur les
## pas, penchement vers l'avant, respiration à l'arrêt, écrasement à l'impact reçu.
func _apply_juice(dt: float) -> void:
	var speed_ratio: float = clampf(_vel.length() / _max_speed, 0.0, 1.0)
	var prev: float = _run_phase
	_run_phase = fposmod(_run_phase + dt * TAU * STEP_HZ * 0.5 * speed_ratio, TAU * 2.0)
	if _ctx.player_alive and speed_ratio > 0.15 and floori(prev / PI) != floori(_run_phase / PI):
		EventBus.player_step.emit(speed_ratio)
	_idle_phase = fposmod(_idle_phase + dt * 2.2, TAU * 4.0)
	var hop: float = absf(sin(_run_phase))
	var hit: float = clampf(_hit_left / HIT_ANIM_TIME, 0.0, 1.0)
	var sy: float = 1.0 + BOUNCE_SQUASH * (hop - 0.4) * speed_ratio
	sy += IDLE_BREATH * sin(_idle_phase) * (1.0 - speed_ratio) - HIT_SQUASH * hit * hit
	var wide: float = 1.0 / sqrt(maxf(sy, 0.3))
	_model.position = Vector3(0.0, hop * BOUNCE_HEIGHT * speed_ratio, 0.0)
	_model.rotation = Vector3(
		-deg_to_rad(5.0) * speed_ratio, _yaw, sin(_run_phase) * deg_to_rad(3.0) * speed_ratio
	)
	_model.scale = Vector3(wide, sy, wide) * VISUAL_SCALE


func _build_visuals() -> void:
	_model = Node3D.new()
	add_child(_model)
	_rig = ModelRig.create("char_player")
	_model.add_child(_rig.root)
	_rig.play(&"idle", 1.0, true)
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
