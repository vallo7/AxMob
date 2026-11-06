# Phase 0 — Rapport (règle 10)

Date : 4 novembre 2026 · Godot 4.7.2-stable · bpy 5.2.3

## Tâches réalisées
- Dépôt structuré selon le plan (scenes/, scripts/, resources/, blender/, assets/, docs/, .github/).
- `project.godot` : Compatibility, portrait 1080×1920, `keep_width`, 60 FPS, avertissements de typage durcis.
- Noyau : `EventBus` (signaux du cahier des charges + ajouts du plan), `SpatialGrid`.
- Scène témoin `boot` (cube 3D, version Godot, renderer, FPS) et spike perf (MultiMesh, 100 → 400 ennemis, tap = +50).
- Runner de tests maison, validateur de GLB, benchmark de grille.
- Pipeline Blender → Godot : hache `axe_light` (script bpy → GLB → import → validation).
- CI : `ci.yml`, `build-android.yml`, `blender-export.yml`, scripts `scripts/ci/*`, `export_presets.cfg` (APK debug + AAB release).

## Vérifié ici (exécuté)
| Élément | Résultat |
|---|---|
| Godot 4.7.2 headless : import, scène boot 120 frames, spike perf 240 frames | OK, aucune erreur |
| Tests (grille vs force brute, coordonnées négatives, clear) | 52 assertions OK |
| gdformat / gdlint (gdtoolkit 4.5.0) | OK |
| Templates 4.7.2 : `android_source.zip`, `version.txt` = `4.7.2.stable` | présents |
| Chaîne Blender : `bpy` 5.2.3 (Python 3.13) → GLB → import Godot → validation | OK : 56 triangles, 0,82 m, 3 matériaux, animation `spin` 0,400 s en boucle |
| `export_presets.cfg` : preset « Android » reconnu par Godot | OK (l'export s'arrête ensuite faute de SDK, attendu ici) |
| Syntaxe YAML des 3 workflows, `bash -n` du script Android | OK |

Bug trouvé et corrigé par les tests : les `PackedArray` sont copiés à la lecture en GDScript, la première version de la grille perdait des ennemis dans les cellules partagées.

## Mesure indicative (CPU serveur x86, GDScript, grille seule)
100 / 200 / 400 / 800 entités : ≈ 0,35 / 0,85 / 2,0 / 3,4 ms par tick (reconstruction + une requête par entité).
Ce n'est PAS une mesure téléphone : le plafond de 60 ennemis du plan reste très confortable côté grille, mais seul le spike perf sur ton appareil tranche.

## Spike AdMob — résultat
- Plugin Poing Studios : addon `addons/admob` + archive Android liée à la version de Godot, à placer dans `res://android/plugins`, build Gradle obligatoire ; l'App ID doit être déclaré dans `AndroidManifest.xml` (sinon crash au démarrage).
- La dernière release Android (v4.1.0) publie des archives pour Godot 4.2.0 → 4.6.1 : **aucune archive 4.7.x**.
- Plan B ordonné : (1) tester l'archive 4.6.1 sur un build 4.7.2 (risque : API du plugin Android) ; (2) compiler le plugin depuis ses sources contre godot-lib 4.7.2 ; (3) petit plugin Android maison autour du SDK Google Mobile Ads.
- Non testé : aucun build Android n'a pu tourner ici (SDK Android non téléchargeable depuis cet environnement).

## Non vérifié (à confirmer au premier run CI)
- Gradle build complet (SDK 35 / build-tools 35.0.1 / NDK 28.1.13356709 / CMake 3.10.2.4988404, valeurs de la doc Godot).
- Actions `android-actions/setup-android@v3`, nom du fichier de réglages éditeur, template Gradle installé à la main.
- Rendu réel sur téléphone, FPS réel, sensation de jeu.
- Pas de rendu de prévisualisation de la hache (à faire en Phase 4 avec les vrais assets).

## Décisions en attente
- D8 : modèle, version Android et RAM de ton téléphone (définit l'appareil plancher).
- D6 : confirmer `com.vallogame.axmob` ; le keystore release sera créé plus tard avec mon guidage.

## Tâches restantes de la Phase 0
1. Tu crées le dépôt GitHub et tu commites l'archive.
2. Tu me colles le journal du premier run CI (ou confirmes qu'il est vert).
3. Tu installes l'APK debug : tu me dis si le cube s'affiche, puis le FPS à 100 / 200 / 300 / 400 ennemis.
4. Spike AdMob sur appareil (voir plan B ci-dessus).
Sortie de phase : APK installable affichant une scène 3D + compatibilité des outils confirmée ou plan B décidé.
