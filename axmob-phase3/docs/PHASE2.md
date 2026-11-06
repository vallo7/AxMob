# Phase 2 — Prototype jouable (jalon G1) — Rapport (règle 10)

Date : 5 novembre 2026 · Godot 4.7.2-stable · base : archive `axmob-phase0.zip`

> Numérotation : la « Phase 1 » (préproduction) est le plan de réalisation v1.0 du 4 novembre.
> Le travail qui suit cette archive est donc la **Phase 2 du plan : prototype, primitives autorisées**.

## Objectif et critère de sortie (G1)
Cinq minutes jouables sur ton téléphone ; **toi seul** valides la sensation. Rien de ce qui
suit ne dit que le jeu est « bon » : il dit que la boucle complète tourne et est testée.

## Tâches réalisées
Boucle complète : joueur → joystick flottant → ennemis → contact (frôlement) → fenêtre de
combat → 4 tourelles qui visent et lancent des haches → dégâts → éliminations → pièces →
vagues → mort → écran de défaite → rejouer.

- **Joueur** : cercle cinématique sur le plan XZ, accélération 0,12 s / décélération 0,10 s,
  rotation lissée, glissement le long du bord, invulnérabilité clignotante (0,6 s).
- **Joystick flottant** (moitié basse de l'écran), zone morte radiale configurable, clavier
  WASD/flèches en repli sur PC.
- **Contact à deux anneaux** : anneau de déclenchement (rayons + 0,45) plus large que l'anneau
  de dégâts (portée d'attaque 0,25). Frôler active les tourelles sans forcément blesser.
  Filtre anti-répétition par ennemi (0,4 s), cooldown global 0,5 s, fenêtre 2 s qui se
  prolonge sans s'empiler. Anneau visible autour du joueur (orange quand la fenêtre est active).
- **Ennemis** (3 types pilotés par `EnemyData` : basique, rapide, lourd) : SPAWNING → CHASE →
  WINDUP (télégraphie) → ATTACK (un seul test, jamais à chaque frame) → RECOVER, STAGGER à
  l'impact (réduit pour les lourds), DYING. Séparation par la grille, répulsion au bord,
  accélération limitée. Récompense attribuée une seule fois.
- **Tourelles** (4 emplacements à 90°, 4 catégories distinctes par données) : machine à états
  DORMANT/ACQUIRING/AIMING/FIRING/RELOADING, rotation amortie, tolérance de tir 5°, visée
  prédictive, recul et flash. Attribution des cibles à 10 Hz : score (proximité, achever,
  menace, priorité, pénalité par tourelle déjà assignée), glouton, hystérésis 0,8 s / +25 %.
- **Haches** : pool de 128 (recyclage de la plus ancienne), collision par balayage de cercle
  contre la grille, un impact par ennemi et par hache, perforation, accélération (lourde),
  éventail (multiple). Le modèle est la vraie hache Blender du spike Phase 0 (`axe_light.glb`).
- **Vagues** par budget `b0 + b1·n^p`, déblocages (rapide v3, lourd v5), apparitions étalées,
  bannière, répit entre vagues. Croissance PV/dégâts linéaire provisoire.
- **HUD** : PV, fenêtre de combat, vague, temps, pièces, pause, overlay debug (FPS, ennemis,
  haches, draw calls). Menu pause, écran de défaite. Caméra à largeur fixe, cadrage décalé
  vers le haut, suivi partiel lissé.
- **Boot** : boutons « JOUER (prototype) » et « Spike perf » (le spike Phase 0 reste accessible).
- Pause automatique en arrière-plan Android, bouton retour = pause.

## Fichiers
Créés : `scripts/{core,resources,gameplay,player,enemies,turrets,projectiles,economy,ui}/*`,
`scenes/{gameplay,turrets,tools}/*`, `resources/{balancing,enemies,turrets}/*.tres`,
`scripts/tests/{systems,gameplay}/*`, `scripts/tools/capture.gd`, `docs/PHASE2.md`.
Modifiés : `project.godot` (retour Android, émulation tactile souris), `scenes/boot/boot.gd`,
`scripts/core/event_bus.gd` (signaux ajoutés : `contact_detected`, `turret_fired`, `axe_hit`,
`enemy_attack_landed`, `enemy_spawn_requested`), `scripts/tests/run_tests.gd`, `ci.yml`.

## Vérifié ici (exécuté)
| Élément | Résultat |
|---|---|
| Godot 4.7.2 headless : import, scène Gameplay 900 frames | aucune erreur |
| `gdformat --check` / `gdlint` | OK |
| Tests : noyau (combat, visée, balayage, steering, ciblage, budget, données) + scénarios | **335 assertions OK** |
| Scénario « frôlement » : combat_activated émis, **0 dégât** | OK |
| Scénario anti-répétition : ≤ 3 activations en 1 s avec un ennemi collé | OK |
| Scénario tourelles : tirs, impacts, éliminations ; pièces == somme des récompenses ; kills == enemy_died | OK |
| Scénario joueur passif : mort, `game_over` émis une seule fois, écran affiché | OK |
| Scénario bot 90 s : 5 à 6 vagues, 40 à 54 éliminations selon l'aléa des vagues | OK (le bot n'est pas un joueur) |
| Charge : 60 ennemis (plafond), joueur et ennemis restent dans l'arène | 1,25 ms/tick CPU serveur |
| Rendu réel (OpenGL logiciel sous xvfb) : arène, tourelles, haches Blender en vol, anneau, flash d'impact | captures dans `docs/captures/` |

Bug trouvé et corrigé en route : `VirtualJoystick` est une classe native de Godot 4.7 ;
mon nœud s'appelle `FloatingJoystick`.

## NON vérifié (seul ton téléphone tranche)
- **La sensation** : vitesse, accélération, taille des personnages et de l'arène, lisibilité
  des haches et des ennemis, difficulté, rythme des vagues. Toutes les valeurs sont des
  hypothèses (`resources/balancing/*.tres`, `resources/enemies/*.tres`, `resources/turrets/*.tres`).
- Joystick tactile réel (zone de départ, taille 150 px, zone morte 0,15).
- FPS réel (les 1,25 ms/tick sont ceux d'un CPU de serveur, pas d'un téléphone).
- Build Android (Phase 0 toujours à confirmer), pause en arrière-plan, bouton retour.
- Mouvement à 120 Hz : l'affichage est plafonné à 60 FPS et la simulation est à pas fixe, sans
  interpolation (à ajouter si tu vois des saccades).
- Le job de captures de la CI (xvfb) n'a pas tourné sur GitHub (étape non bloquante).

## Décisions prises par défaut (à contester)
D1 fenêtre active = chaque tourelle tire sur tout ennemi à portée · D2 monnaie unique, niveaux
de tourelle non encore achetables · D3 4 emplacements à 90° (placés en diagonale) · D4 « Arène
de pierre » (primitives) · D7 Compatibility.

## Hors périmètre de cette phase (Phase 3+)
Améliorations de tourelles (10 niveaux) et dépenses de pièces, élites et boss, niveaux
d'ennemis, simulateur d'équilibrage, sauvegarde, menus complets, publicité, assets Blender
définitifs, effets et sons (aucun son pour l'instant).

## Test sur téléphone (G1)
1. Commiter l'archive, laisser la CI produire l'APK debug, l'installer.
2. Écran d'accueil → « JOUER (prototype) ».
3. Jouer ~5 min. Me renvoyer : ressenti (déplacement, frôlement, haches, ennemis), bugs,
   FPS affiché en haut à gauche, modèle de téléphone / Android / RAM (décision D8).
