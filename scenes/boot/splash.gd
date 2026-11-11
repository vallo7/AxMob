extends Node
## Première scène du jeu : une page BLANCHE (aucun flash noir ni logo Godot), puis le chargement
## réel du menu principal par SceneLoader. L'écran de chargement prend le relais dès la première
## image.


func _ready() -> void:
	# Une image de page blanche, puis le chargement : la transition du démarrage Android (blanc)
	# reste continue.
	await get_tree().process_frame
	SceneLoader.go(LoadManifest.MENU_SCENE, {"first": true})
