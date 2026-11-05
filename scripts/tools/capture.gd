extends Node
## Captures d'écran du prototype avec le bot (nécessite un rendu : xvfb + OpenGL logiciel).
## xvfb-run -a godot --rendering-driver opengl3 --resolution 540x960 \
##   --path . res://scenes/tools/capture.tscn -- /tmp/shots
## Sert à contrôler visuellement la scène ; ne remplace pas un test sur téléphone.

const DT: float = 1.0 / 60.0
const SHOT_TIMES: Array[float] = [1.0, 6.0, 14.0, 26.0]

var _game: Gameplay
var _out_dir: String = "/tmp/axmob_shots"
var _next_shot: int = 0
var _combat_shot_taken: bool = false
var _combat_frames: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_game = (load("res://scenes/gameplay/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	_game.set_physics_process(false)
	add_child(_game)


func _process(_delta: float) -> void:
	if _game.ctx == null:
		return
	var joystick: FloatingJoystick = _game.get_node("Ui/Joystick") as FloatingJoystick
	joystick.vector = BotInput.compute(_game.ctx)
	_game.step(DT)
	if _next_shot < SHOT_TIMES.size() and _game.ctx.time >= SHOT_TIMES[_next_shot]:
		var path: String = "%s/shot_%02d.png" % [_out_dir, _next_shot]
		get_viewport().get_texture().get_image().save_png(path)
		print("[capture] %s (t=%.1f s, vague %d)" % [path, _game.ctx.time, _game.ctx.wave])
		_next_shot += 1
	var projectiles: ProjectileManager = _game.get_node("World/Projectiles") as ProjectileManager
	if not _combat_shot_taken and projectiles.active_count() >= 4:
		_combat_frames += 1
	if not _combat_shot_taken and _combat_frames >= 6:
		_combat_shot_taken = true
		var combat_path: String = "%s/combat.png" % _out_dir
		get_viewport().get_texture().get_image().save_png(combat_path)
		print("[capture] %s (haches en vol : %d)" % [combat_path, projectiles.active_count()])
	if _next_shot >= SHOT_TIMES.size() and _combat_shot_taken:
		get_tree().quit()
