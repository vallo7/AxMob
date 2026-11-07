extends RefCounted
## Bouton retour : pile de gestionnaires, double pression pour quitter, réglages persistés.

var t: Object


func test_back_stack_top_handler_answers_first() -> void:
	var stack: BackStack = BackStack.new()
	var log: Array[String] = []
	var a: RefCounted = RefCounted.new()
	var b: RefCounted = RefCounted.new()
	stack.push(
		a,
		func() -> bool:
			log.append("a")
			return true
	)
	stack.push(
		b,
		func() -> bool:
			log.append("b")
			return true
	)
	t.call("check", stack.dispatch(), "consommé")
	t.call("check", log == ["b"], "seul l'écran du dessus répond (%s)" % str(log))
	stack.remove(b)
	t.call(
		"check",
		stack.dispatch() and log == ["b", "a"],
		"après fermeture, l'écran du dessous répond"
	)


func test_back_stack_falls_through_when_not_consumed() -> void:
	var stack: BackStack = BackStack.new()
	var log: Array[String] = []
	var a: RefCounted = RefCounted.new()
	var b: RefCounted = RefCounted.new()
	stack.push(
		a,
		func() -> bool:
			log.append("a")
			return true
	)
	stack.push(
		b,
		func() -> bool:
			log.append("b")
			return false
	)
	t.call("check", stack.dispatch(), "le dessous consomme")
	t.call("check", log == ["b", "a"], "b décline puis a répond (%s)" % str(log))
	var empty: BackStack = BackStack.new()
	t.call("check", not empty.dispatch(), "pile vide : rien de consommé")


func test_back_stack_repush_and_dead_owner() -> void:
	var stack: BackStack = BackStack.new()
	var count: Array[int] = [0]
	var owner: RefCounted = RefCounted.new()
	stack.push(
		owner,
		func() -> bool:
			count[0] += 1
			return true
	)
	stack.push(
		owner,
		func() -> bool:
			count[0] += 10
			return true
	)
	t.call("check", stack.size() == 1, "un propriétaire n'a qu'un gestionnaire")
	stack.dispatch()
	t.call("check", count[0] == 10, "le dernier enregistrement remplace le précédent")
	var doomed: Object = Object.new()
	stack.push(
		doomed,
		func() -> bool:
			count[0] += 100
			return true
	)
	doomed.free()
	stack.dispatch()
	t.call("check", count[0] == 20, "un propriétaire détruit est ignoré et purgé (%d)" % count[0])
	t.call("check", stack.size() == 1)


func test_back_stack_handler_may_remove_itself() -> void:
	var stack: BackStack = BackStack.new()
	var owner: RefCounted = RefCounted.new()
	var other: RefCounted = RefCounted.new()
	var hits: Array[int] = [0]
	stack.push(
		other,
		func() -> bool:
			hits[0] += 1
			return true
	)
	stack.push(
		owner,
		func() -> bool:
			stack.remove(owner)
			return false
	)
	t.call(
		"check",
		stack.dispatch() and hits[0] == 1,
		"un écran qui se ferme laisse répondre le suivant"
	)
	t.call("check", not stack.has(owner))


func test_double_press_quit_window() -> void:
	var d: DoublePress = DoublePress.new(2.0)
	t.call("check", not d.press(10.0), "1re pression : avertir")
	t.call("check", d.press(11.5), "2e pression dans la fenêtre : quitter")
	t.call("check", not d.press(11.6), "réarmé après confirmation")
	t.call("check", not d.press(20.0), "trop tard : nouvel avertissement")
	t.call("check", d.press(21.9), "et on peut confirmer ensuite")


func test_user_settings_defaults_roundtrip_and_invalid() -> void:
	UserSettings.path_override = "user://test_settings.cfg"
	DirAccess.remove_absolute(UserSettings.path_override)
	t.call(
		"check",
		UserSettings.haptics_level() == UserSettings.DEFAULT_HAPTICS_LEVEL,
		"défaut sans fichier"
	)
	t.call("check", UserSettings.upgrade_pause(1) == 1, "repli du mode d'amélioration")
	UserSettings.set_haptics_level(3)
	UserSettings.set_upgrade_pause(2)
	t.call("check", UserSettings.haptics_level() == 3, "niveau relu après écriture")
	t.call("check", UserSettings.upgrade_pause(0) == 2)
	UserSettings.set_haptics_level(99)
	t.call(
		"check",
		UserSettings.haptics_level() == UserSettings.HAPTICS_LEVELS.size() - 1,
		"borné à l'écriture"
	)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("haptics", "level", "n'importe quoi")
	cfg.save(UserSettings.path_override)
	t.call(
		"check",
		UserSettings.haptics_level() == UserSettings.DEFAULT_HAPTICS_LEVEL,
		"valeur invalide : défaut"
	)
	var broken: FileAccess = FileAccess.open(UserSettings.path_override, FileAccess.WRITE)
	broken.store_string("[[[ pas un fichier valide")
	broken.close()
	t.call(
		"check",
		UserSettings.haptics_level() == UserSettings.DEFAULT_HAPTICS_LEVEL,
		"fichier corrompu : défaut"
	)
	DirAccess.remove_absolute(UserSettings.path_override)
	UserSettings.path_override = ""
