extends Node
## Navigation (autoload). Reçoit le bouton retour du téléphone — NOTIFICATION_WM_GO_BACK_REQUEST,
## envoyée par Godot à tous les noeuds : AUCUN autre script ne doit la traiter, sinon double
## traitement — et la distribue à la pile BackStack : l'écran le plus récent répond d'abord.
## Sur PC (test), Échap joue le même rôle. Affiche aussi les petits messages (toast).
## `config/quit_on_go_back=false` (project.godot) : c'est le jeu qui décide de quitter.

signal back_pressed(consumed: bool)

const TOAST_TIME: float = 1.6

var stack: BackStack = BackStack.new()

var _toast_layer: CanvasLayer
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func _unhandled_input(event: InputEvent) -> void:
	# Échap : repli pour tester sur PC. Sur mobile, seul le bouton retour du système compte.
	if not OS.has_feature("mobile") and event.is_action_pressed(&"ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()


## Enregistre un écran : `handler` retourne vrai s'il a géré le retour. Retiré automatiquement
## quand `owner` quitte l'arbre.
func push_back(owner: Node, handler: Callable) -> void:
	stack.push(owner, handler)
	if not owner.tree_exiting.is_connected(_on_owner_exiting.bind(owner)):
		owner.tree_exiting.connect(_on_owner_exiting.bind(owner), CONNECT_ONE_SHOT)


func pop_back(owner: Node) -> void:
	stack.remove(owner)


func handle_back() -> bool:
	var consumed: bool = stack.dispatch()
	back_pressed.emit(consumed)
	return consumed


func toast(text: String) -> void:
	if _toast == null:
		_build_toast()
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)


func current_toast() -> String:
	return _toast.text if _toast != null and _toast.modulate.a > 0.0 else ""


func _on_owner_exiting(owner: Node) -> void:
	stack.remove(owner)


func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 120
	add_child(_toast_layer)
	_toast = Label.new()
	UiArt.style_label(_toast, 38, UiArt.WHITE, UiArt.INK)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = UiArt.tex("panels/plate_dark")
	sb.texture_margin_left = 46.0
	sb.texture_margin_right = 46.0
	sb.texture_margin_top = 40.0
	sb.texture_margin_bottom = 46.0
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 24.0
	_toast.add_theme_stylebox_override("normal", sb)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.anchor_left = 0.1
	_toast.anchor_right = 0.9
	_toast.offset_top = -400.0
	_toast.offset_bottom = -230.0
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_left = 0.0
	_toast.offset_right = 0.0
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast_layer.add_child(_toast)
