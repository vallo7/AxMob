class_name Gameplay
extends Node3D
## Racine d'une partie et racine de composition : crée le contexte, injecte les systèmes et
## les fait avancer dans un ordre fixe (un seul pas de simulation par tick physique, 60 Hz).
## Les systèmes ne se connaissent pas : ils communiquent par EventBus / RunContext.
## RESTART = recharger la scène : aucun état résiduel.
##
## Bouton retour : UIManager (autoload) reçoit la notification Android et appelle _on_back().
## Ce script NE doit PAS traiter NOTIFICATION_WM_GO_BACK_REQUEST lui-même (double traitement).

enum State { RUN, PAUSED, UPGRADING, DYING, GAME_OVER }

const GAME_OVER_DELAY: float = 1.4
const BOOT_SCENE: String = "res://scenes/boot/boot.tscn"

## Graine des vagues (0 = aléatoire) : à fixer AVANT d'ajouter la scène à l'arbre (simulateur).
var run_seed: int = 0
var ctx: RunContext
var state: State = State.RUN

## Retour au menu (remplaçable en test : on ne change pas de scène pendant les tests).
var menu_action: Callable = Callable(self, "_open_menu")

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
@onready var _upgrades: UpgradeManager = $Systems/UpgradeManager
@onready var _joystick: FloatingJoystick = $Ui/Joystick
@onready var _enemy_bars: EnemyBars = $Ui/EnemyBars
@onready var _boss_bar: BossBar = $Ui/BossBar
@onready var _hud: Hud = $Ui/Hud
@onready var _panel: TurretUpgradePanel = $Ui/UpgradePanel
@onready var _pause_menu: PauseMenu = $Ui/PauseMenu
@onready var _game_over: GameOverScreen = $Ui/GameOverScreen


func _ready() -> void:
	get_tree().paused = false
	_sun.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	var config: GameConfig = DataRegistry.config()
	config.upgrade_pause = (
		UserSettings.upgrade_pause(config.upgrade_pause) as GameConfig.UpgradePause
	)
	ctx = RunContext.new(config, DataRegistry.balance())
	_arena.setup(config)
	_player.setup(ctx)
	_enemies.setup(ctx)
	_turrets.setup(ctx, DataRegistry.turrets())
	_projectiles.setup(ctx)
	_contact.setup(ctx)
	_director.setup(ctx)
	_waves.setup(ctx, DataRegistry.wave_table(), run_seed)
	_economy.setup(ctx)
	_upgrades.setup(ctx, _economy)
	_camera.setup(config)
	_joystick.setup(config)
	_enemy_bars.setup(ctx, _camera.camera())
	_boss_bar.setup(ctx, _camera.camera())
	_hud.setup(ctx, _player, _projectiles, _upgrades)
	_panel.setup(ctx, _upgrades)
	_hud.pause_pressed.connect(_toggle_pause)
	_hud.upgrades_pressed.connect(_toggle_upgrades)
	_panel.close_pressed.connect(_close_upgrades)
	_panel.upgrade_pressed.connect(_on_upgrade_pressed)
	_pause_menu.resume_pressed.connect(_toggle_pause)
	_pause_menu.restart_pressed.connect(_restart)
	_pause_menu.menu_pressed.connect(_to_menu)
	_pause_menu.upgrade_mode_pressed.connect(_cycle_upgrade_mode)
	_game_over.play_again_pressed.connect(_restart)
	_game_over.menu_pressed.connect(_to_menu)
	EventBus.player_died.connect(_on_player_died)
	UIManager.push_back(self, _on_back)
	EventBus.run_started.emit()


func _physics_process(delta: float) -> void:
	match state:
		State.RUN, State.DYING:
			step(delta)
		State.UPGRADING:
			var k: float = ctx.config.upgrade_time_scale()
			if k > 0.0:
				step(delta * k)


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
	if state == State.UPGRADING:
		_close_upgrades()
	state = State.DYING
	_dying_time = 0.0
	_joystick.enabled = false
	_joystick.release()


func _finish() -> void:
	state = State.GAME_OVER
	EventBus.game_over.emit(ctx.wave, ctx.coins)
	_game_over.show_results(ctx)


# --- Navigation : bouton retour du téléphone ---------------------------------------------------


## Réponse au bouton retour selon l'état. Retourne vrai : le retour est toujours consommé
## (jamais de sortie accidentelle de la partie).
func _on_back() -> bool:
	match state:
		State.RUN, State.PAUSED:
			_toggle_pause()
		State.UPGRADING:
			_close_upgrades()
		State.GAME_OVER:
			_to_menu()
		State.DYING:
			pass
	return true


# --- Pause -------------------------------------------------------------------------------------


func _toggle_pause() -> void:
	if state == State.RUN or state == State.UPGRADING:
		if state == State.UPGRADING:
			_close_upgrades()
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


# --- Améliorations en partie -------------------------------------------------------------------


func _toggle_upgrades() -> void:
	if state == State.RUN:
		_open_upgrades()
	elif state == State.UPGRADING:
		_close_upgrades()


func _open_upgrades() -> void:
	state = State.UPGRADING
	_panel.open()
	_joystick.exclusion_rects = [_panel.sheet_rect()]
	if ctx.config.upgrade_time_scale() <= 0.0:
		# Arrêt total : le joueur ne se déplace plus, le doigt éventuel est relâché.
		_joystick.release()
		_joystick.enabled = false


func _close_upgrades() -> void:
	if state != State.UPGRADING:
		return
	state = State.RUN
	_panel.close()
	_joystick.exclusion_rects = []
	_joystick.enabled = true


## Achat de la 1re catégorie abordable (outil de capture : montre l'effet visuel de l'achat).
func _try_buy_for_capture() -> void:
	_upgrades.try_upgrade(0)


func _on_upgrade_pressed(turret_id: int) -> void:
	if not _upgrades.try_upgrade(turret_id):
		UIManager.toast(
			"Pièces insuffisantes" if not _upgrades.is_max(turret_id) else "Niveau maximal"
		)


## Arrêt total -> Ralenti -> Aucune pause (sauvegardé).
func _cycle_upgrade_mode() -> void:
	var next: int = (int(ctx.config.upgrade_pause) + 1) % 3
	ctx.config.upgrade_pause = next as GameConfig.UpgradePause
	UserSettings.set_upgrade_pause(next)
	_pause_menu.refresh_labels()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	menu_action.call()


func _open_menu() -> void:
	get_tree().change_scene_to_file(BOOT_SCENE)


func _notification(what: int) -> void:
	# Pause automatique à la mise en arrière-plan (le retour est géré par UIManager).
	if what == NOTIFICATION_APPLICATION_PAUSED and (state == State.RUN or state == State.UPGRADING):
		_toggle_pause()
