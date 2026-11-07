class_name ModelRig
extends RefCounted
## Enveloppe d'un modèle glTF du jeu (phase 4) : applique le matériau partagé « palette », gère
## les animations à la main (pas de _process par modèle : le jeu les fait avancer au pas fixe,
## donc elles respectent la pause et le ralenti) et expose les paramètres de teinte par instance
## du shader ax_toon (teinte de niveau, flash d'impact, armement, lueur) sans nouveau matériau.
##
## Conventions des modèles (plan §6.2) : avant = -Z, origine au sol, os = pivots, animations
## `idle`, `run`, `attack` (frappe à STRIKE_FRACTION), `hit`, `death`, + boss : `charge_windup`,
## `charge`, `roar`.

const PALETTE: ShaderMaterial = preload("res://assets/materials/ax_palette.tres")
const MODEL_DIR: String = "res://assets/models/"
## Moment de la frappe dans le clip `attack` (0..1) : le jeu cale la fin de l'armement dessus.
const STRIKE_FRACTION: float = 0.5
const BLEND_TIME: float = 0.08

static var _scenes: Dictionary = {}
static var _loops_fixed: Dictionary = {}

var root: Node3D
var player: AnimationPlayer
var current: StringName = &""
var model_name: String = ""

var _meshes: Array[MeshInstance3D] = []
var _flash: float = 0.0
var _glow: float = 0.0
var _tint: Color = Color(1.0, 1.0, 1.0, 0.0)
var _alert: Color = Color(1.0, 0.35, 0.1, 0.0)


## Crée une instance du modèle (null si le fichier manque : l'appelant doit le signaler).
static func create(model: String) -> ModelRig:
	var packed: PackedScene = _scenes.get(model) as PackedScene
	if packed == null:
		packed = load(MODEL_DIR + model + ".glb") as PackedScene
		if packed == null:
			push_error("[ModelRig] modèle introuvable : %s" % model)
			return null
		_scenes[model] = packed
	var rig: ModelRig = ModelRig.new()
	rig.model_name = model
	rig.root = packed.instantiate() as Node3D
	for n: Node in rig.root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		mi.material_override = PALETTE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig._meshes.append(mi)
	var players: Array[Node] = rig.root.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		rig.player = players[0] as AnimationPlayer
		rig.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		rig.player.playback_default_blend_time = BLEND_TIME
		for a: StringName in rig.player.get_animation_list():
			_fix_loop(rig.player.get_animation(a))
	return rig


## L'export glTF ajoute une copie de la dernière clé (maintien d'une image) : sur une boucle elle
## ferait « bégayer » l'animation. On la retire ; la durée est inchangée, donc l'interpolation
## de bouclage relie la dernière pose à la première sur exactement une image.
static func _fix_loop(anim: Animation) -> void:
	if anim == null or anim.loop_mode == Animation.LOOP_NONE:
		return
	var id: int = anim.get_instance_id()
	if _loops_fixed.has(id):
		return
	_loops_fixed[id] = true
	for t: int in anim.get_track_count():
		var n: int = anim.track_get_key_count(t)
		if n < 3:
			continue
		var last: Variant = anim.track_get_key_value(t, n - 1)
		var prev: Variant = anim.track_get_key_value(t, n - 2)
		if _same(last, prev):
			anim.track_remove_key(t, n - 1)


static func _same(a: Variant, b: Variant) -> bool:
	if a is Quaternion:
		return (a as Quaternion).is_equal_approx(b as Quaternion)
	if a is Vector3:
		return (a as Vector3).is_equal_approx(b as Vector3)
	return a == b


func has_anim(anim: StringName) -> bool:
	return player != null and player.has_animation(anim)


func length_of(anim: StringName) -> float:
	return player.get_animation(anim).length if has_anim(anim) else 0.0


## Joue `anim` à la vitesse `speed`. Si c'est déjà l'animation en cours, ne fait qu'ajuster la
## vitesse (sauf `restart`). Une animation inconnue est ignorée sans erreur.
func play(anim: StringName, speed: float = 1.0, restart: bool = false) -> void:
	if player == null or not player.has_animation(anim):
		return
	if anim == current and not restart:
		player.speed_scale = speed
		return
	current = anim
	player.speed_scale = 1.0
	player.play(anim, -1.0, speed, false)
	player.advance(0.0)


## Vrai quand l'animation en cours (non bouclée) est arrivée au bout.
func finished() -> bool:
	if player == null or current == &"" or not player.has_animation(current):
		return true
	var a: Animation = player.get_animation(current)
	if a.loop_mode != Animation.LOOP_NONE:
		return false
	return player.current_animation_position >= a.length - 0.001 or not player.is_playing()


func advance(dt: float) -> void:
	if player != null and player.is_playing():
		player.advance(dt)


## Se place directement à l'instant `t` (secondes) d'une animation (captures, tests).
func seek(anim: StringName, t: float) -> void:
	if player == null or not player.has_animation(anim):
		return
	current = anim
	player.play(anim, 0.0, 1.0, false)
	player.seek(t, true)
	player.pause()


func set_visible(v: bool) -> void:
	root.visible = v


func set_flash(v: float) -> void:
	if absf(v - _flash) > 0.002:
		_flash = v
		_push(&"flash", v)


func set_glow(v: float) -> void:
	if absf(v - _glow) > 0.002:
		_glow = v
		_push(&"glow", v)


## rgb = teinte, a = intensité du mélange (0 = couleurs de la palette).
func set_tint(c: Color) -> void:
	if not c.is_equal_approx(_tint):
		_tint = c
		_push(&"tint", c)


## rgb = couleur de lueur, a = force (armement, alerte).
func set_alert(c: Color) -> void:
	if not c.is_equal_approx(_alert):
		_alert = c
		_push(&"alert", c)


func get_flash() -> float:
	return _flash


func get_tint() -> Color:
	return _tint


func get_alert() -> Color:
	return _alert


func get_glow() -> float:
	return _glow


func find_node(node_name: String) -> Node3D:
	return root.find_child(node_name, true, false) as Node3D


func _push(param: StringName, value: Variant) -> void:
	for mi: MeshInstance3D in _meshes:
		mi.set_instance_shader_parameter(param, value)
