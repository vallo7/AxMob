class_name CameraRig
extends Node3D
## Caméra 3D en vue plongée OBLIQUE (phase 5 : 60° au lieu de 70°), perspective légère.
## La distance est calculée (CameraFit) pour que toute l'arène et ses tourelles restent dans la
## largeur de l'écran quel que soit l'angle. Mouvement dynamique :
##  - suivi partiel + anticipation du déplacement, inclinaison latérale (« bank ») en courant,
##    élévation qui se baisse légèrement à pleine vitesse ;
##  - dé-zoom progressif quand la foule se resserre ;
##  - coups de zoom ressort (combat, impact de zone, coup subi) et poussée directionnelle ;
##  - secousses « trauma » (amplitude = trauma², bruit sinusoïdal) réservées aux gros événements.
## Tout se règle dans FeelConfig. Le rig avance au pas fixe de la simulation (respecte pause,
## ralenti et arrêt sur image) ; l'interpolation physique du moteur le lisse à l'affichage.

## Plafond du zoom avant cumulé (coups + secousses) : l'arène ne doit jamais être rognée.
const MAX_ZOOM_IN: float = 0.05
const KICK_STIFFNESS: float = 120.0
const KICK_DAMPING: float = 13.0

var feel: FeelConfig
var visible_width: float = 21.0
var distance: float = 20.0

var _cfg: GameConfig
var _focus: Vector2 = Vector2.ZERO
var _roll: float = 0.0
var _pitch_extra: float = 0.0
var _crowd: float = 0.0
var _punch: float = 0.0
var _punch_vel: float = 0.0
var _kick: Vector2 = Vector2.ZERO
var _kick_vel: Vector2 = Vector2.ZERO
var _trauma: float = 0.0
var _clock: float = 0.0
var _shift: float = 0.0

@onready var _camera: Camera3D = $Camera3D


func setup(cfg: GameConfig, p_feel: FeelConfig = null) -> void:
	_cfg = cfg
	feel = p_feel if p_feel != null else FeelConfig.new()
	distance = CameraFit.distance_for(cfg, feel)
	visible_width = CameraFit.width_at(distance, feel.fov_degrees)
	_shift = CameraFit.frame_shift(cfg, feel)
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = feel.fov_degrees
	_camera.current = true
	_place()
	reset_physics_interpolation()


func bind_events() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.combat_activated.connect(_on_combat_activated)
	EventBus.axe_splash.connect(_on_splash)
	EventBus.shockwave.connect(_on_shockwave)
	EventBus.boss_phase_changed.connect(_on_boss_phase)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.boss_spawned.connect(func(_id: int) -> void: add_trauma(0.25))


func camera() -> Camera3D:
	return _camera


## Secousse : `amount` s'ajoute au « trauma » (0..1) ; l'amplitude suit son carré.
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount * feel.shake_scale, 1.0)


func trauma() -> float:
	return _trauma


## Coup de zoom : négatif = la caméra se rapproche (puis revient avec un petit rebond).
func punch(amount: float) -> void:
	_punch_vel += amount * feel.spring_stiffness * 0.5


## Poussée de la caméra dans une direction du plan (mètres) : rebond amorti.
func kick(direction: Vector2, meters: float) -> void:
	_kick_vel += direction.normalized() * meters * KICK_STIFFNESS * 0.18


func step(ctx: RunContext, dt: float) -> void:
	_clock += dt
	var speed: float = maxf(_cfg.player_speed, 0.001)
	var speed_ratio: float = clampf(ctx.player_vel.length() / speed, 0.0, 1.0)
	var target: Vector2 = (ctx.player_pos + ctx.player_vel * feel.lead_seconds) * feel.follow_factor
	_focus = _focus.lerp(target, 1.0 - exp(-feel.follow_smoothing * dt))
	var bank_target: float = -clampf(ctx.player_vel.x / speed, -1.0, 1.0)
	_roll = lerpf(
		_roll, bank_target * deg_to_rad(feel.bank_degrees), _ease(feel.bank_smoothing, dt)
	)
	_pitch_extra = lerpf(
		_pitch_extra, speed_ratio * deg_to_rad(feel.pitch_run_delta_deg), _ease(4.0, dt)
	)
	var crowd_target: float = clampf(
		float(ctx.enemies.count_living()) / float(maxi(feel.crowd_full, 1)), 0.0, 1.0
	)
	_crowd = lerpf(_crowd, crowd_target, _ease(1.5, dt))
	# Ressorts (intégration semi-implicite) : zoom et poussée.
	_punch_vel += (-feel.spring_stiffness * _punch - feel.spring_damping * _punch_vel) * dt
	_punch += _punch_vel * dt
	_kick_vel += (-KICK_STIFFNESS * _kick - KICK_DAMPING * _kick_vel) * dt
	_kick += _kick_vel * dt
	_trauma = maxf(_trauma - feel.shake_decay * dt, 0.0)
	_place()


static func _ease(rate: float, dt: float) -> float:
	return 1.0 - exp(-rate * dt)


func _place() -> void:
	var pitch: float = deg_to_rad(feel.pitch_degrees) + _pitch_extra
	var zoom: float = clampf(_punch, -MAX_ZOOM_IN, 0.06) + _crowd * feel.crowd_zoom_out
	var dist: float = distance * (1.0 + zoom)
	var look: Vector3 = Vector3(_focus.x + _kick.x, 0.0, _focus.y + _shift + _kick.y)
	var shake: float = _trauma * _trauma
	var sx: float = 0.0
	var sz: float = 0.0
	var sr: float = 0.0
	if shake > 0.0001:
		sx = (sin(_clock * 41.3) + sin(_clock * 27.1 + 1.7)) * 0.5
		sz = (sin(_clock * 35.9 + 0.6) + sin(_clock * 23.3 + 2.9)) * 0.5
		sr = sin(_clock * 31.7 + 4.1)
	var offset: Vector3 = Vector3(sx, 0.0, sz) * shake * feel.shake_max_offset
	_camera.position = (look + Vector3(0.0, sin(pitch), cos(pitch)) * dist + offset)
	_camera.look_at(look + offset, Vector3.UP)
	var roll: float = _roll + sr * shake * deg_to_rad(feel.shake_max_roll_deg)
	if absf(roll) > 0.00001:
		_camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), roll)


# --- Événements -------------------------------------------------------------------------------


func _on_player_damaged(amount: float, _hp_left: float) -> void:
	if amount <= 0.0:
		return
	add_trauma(feel.trauma_hurt)
	punch(-feel.punch_hurt)


func _on_combat_activated(contacts: int, _position: Vector3) -> void:
	punch(-feel.punch_combat * minf(float(contacts), 3.0) / 3.0 - 0.002)


func _on_splash(
	position: Vector2, _radius: float, _damage: float, _cat: int, _src: int, _fo: float, _kb: float
) -> void:
	add_trauma(feel.trauma_splash)
	punch(-feel.punch_splash)
	if _cfg != null:
		kick((position - Vector2(_focus.x, _focus.y)) * 0.05, 0.12)


func _on_shockwave(_position: Vector2, _radius: float) -> void:
	add_trauma(feel.trauma_slam)
	punch(-feel.punch_splash * 1.4)


func _on_boss_phase(_id: int, _phase: int) -> void:
	add_trauma(feel.trauma_boss_phase)


func _on_boss_defeated(_id: int, _reward: int) -> void:
	add_trauma(feel.trauma_boss_death)
	punch(-feel.punch_splash * 2.0)
