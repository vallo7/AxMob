# AxMob — ValloGame

Arena survival 3D (Godot 4.7.2, GDScript typé, Android portrait). Rapports : `docs/PHASE0.md`, `docs/PHASE2.md` (prototype jouable), `docs/PHASE3.md` (combat et systèmes), `docs/PHASE4.md` (assets Blender, décor plage, vibrations).

## Démarrer en local
```bash
godot --headless --import
godot --headless --script res://scripts/tests/run_tests.gd        # tests (code 1 si échec)
godot --headless --script res://scripts/tools/validate_assets.gd  # budgets des GLB
godot --headless --script res://scripts/tools/bench_grid.gd       # benchmark de la grille spatiale
```
Régénérer les modèles (Blender via le module pip `bpy`, Python 3.13 ; chaque script écrit
`blender/export/*.glb|.blend` **et** copie le GLB dans `assets/models/`) :
```bash
pip install bpy==5.2.3
for f in blender/source/*.py; do python "$f"; done        # tout (la bibliothèque est dans blender/source/lib/)
python blender/source/enemy_basic.py                       # un seul asset
godot --headless --import                                  # puis réimporter dans Godot
```
Contrôle visuel des modèles (mêmes matériau et éclairage que le jeu, rendu logiciel) :
```bash
xvfb-run -a godot --rendering-driver opengl3 --resolution 640x640 --path . \
  res://scenes/tools/asset_preview.tscn -- /tmp/previews enemy_basic enemy_boss:attack:0.7
```

## CI (GitHub Actions)
- `ci.yml` : lint/format, import, tests, simulation d'équilibrage (CSV), budgets d'assets, benchmark.
- `build-android.yml` : APK debug (artefact) à chaque push sur `main` ; AAB signé sur tag `v*`
  (Secrets : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER`, `ANDROID_KEYSTORE_PASSWORD`).
- `blender-export.yml` : exécute `blender/source/*.py` et publie GLB, .blend et textures.

## Conventions
- Animations Blender bouclées : nommer l'action `xxx-loop` ; Godot l'importe en `xxx` avec boucle linéaire.
  La copie de la dernière clé ajoutée par l'export est retirée au chargement (`ModelRig`).
- Modèles : avant = +Y dans Blender (= -Z dans Godot), origine au sol, un seul matériau (palette 8×8,
  `assets/textures/palette.png`) appliqué par le shader `assets/shaders/ax_toon.gdshader`.
- Les `.glb.import` committés désactivent LOD, tangentes, ombres et textures embarquées : gardez ces
  réglages pour un nouvel asset (copier un `.glb.import` existant).
- Le dossier `blender/` est ignoré par Godot (`.gdignore`) ; seuls les GLB copiés dans `assets/models/` sont importés.
- Budgets d'assets : `assets/budgets.json`.

## Prototype (phase 2)
```bash
godot --headless --script res://scripts/tests/run_tests.gd     # noyau + scénarios de gameplay
xvfb-run -a godot --rendering-driver opengl3 --resolution 540x960 \
  --path . res://scenes/tools/capture.tscn -- /tmp/shots       # captures de contrôle (bot)
```
Équilibrage : `resources/balancing/*.tres`, `resources/enemies/*.tres`, `resources/turrets/*.tres`.

## Phase 3
```bash
godot --headless --script res://scripts/tools/simulate_runs.gd -- --runs 6 --seconds 600 --out reports/balance
godot --headless --script res://scripts/tools/simulate_runs.gd -- --runs 3 --seconds 900 --god 1 --out reports/god
```
Réglages clés : `arena_radius` (taille de l'arène, tout le reste en découle) dans
`resources/balancing/game_config.tres` ; vibrations dans `scripts/haptics/haptic_patterns.gd` ;
coûts et niveaux d'ennemis dans `resources/balancing/balance_config.tres` ; boss dans
`resources/enemies/boss.tres`.

## Phase 4
Rapport : `docs/PHASE4.md` (planches de contrôle dans `docs/phase4/`).
Modèles : `blender/source/` (joueur, 5 ennemis, 4 tourelles, 4 haches, arène plage, mer, 10 décors) ;
intégration : `scripts/core/model_rig.gd` (animations, teinte par instance), `scripts/gameplay/arena.gd`
(décor), `scripts/enemies/enemy_manager.gd` (un pool de modèles par type).
Vibrations : test dans le menu pause (« TESTER LA VIBRATION ») ; la CI vérifie la permission VIBRATE
dans l'APK produit.
