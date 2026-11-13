class_name IslandShape
extends RefCounted
## Forme RÉELLE de l'île (phase 7) : toute l'île est l'arène, il n'y a plus de bordure artificielle.
## Le contour reprend la formule du modèle Blender (blender/source/arena_beach.py, edge(theta)) et
## du
## shader de la mer (ax_ocean.gdshader, island_edge) : changer l'une impose de changer les trois.
##
## Convention : theta = atan2(x, -z) (0 = haut de l'écran, croît vers la droite).
## Deux limites, toutes deux en MÈTRES du monde :
##  - joueur  : sable sec/humide, un peu avant la ligne d'eau ;
##  - ennemis : eau peu profonde (ils sortent des vagues) ; c'est là qu'ils apparaissent côté mer.
## Fonctions pures (testables sans moteur de rendu).

## Rayon moyen du bord du sable dans le modèle (mètres du modèle, avant mise à l'échelle).
const EDGE_BASE: float = 22.5
## Retrait (mètres du modèle) des limites par rapport au bord du sable.
const PLAYER_INSET: float = 2.2
const ENEMY_INSET: float = 0.9
## Rayon moyen de la zone jouable du joueur dans le modèle : sert à convertir un rayon de jeu en
## échelle.
const MODEL_PLAY_RADIUS: float = EDGE_BASE - PLAYER_INSET

## Échelle monde / modèle de l'île.
var world_scale: float = 1.0
## Ondulation du contour (1 = vrai contour, 0 = cercle parfait : utile pour les tests de géométrie).
var wobble: float = 1.0


func _init(p_scale: float = 1.0, p_wobble: float = 1.0) -> void:
	world_scale = p_scale
	wobble = p_wobble


## Échelle pour que le rayon moyen jouable (joueur) vaille `play_radius` mètres.
static func scale_for_play_radius(play_radius: float) -> float:
	return play_radius / MODEL_PLAY_RADIUS


## Bord du sable (mètres du modèle) dans la direction theta.
static func edge_model(theta: float, p_wobble: float = 1.0) -> float:
	return EDGE_BASE + p_wobble * (1.0 * sin(3.0 * theta + 0.6) + 0.6 * sin(5.0 * theta + 2.0))


static func theta_of(pos: Vector2) -> float:
	return atan2(pos.x, -pos.y)


## Point de rayon `r` dans la direction theta.
static func point(theta: float, r: float) -> Vector2:
	return Vector2(sin(theta) * r, -cos(theta) * r)


## Bord du sable en mètres du monde.
func edge(theta: float) -> float:
	return edge_model(theta, wobble) * world_scale


func player_limit(theta: float) -> float:
	return (edge_model(theta, wobble) - PLAYER_INSET) * world_scale


func enemy_limit(theta: float) -> float:
	return (edge_model(theta, wobble) - ENEMY_INSET) * world_scale


## Rayon moyen jouable (joueur) en mètres.
func mean_play_radius() -> float:
	return MODEL_PLAY_RADIUS * world_scale


## Garde un corps de rayon `body_radius` dans la zone du joueur.
func clamp_player(pos: Vector2, body_radius: float) -> Vector2:
	return _clamp(pos, body_radius, PLAYER_INSET)


## Garde un corps de rayon `body_radius` dans la zone des ennemis (eau peu profonde comprise).
func clamp_enemy(pos: Vector2, body_radius: float) -> Vector2:
	return _clamp(pos, body_radius, ENEMY_INSET)


func _clamp(pos: Vector2, body_radius: float, inset: float) -> Vector2:
	var d: float = pos.length()
	if d < 0.0001:
		return pos
	var limit: float = maxf(
		(edge_model(theta_of(pos), wobble) - inset) * world_scale - body_radius, 0.0
	)
	return pos if d <= limit else pos / d * limit


## Vrai si la position est au large du sable du joueur (dans l'eau peu profonde ou plus loin).
func is_water(pos: Vector2) -> bool:
	return pos.length() > player_limit(theta_of(pos)) + 0.15


## Répulsion vers l'intérieur près de la limite des ennemis (évite qu'ils collent à la côte).
func edge_push(pos: Vector2, body_radius: float, margin: float, strength: float) -> Vector2:
	var d: float = pos.length()
	if d < 0.0001:
		return Vector2.ZERO
	var limit: float = enemy_limit(theta_of(pos)) - body_radius
	var start: float = limit - margin
	if d <= start:
		return Vector2.ZERO
	return -pos / d * clampf((d - start) / margin, 0.0, 1.0) * strength


## Point d'apparition « sortie de la mer » : dans l'eau peu profonde, sur la limite des ennemis.
func water_point(theta: float, body_radius: float) -> Vector2:
	return point(theta, maxf(enemy_limit(theta) - body_radius, 0.0))


## Point d'apparition « sortie du sable » : fraction `frac` (0..1) de la limite du joueur.
func sand_point(theta: float, frac: float) -> Vector2:
	return point(theta, player_limit(theta) * clampf(frac, 0.0, 1.0))
