extends RefCounted
## Simulateur d'équilibrage headless (plan §2.5) : fait jouer un bot sur la vraie scène Gameplay,
## plus vite que le temps réel, et écrit des CSV. Il dégrossit les valeurs ; il NE remplace PAS
## les parties sur téléphone : le bot n'est pas un joueur (il ne joue ni mieux ni comme vous).
##
##   godot --headless --script res://scripts/tools/simulate_runs.gd -- \
##       --runs 8 --seconds 600 --seed 1000 --god 0 --out reports/balance
##
## --god 1 : le joueur est soigné à chaque pas (les dégâts subis sont seulement comptés, colonne
## damage_taken). Sert à étudier la progression à long terme (rythme des vagues, revenu, boss)
## indépendamment de l'habileté du bot.
##
## Produit <out>_runs.csv (une ligne par partie et par politique) et <out>_timeline.csv
## (échantillon toutes les 30 s). Politiques : « none » (aucun achat) et « lowest »
## (améliore toujours la tourelle de plus bas niveau abordable).

const DT: float = 1.0 / 60.0
const SAMPLE_EVERY: float = 30.0
const BUY_EVERY_STEPS: int = 30
const POLICIES: Array[String] = ["none", "lowest"]

var _runs: int = 6
var _seconds: float = 300.0
var _seed: int = 1000
var _out: String = "reports/balance"
var _god: bool = false
var _tree: SceneTree


## Point d'entrée : appelé par simulate_runs.gd une fois la scène prête (autoloads disponibles).
func run(tree: SceneTree) -> void:
	_tree = tree
	_parse_args()
	await _run_all()


func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var key: String = args[i]
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match key:
			"--runs":
				_runs = maxi(value.to_int(), 1)
			"--seconds":
				_seconds = maxf(value.to_float(), 10.0)
			"--seed":
				_seed = value.to_int()
			"--god":
				_god = value.to_int() != 0
			"--out":
				_out = value
		i += 2


func _run_all() -> void:
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var runs_csv: PackedStringArray = PackedStringArray()
	var timeline_csv: PackedStringArray = PackedStringArray()
	runs_csv.append(
		(
			"policy,run,seed,survived_s,died,wave,kills,coins_earned,coins_spent,bosses,levels,"
			+ "peak_enemies,pacing_min,pacing_max,damage_taken,ms_per_tick"
		)
	)
	timeline_csv.append("policy,run,t_s,wave,kills,coins_earned,coins_spent,hp,enemies,levels")
	var summary: Dictionary = {}
	for policy: String in POLICIES:
		var waves: Array[float] = []
		var survived: Array[float] = []
		var earned: Array[float] = []
		var levels: Array[float] = []
		for run: int in _runs:
			var result: Dictionary = await _simulate(policy, run, _seed + run, timeline_csv)
			runs_csv.append(result["row"] as String)
			waves.append(result["wave"] as float)
			survived.append(result["survived"] as float)
			earned.append(result["earned"] as float)
			levels.append(result["levels"] as float)
		summary[policy] = {
			"survived": _median(survived),
			"wave": _median(waves),
			"earned": _median(earned),
			"levels": _median(levels),
		}
	_write("%s_runs.csv" % _out, runs_csv)
	_write("%s_timeline.csv" % _out, timeline_csv)
	for policy: String in POLICIES:
		var s: Dictionary = summary[policy]
		print(
			(
				"[balance] %-6s : survie médiane %.0f s, vague %.1f, pièces %.0f, niveaux achetés %.1f"
				% [policy, s["survived"], s["wave"], s["earned"], s["levels"]]
			)
		)
	print(
		(
			"[balance] %d parties × %d politiques de %.0f s max -> %s_runs.csv, %s_timeline.csv"
			% [_runs, POLICIES.size(), _seconds, _out, _out]
		)
	)
	var audio: Node = _tree.root.get_node_or_null("AudioManager")
	if audio != null:
		audio.call("shutdown")
	for i: int in 12:
		await _tree.process_frame
	_tree.quit(0)


