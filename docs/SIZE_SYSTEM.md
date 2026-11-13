# Système de tailles d'AxMob (phase 7)

**1 unité = 1 mètre.** Toutes les tailles ci-dessous sont mesurées sur les vrais modèles par
`scripts/tests/systems/test_phase7_scale.gd` (boîtes englobantes des GLB × échelle appliquée par le jeu) :
si une valeur dérive, le test échoue.

Le **héros** est l'unité de référence : 2,2 m de haut (échelle 1,2 appliquée à un modèle de 1,85 m),
hitbox de 1,0 m de diamètre.

| Élément | Taille visible (L × H × P) | Hitbox (diamètre) | Rapport au héros |
|---|---|---|---|
| Héros | 1,4 × 2,2 × 1,0 | 1,0 | 1× |
| Crabe (basique) | 1,5 × 0,8 × 1,0 | 1,1 | genou |
| Crevette (rapide) | 0,9 × 0,5 × 1,6 | 0,8 | cheville, longue |
| Tortue (lourde) | 1,6 × 0,9 × 2,3 | 1,8 | mi-cuisse, large |
| Poisson-globe (élite) | 1,9 × 1,4 × 1,6 | 1,6 | hanche |
| Kraken (boss) | 5,2 × 4,1 × 4,3 | 3,6 | ~1,9× |
| Canons (×1,25) | ~2,6 de large × 2,1 à 2,6 de haut | collision 2,3 | ~1× (un peu plus gros) |
| Palmier | ~5,5 de haut | tronc 0,9 | ~2,5× |
| Parasol | ~2,5 de haut | pied 0,6 | ~1,1× |
| Château de sable | ~2,2 × 1,5 | 2,0 | — |
| Rochers | 0,9 à 1,9 de large | 0,9 à 1,7 | — |

Règles :
- **Ce qu'on voit = ce qu'on touche** : l'empreinte visible d'un ennemi vaut 0,8 à 1,6 fois sa hitbox
  (avant la phase 7, un crabe affichait 2,0 m pour une hitbox de 0,8 m).
- **Aucun ennemi n'est plus haut que le héros**, sauf le boss (≥ 1,5×).
- **Décor haut au nord seulement** (palmiers, parasol, château) : la caméra regarde vers le nord depuis
  le sud ; un élément haut au sud masquerait le joueur. Le sud n'a que du décor bas.
- Les décors **solides** (palmiers, rochers, château, parasol) et les **canons** sont des obstacles
  circulaires : le joueur et les ennemis glissent autour ; les haches passent.

## Caméra

Largeur de monde visible : **22 m** au point visé (`GameConfig.view_width`), focale étroite 34°
(peu de déformation), inclinaison **46°** (vue oblique : on perçoit la hauteur des éléments), la
caméra **suit** le joueur (`FeelConfig.follow_factor` 0,82) sur l'île entière. Joueur au centre, les
quatre canons restent à l'écran (test `test_island_camera_follows_and_turrets_visible_from_the_centre`).
Résultat : le héros occupe ~10 % de la largeur de l'écran (≈ 5 % avant).

## L'île est l'arène

Plus de bordure. Le contour réel de la plage (`IslandShape`, même formule que le modèle Blender et le
shader de la mer) est la seule limite : le joueur s'arrête au bord de l'eau, les ennemis peuvent
patauger dans l'eau peu profonde. Rayon moyen jouable 16,2 m ; canons sur un anneau de 9,8 m.
Les ennemis **sortent de l'eau** (sur le rivage, éclaboussure + gouttes) ou **du sable** (secousse,
fissure, éclats) : 40 % sable, 60 % eau ; le boss sort toujours de la mer, du côté opposé au joueur.
