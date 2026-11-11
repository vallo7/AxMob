class_name CrashGuard
extends RefCounted
## Garde anti-plantage (phase 6). Principe : un « témoin » est écrit au lancement (`running`) et
## effacé à la fermeture propre ET à la mise en arrière-plan (le système peut alors tuer l'appli
## sans que ce soit un plantage). Au lancement suivant, un témoin encore présent = l'appli s'est
## arrêtée en AVANT-PLAN sans prévenir (plantage natif, tueur de processus mémoire...).
##
## On ne connaît pas la cause (aucun téléphone ici) : on agit sur le SYMPTÔME. Le profil graphique
## actif au moment du plantage est « interdit » (le plafond devient le profil du dessous), puis
## pardonné après quelques lancements stables, une seule fois (deux plantages = interdit pour de
## bon).
## Logique PURE sur un dictionnaire (testée) ; l'accès fichier est dans `load_from` / `save_to`.

const VERSION: int = 1
const FORGIVE_AFTER_CLEAN: int = 5
const MAX_CRASHES_PER_TIER: int = 2
const NO_BAN: int = -1

var state: Dictionary = default_state()


static func default_state() -> Dictionary:
	return {
		"version": VERSION,
		"running": false,
		"tier": 1,
		"mode": 0,
		"banned_tier": NO_BAN,
		"crashes": 0,
		"crashes_by_tier": {},
		"last_crash_tier": NO_BAN,
		"clean_streak": 0,
		"sessions": 0,
		"locked": false,
	}


## Valide un dictionnaire lu sur le disque (valeurs absentes ou de mauvais type -> défauts).
static func sanitize(raw: Variant) -> Dictionary:
	var out: Dictionary = default_state()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw as Dictionary
	for key: String in ["running", "locked"]:
		if typeof(d.get(key)) == TYPE_BOOL:
			out[key] = d[key]
	for key: String in [
		"tier", "mode", "banned_tier", "crashes", "last_crash_tier", "clean_streak", "sessions"
	]:
		var v: Variant = d.get(key)
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			out[key] = int(v)
	out["tier"] = clampi(int(out["tier"]), 0, 2)
	out["mode"] = clampi(int(out["mode"]), 0, 3)
	out["banned_tier"] = clampi(int(out["banned_tier"]), NO_BAN, 2)
	var by_tier: Variant = d.get("crashes_by_tier")
	if typeof(by_tier) == TYPE_DICTIONARY:
		var clean: Dictionary = {}
		for k: Variant in (by_tier as Dictionary).keys():
			var n: Variant = (by_tier as Dictionary)[k]
			if typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT:
				clean[str(k)] = maxi(int(n), 0)
		out["crashes_by_tier"] = clean
	return out


## Analyse l'état laissé par la session précédente (à appeler UNE fois, avant start()).
## Retourne {crashed, tier, mode} ; met à jour interdiction, compteurs et série stable.
func detect() -> Dictionary:
	var result: Dictionary = {
		"crashed": false, "tier": int(state["tier"]), "mode": int(state["mode"])
	}
	if bool(state["running"]):
		result["crashed"] = true
		state["running"] = false
		state["crashes"] = int(state["crashes"]) + 1
		state["clean_streak"] = 0
		var tier: int = int(state["tier"])
		state["last_crash_tier"] = tier
		var by_tier: Dictionary = state["crashes_by_tier"] as Dictionary
		by_tier[str(tier)] = int(by_tier.get(str(tier), 0)) + 1
		if tier >= 1:
			var current: int = int(state["banned_tier"])
			state["banned_tier"] = tier if current == NO_BAN else mini(current, tier)
			if int(by_tier[str(tier)]) >= MAX_CRASHES_PER_TIER:
				state["locked"] = true
	else:
		state["clean_streak"] = int(state["clean_streak"]) + 1
		if _can_forgive():
			state["banned_tier"] = NO_BAN
	return result


func _can_forgive() -> bool:
	var banned: int = int(state["banned_tier"])
	if banned == NO_BAN or bool(state["locked"]):
		return false
	if int(state["clean_streak"]) < FORGIVE_AFTER_CLEAN:
		return false
	var by_tier: Dictionary = state["crashes_by_tier"] as Dictionary
	return int(by_tier.get(str(banned), 0)) < MAX_CRASHES_PER_TIER


## Profil le plus élevé autorisé (ÉLEVÉ = 2 s'il n'y a pas d'interdiction).
func ceiling() -> int:
	var banned: int = int(state["banned_tier"])
	return 2 if banned == NO_BAN else maxi(banned - 1, 0)


func is_banned(tier: int) -> bool:
	return tier > ceiling()


## Début de session : le témoin est posé.
func start(tier: int, mode: int) -> void:
	state["running"] = true
	state["tier"] = clampi(tier, 0, 2)
	state["mode"] = clampi(mode, 0, 3)
	state["sessions"] = int(state["sessions"]) + 1


## Le profil change en cours de partie : un plantage sera attribué au bon profil.
func note_tier(tier: int) -> void:
	state["tier"] = clampi(tier, 0, 2)


## Arrière-plan = pas de plantage possible ; retour au premier plan = témoin reposé.
func set_foreground(on: bool) -> void:
	state["running"] = on


## Fermeture propre.
func stop() -> void:
	state["running"] = false


# --- Fichier -------------------------------------------------------------------------------------


static func load_from(path: String) -> CrashGuard:
	var guard: CrashGuard = CrashGuard.new()
	if FileAccess.file_exists(path):
		guard.state = sanitize(JSON.parse_string(FileAccess.get_file_as_string(path)))
	return guard


## Écriture atomique (temporaire puis renommage) : un plantage PENDANT l'écriture ne corrompt rien.
func save_to(path: String) -> bool:
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK
