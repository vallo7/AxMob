extends Node
## Captures d'écran du prototype avec le bot (nécessite un rendu : xvfb + OpenGL logiciel).
## xvfb-run -a godot --rendering-driver opengl3 --resolution 540x960 \
##   --path . res://scenes/tools/capture.tscn -- /tmp/shots [élévation caméra en degrés]
## Sert à contrôler visuellement la scène ; ne remplace pas un test sur téléphone.
## Séquence : parties normales (shot_00..03, combat), puis panneau d'amélioration (panel),
## avertissement de boss (boss_warning), boss et télégraphe d'onde de choc (boss, boss_slam),
## charge télégraphiée (boss_charge).

const DT: float = 1.0 / 60.0
const SHOT_TIMES: Array[float] = [1.0, 6.0, 14.0, 26.0]
const SETTLE_FRAMES: int = 10

var _game: Gameplay
var _out_dir: String = "/tmp/axmob_shots"
var _next_shot: int = 0
var _combat_shot_taken: bool = false
var _combat_frames: int = 0
var _stage: int = 0
var _stage_frames: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	if args.size() > 1:
		# Comparaison d'angles : le 2e argument remplace l'élévation de la caméra (degrés).
		DataRegistry.feel().pitch_degrees = float(args[1])
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_game = (load("res://scenes/gameplay/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	_game.set_physics_process(false)
	_game.run_seed = 4242
	add_child(_game)


func _process(_delta: float) -> void:
	if _game.ctx == null:
		return
	if _next_shot < SHOT_TIMES.size() or not _combat_shot_taken:
		_run_normal()
	else:
		_run_extra()


func _run_normal() -> void:
	var joystick: FloatingJoystick = _game.get_node("Ui/Joystick") as FloatingJoystick
	joystick.vector = BotInput.compute(_game.ctx)
	_game.step(DT)
	if _next_shot < SHOT_TIMES.size() and _game.ctx.time >= SHOT_TIMES[_next_shot]:
		var path: String = "%s/shot_%02d.png" % [_out_dir, _next_shot]
		_save(path)
		print("[capture] %s (t=%.1f s, vague %d)" % [path, _game.ctx.time, _game.ctx.wave])
		_next_shot += 1
	var projectiles: ProjectileManager = _game.get_node("World/Projectiles") as ProjectileManager
	if not _combat_shot_taken and projectiles.active_count() >= 4:
		_combat_frames += 1
	if not _combat_shot_taken and _combat_frames >= 6:
		_combat_shot_taken = true
		_save("%s/combat.png" % _out_dir)
		print("[capture] combat (haches en vol : %d)" % projectiles.active_count())


## Scènes mises en place à la main : panneau, avertissement, boss, charge.
func _run_extra() -> void:
	_stage_frames += 1
	match _stage:
		0:
			_game.ctx.coins = 40
			_game.ctx.config.upgrade_pause = GameConfig.UpgradePause.FULL_STOP
			_game._toggle_upgrades()
			_next_stage()
		1:
			if _stage_frames > SETTLE_FRAMES:
				_save("%s/panel.png" % _out_dir)
				_game._try_buy_for_capture()
				_next_stage()
		2:
			if _stage_frames > SETTLE_FRAMES:
				_save("%s/panel_after_buy.png" % _out_dir)
				_game._toggle_upgrades()
				_clear_enemies()
				EventBus.boss_warning.emit(10, 2.0, Vector2(0.0, -11.0))
				_next_stage()
		3:
			_game.step(DT)
			if _stage_frames > SETTLE_FRAMES:
				_save("%s/boss_warning.png" % _out_dir)
				_spawn_boss(Vector2(0.0, -6.0), Enemy.State.WINDUP)
				_next_stage()
		4:
			_game.step(DT * 0.2)
			_keep_boss_state(Enemy.State.WINDUP, 0.6)
			if _stage_frames > SETTLE_FRAMES:
				_save("%s/boss_slam.png" % _out_dir)
				_next_stage()
		5:
			var boss: Enemy = _game.ctx.enemies.slots[_game.ctx.boss_id]
			if _stage_frames == 1:
				boss.boss.phase = 2
				boss.boss.charge_cooldown = 0.0
				boss.pos = Vector2(0.0, -9.0)
				boss.state = Enemy.State.CHASE
				_game._player.teleport(Vector2(0.0, 4.0))
			_game.step(DT * 0.2)
			if boss.state == Enemy.State.CHARGE_WINDUP and _stage_frames > 4:
				_keep_boss_state(Enemy.State.CHARGE_WINDUP, 0.5)
				_game.step(0.0001)
				await get_tree().process_frame
				_save("%s/boss_charge.png" % _out_dir)
				print("[capture] terminé")
				AudioManager.shutdown()
				get_tree().quit()
			elif _stage_frames > 120:
				AudioManager.shutdown()
				get_tree().quit()


func _next_stage() -> void:
	_stage += 1
	_stage_frames = 0


func _clear_enemies() -> void:
	for e: Enemy in _game.ctx.enemies.slots:
		e.state = Enemy.State.INACTIVE
		e.visual.visible = false


func _spawn_boss(pos: Vector2, state: Enemy.State) -> void:
	var boss: BossData = DataRegistry.wave_table().boss
	var em: EnemyManager = _game.get_node("World/Enemies") as EnemyManager
	var id: int = em.spawn(boss, pos, 1)
	_game._player.teleport(Vector2(0.0, 0.5))
	var e: Enemy = _game.ctx.enemies.slots[id]
	e.state = state
	e.state_time = 0.3
	e.health.hp = e.health.max_hp * 0.7


## Maintient le boss dans un état d'armement le temps de la capture.
func _keep_boss_state(state: Enemy.State, at: float) -> void:
	var e: Enemy = _game.ctx.enemies.slots[_game.ctx.boss_id]
	e.state = state
	e.state_time = at


func _save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
