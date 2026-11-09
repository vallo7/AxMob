extends Node
## Séquence de contrôle des effets de la phase 5 (rendu logiciel : xvfb + OpenGL) : la tourelle
## lourde lance une hache sur un groupe de crabes ; captures régulières du vol, de l'impact de zone,
## de la poussière, des confettis et des pièces.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 540x960 \
##     --path . res://scenes/tools/fx_showcase.tscn -- /tmp/fx
## Sert au contrôle visuel ; ne remplace pas un test sur téléphone.

const DT: float = 1.0 / 60.0
const SHOT_EVERY: int = 4
const SHOTS: int = 22
const CLUSTER: Array[Vector2] = [
	Vector2(3.0, 2.0),
	Vector2(4.2, 2.8),
	Vector2(2.2, 3.4),
	Vector2(3.6, 4.0),
	Vector2(5.2, 3.6),
	Vector2(1.4, 2.0),
]

var _game: Gameplay
var _out_dir: String = "/tmp/axmob_fx"
var _frame: int = 0
var _shots: int = 0
var _fired: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_game = (load("res://scenes/gameplay/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	_game.set_physics_process(false)
	_game.run_seed = 777
	add_child(_game)


func _process(_delta: float) -> void:
	if _game.ctx == null:
		return
	_game.step(DT)
	_frame += 1
	if _frame == 20:
		_prepare()
	if _fired and _frame % SHOT_EVERY == 0 and _shots < SHOTS:
		var path: String = "%s/fx_%02d.png" % [_out_dir, _shots]
		get_viewport().get_texture().get_image().save_png(path)
		_shots += 1
		if _shots == 14:
			_kill_one()
	if _shots >= SHOTS:
		print("[fx] %d captures dans %s" % [_shots, _out_dir])
		AudioManager.shutdown()
		get_tree().quit()


func _prepare() -> void:
	var em: EnemyManager = _game.get_node("World/Enemies") as EnemyManager
	var datas: Array[TurretData] = DataRegistry.turrets()
	var heavy: int = 0
	for i: int in datas.size():
		if datas[i].projectile.category == ProjectileData.Category.HEAVY:
			heavy = i
	for p: Vector2 in CLUSTER:
		var id: int = em.spawn(DataRegistry.enemies()[0], p, 1)
		var e: Enemy = _game.ctx.enemies.slots[id]
		e.state = Enemy.State.CHASE
		e.health.max_hp = 400.0
		e.health.hp = 400.0
		e.speed_mult = 0.0
	var origin: Vector2 = Vector2(10.2, 10.2)
	var target: Vector2 = CLUSTER[0]
	EventBus.turret_fired.emit(heavy, datas[heavy], origin, (target - origin).normalized())
	_fired = true


func _kill_one() -> void:
	for e: Enemy in _game.ctx.enemies.slots:
		if e.state == Enemy.State.CHASE:
			EventBus.axe_hit.emit(e.id, 9999.0, 0, Vector2.LEFT)
			return
