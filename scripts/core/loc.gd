class_name Loc
extends RefCounted
## Traductions de l'interface (plan D5 : français et anglais). Clé -> texte ; si la clé manque dans
## la langue demandée on retombe sur le français, puis sur la clé (jamais de texte vide).
## Langue : réglage joueur (AUTO = langue du téléphone si FR/EN, sinon anglais).

const LANGS: Array[String] = ["fr", "en"]
const MODE_NAMES: Array[String] = ["AUTO", "FRANÇAIS", "ENGLISH"]

## Langue forcée (tests) : vide = réglage joueur.
static var override_lang: String = ""


static func lang() -> String:
	if override_lang != "":
		return override_lang
	var mode: int = UserSettings.language_mode()
	if mode == 1:
		return "fr"
	if mode == 2:
		return "en"
	var sys: String = OS.get_locale_language()
	return sys if sys in LANGS else "en"


## Texte traduit ; `args` remplace les %s / %d dans l'ordre (format GDScript).
static func t(key: String, args: Array = []) -> String:
	var row: Dictionary = LocStrings.STRINGS.get(key, {}) as Dictionary
	var text: String = str(row.get(lang(), row.get("fr", key)))
	if args.is_empty():
		return text
	return text % args


static func has_key(key: String) -> bool:
	return LocStrings.STRINGS.has(key)