func _simulate(
	policy: String, run: int, seed_value: int, timeline: PackedStringArray
) -> Dictionary:
	var g: Gameplay = (
		(load("res://scenes/gameplay/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	)
	g.set_physics_process(false)
	g.run_seed = seed_value
	_tree.root.add_child(g)
	await _tree.process_frame
	var earned: Array[int] = [0]
	var damage: Array[float] = [0.0]
	var on_died: Callable = func(_i: int, r: int, _p: Vector3) -> void: earned[0] += r
	var on_damaged: Callable = func(a: float, _h: float) -> void: damage[0] += a
	EventBus.enemy_died.connect(on_died)
	EventBus.player_damaged.connect(on_damaged)
	var joystick: FloatingJoystick = g.get_node("Ui/Joystick") as FloatingJoystick
	var steps: int = 0
	var max_steps: int = int(_seconds / DT)
	var peak: int = 0
	var pacing_min: float = 10.0
	var pacing_max: float = 0.0
	var next_sample: float = SAMPLE_EVERY
	var start_us: int = Time.get_ticks_usec()
	while steps < max_steps and g.ctx.player_alive:
		joystick.vector = BotInput.compute(g.ctx)
		g.step(DT)
		if _god:
			g._player.health.hp = g._player.health.max_hp
			g.ctx.player_hp_fraction = 1.0
		if policy == "lowest" and steps % BUY_EVERY_STEPS == 0:
			UpgradeBot.act(g._upgrades, g.ctx)
		peak = maxi(peak, g.ctx.enemies.count_living())
		pacing_min = minf(pacing_min, g.ctx.pacing)
		pacing_max = maxf(pacing_max, g.ctx.pacing)
		if g.ctx.time >= next_sample:
			next_sample += SAMPLE_EVERY
			timeline.append(_timeline_row(policy, run, g, earned[0]))
		steps += 1
	var ms: float = float(Time.get_ticks_usec() - start_us) / 1000.0 / maxf(float(steps), 1.0)
	var level_sum: int = 0
	var level_text: String = ""
	for lv: int in g.ctx.turret_levels:
		level_sum += lv - 1
		level_text += ("-" if level_text != "" else "") + str(lv)
	var died: bool = not g.ctx.player_alive
	var row: String = (
		"%s,%d,%d,%.1f,%d,%d,%d,%d,%d,%d,%s,%d,%.3f,%.3f,%.0f,%.3f"
		% [
			policy,
			run,
			seed_value,
			g.ctx.time,
			int(died),
			g.ctx.wave,
			g.ctx.kills,
			earned[0],
			g.ctx.coins_spent,
			g.ctx.bosses_defeated,
			level_text,
			peak,
			pacing_min,
			pacing_max,
			damage[0],
			ms,
		]
	)
	var result: Dictionary = {
		"row": row,
		"wave": float(g.ctx.wave),
		"survived": g.ctx.time,
		"earned": float(earned[0]),
		"levels": float(level_sum),
	}
	EventBus.enemy_died.disconnect(on_died)
	EventBus.player_damaged.disconnect(on_damaged)
	_tree.root.remove_child(g)
	g.free()
	return result


func _timeline_row(policy: String, run: int, g: Gameplay, earned: int) -> String:
	var level_text: String = ""
	for lv: int in g.ctx.turret_levels:
		level_text += ("-" if level_text != "" else "") + str(lv)
	return (
		"%s,%d,%.0f,%d,%d,%d,%d,%.0f,%d,%s"
		% [
			policy,
			run,
			g.ctx.time,
			g.ctx.wave,
			g.ctx.kills,
			earned,
			g.ctx.coins_spent,
			g._player.health.hp,
			g.ctx.enemies.count_living(),
			level_text,
		]
	)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var mid: int = sorted.size() / 2
	if sorted.size() % 2 == 1:
		return sorted[mid]
	return (sorted[mid - 1] + sorted[mid]) * 0.5


func _write(path: String, lines: PackedStringArray) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("[balance] impossible d'écrire %s" % path)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
