class_name LoadManifest
extends RefCounted
## Liste des ressources à charger AVANT une scène (chargement réel et fil séparé), par groupe.
## Charger d'avance = pas d'à-coups au premier tir, à la première apparition d'un ennemi ou au
## premier son : tout est déjà en cache quand la partie commence.

const MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const GAMEPLAY_SCENE: String = "res://scenes/gameplay/gameplay.tscn"
const SFX_DIR: String = "res://assets/audio/sfx/"
const MODEL_DIR: String = "res://assets/models/"

const MENU_MODELS: Array[String] = [
	"char_player",
	"arena_beach",
	"ocean",
	"deco_palm",
	"deco_umbrella",
	"deco_towel",
	"deco_ball",
	"deco_bucket",
	"deco_rock",
	"deco_sandcastle",
	"deco_shell",
	"deco_starfish",
	"deco_surfboard",
	"turret_rapid",
	"turret_heavy",
]
const GAME_MODELS: Array[String] = [
	"char_player",
	"arena_beach",
	"ocean",
	"enemy_basic",
	"enemy_fast",
	"enemy_heavy",
	"enemy_elite",
	"enemy_boss",
	"turret_rapid",
	"turret_heavy",
	"turret_multi",
	"turret_pierce",
	"axe_light",
	"axe_heavy",
	"axe_multi",
	"axe_pierce",
	"deco_palm",
	"deco_umbrella",
	"deco_towel",
	"deco_ball",
	"deco_bucket",
	"deco_rock",
	"deco_sandcastle",
	"deco_shell",
	"deco_starfish",
	"deco_surfboard",
]
const SHADERS: Array[String] = [
	"res://assets/shaders/ax_toon.gdshader",
	"res://assets/shaders/ax_outline.gdshader",
	"res://assets/shaders/ax_ocean.gdshader",
	"res://assets/shaders/ax_vignette.gdshader",
]


## Remplit `progress` pour la scène demandée. Retourne la liste des chemins (diagnostic).
static func fill(progress: LoadProgress, scene_path: String) -> void:
	var is_game: bool = scene_path == GAMEPLAY_SCENE
	progress.add_group("scene", 3.0, [scene_path] as Array[String])
	var models: Array[String] = []
	for m: String in GAME_MODELS if is_game else MENU_MODELS:
		models.append(MODEL_DIR + m + ".glb")
	progress.add_group("models", 3.0, models)
	progress.add_group("shaders", 0.5, existing(SHADERS))
	progress.add_group("ui", 1.0, ui_textures())
	if is_game:
		progress.add_group("audio", 2.0, sfx_files())
	else:
		progress.add_group("audio", 0.5, ["res://assets/audio/music/menu.ogg"] as Array[String])


static func existing(paths: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for p: String in paths:
		if ResourceLoader.exists(p):
			out.append(p)
	return out


static func ui_textures() -> Array[String]:
	var out: Array[String] = []
	for folder: String in ["buttons", "panels", "bars", "icons", "misc", "brand"]:
		for f: String in list_dir(UiArt.BASE + folder + "/"):
			if f.ends_with(".png"):
				out.append(UiArt.BASE + folder + "/" + f)
	return out


static func sfx_files() -> Array[String]:
	var out: Array[String] = []
	for f: String in list_dir(SFX_DIR):
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			out.append(SFX_DIR + f)
	return out


## Liste un dossier de ressources, aussi dans un export Android (où les fichiers d'origine
## n'existent plus : ResourceLoader.list_directory renvoie les ressources importées).
static func list_dir(path: String) -> PackedStringArray:
	var names: PackedStringArray = ResourceLoader.list_directory(path)
	if names.is_empty():
		names = DirAccess.get_files_at(path)
	var out: PackedStringArray = PackedStringArray()
	for n: String in names:
		var clean: String = n.trim_suffix(".import").trim_suffix(".remap")
		if not out.has(clean):
			out.append(clean)
	return out
