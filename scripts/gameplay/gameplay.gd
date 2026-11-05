class_name Gameplay
extends Node3D
## Racine d'une partie et racine de composition : crée le contexte, injecte les systèmes et
## les fait avancer dans un ordre fixe (un seul pas de simulation par tick physique, 60 Hz).
## Les systèmes ne se connaissent pas : ils communiquent par EventBus / RunContext.
## RESTART = recharger la scène : aucun état résiduel.

enum State { RUN, PAUSED, DYING, GAME_OVER }

const GAME_OVER_DELAY: float = 1.4
const BOOT_SCENE: String = "res://scenes/boot/boot.tscn"

var ctx: RunContext
var state: State = State.RUN

var _dying_time: float = 0.0

@onready var _sun: DirectionalLight3D = $World/Sun
@onready var _arena: Arena = $World/Arena
@onready var _turrets: TurretManager = $World/Turrets
@onready var _enemies: EnemyManager = $World/Enemies
@onready var _projectiles: ProjectileManager = $World/Projectiles
@onready var _player: PlayerController = $World/Player
@onready var _camera: CameraRig = $CameraRig
@onready var _contact: ContactDetector = $Systems/ContactDetector
@onready var _director: CombatDirector = $Systems/CombatDirector
@onready var _waves: WaveManager = $Systems/WaveManager
@onready var _economy: EconomyManager = $Systems/EconomyManager
@onready var _joystick: FloatingJoystick = $Ui/Joystick
@onready var _hud: Hud = $Ui/Hud
@onready var _pause_menu: PauseMenu = $Ui/PauseMenu
@onready var _game_over: GameOverScreen = $Ui/GameOverScreen


func _ready() -> void:
	get_tree().paused = false
	_sun.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	var config: GameConfig = DataRegistry.config()
	ctx = RunContext.new(config, DataRegistry.balance())
	_arena.setup(config)
	_player.setup(ctx)
	_enemies.setup(ctx)
	_turrets.setup(ctx, DataRegistry.turrets())
	_projectiles.setup(ctx)
	_contact.setup(ctx)
	_director.setup(ctx)
	_waves.setup(ctx, DataRegistry.enemies())
	_economy.setup(ctx)
	_camera.setup()
	_joystick.setup(config)
	_hud.setup(ctx, _player, _projectiles)
	_hud.pause_pressed.connect(_toggle_pause)
	_pause_menu.resume_pressed.connect(_toggle_pause)
	_pause_menu.restart_pressed.connect(_restart)
	_pause_menu.menu_pressed.connect(_to_menu)
	_game_over.play_again_pressed.connect(_restart)
	_game_over.menu_pressed.connect(_to_menu)
	EventBus.player_died.connect(_on_player_died)
	EventBus.run_started.emit()


func _physics_process(delta: float) -> void:
	if state == State.RUN or state == State.DYING:
		step(delta)


## Un pas de simulation. Public pour les tests headless (pas de dépendance au moteur de boucle).
func step(dt: float) -> void:
	ctx.time += dt
	_player.step(dt, _read_input())
	_enemies.step(dt)
	_contact.step()
	_turrets.step(dt)
	_projectiles.step(dt)
	_waves.step(dt)
	_camera.step(ctx, dt)
	if state == State.DYING:
		_dying_time += dt
		if _dying_time >= GAME_OVER_DELAY:
			_finish()


func _read_input() -> Vector2:
	if not ctx.player_alive:
		return Vector2.ZERO
	var v: Vector2 = _joystick.vector
	if v != Vector2.ZERO:
		return v
	# Repli clavier pour tester sur PC (écran vers le bas = +Z).
	var kb: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		kb.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		kb.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		kb.y += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		kb.y -= 1.0
	return kb.normalized()


func _on_player_died() -> void:
	state = State.DYING
	_dying_time = 0.0
	_joystick.enabled = false
	_joystick.release()


func _finish() -> void:
	state = State.GAME_OVER
	EventBus.game_over.emit(ctx.wave, ctx.coins)
	_game_over.show_results(ctx)


func _toggle_pause() -> void:
	if state == State.RUN:
		state = State.PAUSED
		get_tree().paused = true
		_joystick.release()
		_joystick.enabled = false
		_pause_menu.visible = true
		EventBus.run_paused.emit(true)
	elif state == State.PAUSED:
		state = State.RUN
		get_tree().paused = false
		_joystick.enabled = true
		_pause_menu.visible = false
		EventBus.run_paused.emit(false)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(BOOT_SCENE)


func _notification(what: int) -> void:
	# Pause automatique à la mise en arrière-plan ; le bouton retour Android bascule la pause.
	if what == NOTIFICATION_APPLICATION_PAUSED and state == State.RUN:
		_toggle_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and (state == State.RUN or state == State.PAUSED):
		_toggle_pause()
