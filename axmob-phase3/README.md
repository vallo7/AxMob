# AxMob — ValloGame

Arena survival 3D (Godot 4.7.2, GDScript typé, Android portrait). Rapports : `docs/PHASE0.md`, `docs/PHASE2.md` (prototype jouable), `docs/PHASE3.md` (combat et systèmes).

## Démarrer en local
```bash
godot --headless --import
godot --headless --script res://scripts/tests/run_tests.gd        # tests (code 1 si échec)
godot --headless --script res://scripts/tools/validate_assets.gd  # budgets des GLB
godot --headless --script res://scripts/tools/bench_grid.gd       # benchmark de la grille spatiale
```
Régénérer la hache témoin (Blender via le module pip `bpy`, Python 3.13) :
```bash
pip install bpy==5.2.3 && python blender/source/axe_light.py && cp blender/export/axe_light.glb assets/models/
```

## CI (GitHub Actions)
- `ci.yml` : lint/format, import, tests, simulation d'équilibrage (CSV), budgets d'assets, benchmark.
- `build-android.yml` : APK debug (artefact) à chaque push sur `main` ; AAB signé sur tag `v*`
  (Secrets : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER`, `ANDROID_KEYSTORE_PASSWORD`).
- `blender-export.yml` : exécute `blender/source/*.py` et publie les GLB.

## Conventions
- Animations Blender bouclées : nommer l'action `xxx-loop` ; Godot l'importe en `xxx` avec boucle linéaire.
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
