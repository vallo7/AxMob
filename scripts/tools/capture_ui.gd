extends Node
## Captures de TOUS les écrans de la phase 6 (nécessite un rendu : xvfb + OpenGL logiciel).
## xvfb-run -a godot --rendering-driver opengl3 --resolution 540x960 --path . \
##   res://scenes/tools/capture_ui.tscn -- /tmp/shots_ui [fr|en]
## Utilise une sauvegarde de démonstration (user://capture_save.json) : rien n'est écrasé.

const DT: float = 1.0 / 60.0

var _out: String = "/tmp/axmob_ui"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	Loc.override_lang = args[1] if args.size() > 1 else "fr"
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.path_override = "user://capture_save.json"
	var d: SaveData = SaveManager.data
	d.coins = 1250
	d.perm_levels = PackedInt32Array([2, 1, 3, 0, 1])
	d.best_wave = 12
	d.best_time = 412.0
	d.total_kills = 1834
	d.total_coins_earned = 9650
	d.bosses_defeated = 3
	d.games_played = 27
	d.total_play_time = 5120.0
	await _run()
	AudioManager.shutdown()
	get_tree().quit()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[capture_ui] ", name)


func _run() -> void:
	# 1. écran de chargement (premier lancement : page blanche puis logo)
	var ls: LoadingScreen = LoadingScreen.new()
	add_child(ls)
	await _frames(2)
	ls.open(true, false)
	await _frames(6)
	await _shot("00_blank_start")
	await _frames(50)
	ls.set_progress(0.62, Loc.t("load_assets"))
	await _frames(4)
	await _shot("01_loading")
	ls.queue_free()
	await _frames(2)
	# 2. menu principal
	var menu: MainMenu = (
		(load("res://scenes/main_menu/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	)
	add_child(menu)
	await _frames(100)
	await _shot("02_menu")
	var up: UpgradesScreen = UpgradesScreen.new()
	menu._root.add_child(up)
	await _frames(40)
	print(
		"[dbg] root ",
		menu._root.size,
		" screen ",
		up.size,
		" sheet ",
		up.sheet.size,
		" pos ",
		up.position,
		" dim ",
		up.dim.size
	)
	await _shot("03_upgrades")
	up.close()
	await _frames(30)
	var st: StatsScreen = StatsScreen.new()
	menu._root.add_child(st)
	await _frames(40)
	await _shot("04_stats")
	st.close()
	await _frames(30)
	var se: SettingsScreen = SettingsScreen.new()
	menu._root.add_child(se)
	await _frames(40)
	await _shot("05_settings")
	se._scroll.scroll_vertical = 1100
	await _frames(6)
	await _shot("06_settings_bottom")
	se.close()
	await _frames(30)
	menu.queue_free()
	await _frames(4)
	# 3. partie : HUD, panneau, pause, défaite
	var g: Gameplay = (
		(load("res://scenes/gameplay/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	)
	g.set_physics_process(false)
	g.run_seed = 4242
	add_child(g)
	await _frames(4)
	var joystick: FloatingJoystick = g.get_node("Ui/Joystick") as FloatingJoystick
	while g.ctx.time < 14.0:
		joystick.vector = BotInput.compute(g.ctx)
		g.step(DT)
		await get_tree().process_frame
	await _shot("07_hud")
	g.ctx.coins = 60
	g._toggle_upgrades()
	await _frames(40)
	await _shot("08_turret_panel")
	g._toggle_upgrades()
	await _frames(4)
	g._toggle_pause()
	await _frames(30)
	await _shot("09_pause")
	g._toggle_pause()
	await _frames(4)
	g._pause_menu.visible = false
	g._game_over.set_revive_available(false)
	g._game_over.show_results(g.ctx, {"new_best_wave": true, "banked": 37, "new_best_time": false})
	await _frames(80)
	await _shot("10_game_over")
