extends RefCounted
## Phase 6 : parcours complet avec le VRAI chargeur (SceneLoader) : menu -> partie -> menu,
## versement
## des pièces à la sauvegarde, bonus permanents appliqués à la partie.

const TMP_SAVE: String = "user://test_save_p6g.json"

var t: Object


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _wait_loader() -> void:
	var n: int = 0
	while SceneLoader.busy and n < 2400:
		await _tree().process_frame
		n += 1


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TMP_SAVE + suffix):
			DirAccess.remove_absolute(TMP_SAVE + suffix)


func test_loader_menu_game_menu_and_banking() -> void:
	var tree: SceneTree = _tree()
	var saved_path: String = SaveManager.path_override
	var saved_data: SaveData = SaveManager.data
	SaveManager.path_override = TMP_SAVE
	_cleanup()
	SaveManager.data = SaveData.new()
	SaveManager.data.perm_levels = PackedInt32Array([5, 0, 0, 4, 0])  # +40 PV, +20 % de pièces
	SaveManager.data.coins = 0

	SceneLoader.go(LoadManifest.MENU_SCENE, {"first": true})
	await _wait_loader()
	t.call("check", not SceneLoader.busy, "le chargement du menu se termine")
	t.call("check", tree.current_scene is MainMenu, "le menu principal est affiché")

	SceneLoader.go(LoadManifest.GAMEPLAY_SCENE)
	await _wait_loader()
	var g: Gameplay = tree.current_scene as Gameplay
	t.call("check", g != null, "la partie est chargée par le chargeur")
	if g == null:
		SaveManager.data = saved_data
		SaveManager.path_override = saved_path
		_cleanup()
		return
	t.call(
		"check",
		is_equal_approx(g._player.health.max_hp, g.ctx.config.player_hp + 40.0),
		"bonus de PV appliqué"
	)
	t.call("check", is_equal_approx(g.ctx.bonuses.coin_mult, 1.2), "bonus de pièces actif")
	t.call("check", not tree.paused, "jeu actif après le chargement")

	# Le joueur arrête la partie avec 30 pièces non dépensées : elles sont conservées.
	g.ctx.coins = 30
	g.ctx.time = 50.0
	g.ctx.wave = 4
	g._to_menu()
	await _wait_loader()
	t.call("check", tree.current_scene is MainMenu, "retour au menu principal")
	t.call("check", SaveManager.coins() == 30, "pièces non dépensées conservées")
	t.call(
		"check",
		SaveManager.data.best_wave == 4 and SaveManager.data.games_played == 1,
		"records et parties enregistrés"
	)

	if tree.current_scene != null:
		tree.current_scene.queue_free()
	await tree.process_frame
	SaveManager.data = saved_data
	SaveManager.path_override = saved_path
	_cleanup()
