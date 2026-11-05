# AxMob — ValloGame

Arena survival 3D (Godot 4.7.2, GDScript typé, Android portrait). Plan : voir `docs/PHASE0.md`.

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
- `ci.yml` : lint/format, import, tests, budgets d'assets, benchmark.
- `build-android.yml` : APK debug (artefact) à chaque push sur `main` ; AAB signé sur tag `v*`
  (Secrets : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER`, `ANDROID_KEYSTORE_PASSWORD`).
- `blender-export.yml` : exécute `blender/source/*.py` et publie les GLB.

## Conventions
- Animations Blender bouclées : nommer l'action `xxx-loop` ; Godot l'importe en `xxx` avec boucle linéaire.
- Le dossier `blender/` est ignoré par Godot (`.gdignore`) ; seuls les GLB copiés dans `assets/models/` sont importés.
- Budgets d'assets : `assets/budgets.json`.
