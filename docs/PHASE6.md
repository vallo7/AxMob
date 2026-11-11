# Phase 6 — Interface complète, style cartoon, chargement, anti-plantage

Version du projet : **0.6.0**. Tests : **9 500 assertions, 0 échec** (`run_tests.gd`), `gdformat` et
`gdlint` propres, budgets d'assets validés. Captures de tous les écrans : `docs/phase6/`.

> **À lire d'abord : ce qui n'est PAS vérifié.** Aucun téléphone ici. Le plantage en graphisme élevé,
> le démarrage blanc Android et les vibrations ne sont pas confirmés sur appareil. La cause exacte du
> plantage est **inconnue** : j'ai supprimé la piste la plus probable et ajouté un système qui
> empêche la répétition et me donne les données si ça recommence (section 2).

## 1. Tâches réalisées

| Demande | Réalisé |
|---|---|
| Interface complète avec tes éléments | 11 écrans/éléments (chargement, menu 3D, améliorations, statistiques, réglages, pause, défaite, HUD, panneau de tourelles, toasts, joystick) |
| Éléments supplémentaires « exactement dans le même style » | `ui_src/candy.py` : moteur qui gonfle un masque 2D (volume, dégradé doux, reflet en haut à gauche, pas de contour noir). 6 couleurs de boutons ×3 formats, 4 panneaux, 2 pastilles, barres, interrupteur, curseur, joystick, **40 icônes** (dont 4 petites variantes de tes visuels) |
| Plantage en graphisme élevé / meilleure optimisation | Voir section 2 |
| Style cartoon complet | Shader toon refait (ombres colorées, 3 paliers, reflet « point », liseré), **contours** par coque inversée, textures de sable cartoon, effets (étoiles, nuages à contour, anneaux, traînées) |
| Modèles 3D de meilleure qualité | Arrondis plus fins (14×8 au lieu de 10×6), reflets de pupille sur les 5 ennemis, contours + éclairage cartoon. **Voir limites (section 5)** |
| Eau de meilleure qualité | `ax_ocean.gdshader` refait : bandes de profondeur, caustiques, écume festonnée + 2e ligne, traits de vagues, scintillements en étoile (ÉLEVÉ), transparence près du sable |
| Vrais écrans de chargement | `SceneLoader` : chargement **réel** en fil séparé (scène, 26 modèles, shaders, textures, 82 sons), barre = ce qui est chargé, préchauffage des shaders, erreur → RÉESSAYER / MENU |
| Remplacer le flash Android natif par une page blanche | Section 3 |

## 2. Plantage en graphisme élevé : ce qui a été fait

**Cause probable (non confirmée)** : le profil ÉLEVÉ activait le MSAA 2× du moteur Compatibility
avec réduction de résolution 3D, et le gouverneur **modifiait le MSAA en cours de partie** (chaque
changement réalloue les cibles de rendu). C'est la piste n°1 des plantages natifs Android.

1. **MSAA supprimé sur mobile** (`QualityProfile.effective_msaa`), gardé seulement sur ordinateur.
2. **Changements de profil encadrés** : on *descend* tout de suite, on *monte* seulement au début
   d'une vague, en pause ou au menu, au plus une fois toutes les 20 s, 10 changements maximum par
   session ; le viewport n'est touché que si la valeur change vraiment.
3. **Garde anti-plantage** (`CrashGuard`) : un témoin est posé au lancement et effacé à la
   fermeture propre **et** à la mise en arrière-plan. Témoin encore là au lancement suivant = arrêt
   en avant-plan sans prévenir. Le profil actif devient **interdit** (plafond = profil du dessous),
   pardonné après 5 lancements stables, **une seule fois** ; deux plantages au même profil = interdit
   pour de bon. ÉLEVÉ apparaît alors grisé avec un cadenas dans Réglages. Premier lancement de cette
   version : ÉLEVÉ imposé est ramené à AUTO et AUTO ne démarre pas au-dessus de MOYEN.
4. **Surveillance de la mémoire vidéo** : au-delà du budget du profil (BAS 220 / MOYEN 320 / ÉLEVÉ
   440 Mo, valeurs provisoires) le profil baisse avant que le système ne tue l'appli.
5. **Contours** désactivés sur BAS (la seconde passe double le coût des personnages).
6. **Rapport technique** : Réglages → COPIER LE RAPPORT TECHNIQUE (appareil, GPU, profil, plantages,
   mémoire, journal de la session et **de celle qui a planté**). Colle-le-moi si ça replante.

## 3. Démarrage Android blanc (à vérifier sur téléphone)

Options d'export lues dans le code de Godot 4.7.2 (`export_plugin.cpp`), dans les deux préréglages :
`splash_screen/disable_godot_boot_splash=true`, `splash_screen/icon` = image **transparente**,
`splash_screen/background_color` et `screen/background_color` = **blanc** (ce dernier était noir
par défaut : probablement le flash). Projet : fond de démarrage blanc, pas d'image, couleur d'effacement
blanche ; la scène `splash.tscn` est une page blanche puis le logo apparaît. Icône du lanceur :
ton icône (principale + adaptative). La CI affiche un avertissement si le thème généré n'est pas blanc.

## 4. Fichiers

**Nouveaux** — `scripts/ui/` : `ui_art.gd`, `widgets/` (`ax_button`, `ax_round_button`, `ax_toggle`,
`ax_slider`, `ax_segment`, `ax_bar`, `ax_pill`, `ax_screen`), `screens/` (`main_menu`, `settings_screen`,
`upgrades_screen`, `stats_screen`), `loading/` (`scene_loader`, `loading_screen`, `load_progress`,
`load_manifest`) ; `scripts/save/` (`save_data`, `save_manager`) ; `scripts/economy/permanent_*` ;
`scripts/perf/` (`crash_guard`, `diagnostics`, `device_profile`) ; `scripts/core/loc*.gd` ;
`scripts/fx/toon_style.gd` ; shaders `ax_outline` ; `scenes/boot/splash`, `scenes/main_menu/` ;
`assets/ui/` (91 PNG), `assets/fonts/` (Lilita One, licence OFL incluse) ; `ui_src/` ; outils
`capture_ui` ; tests `test_phase6_logic.gd` et `test_phase6.gd`.
**Modifiés** — `project.godot` (autoloads Diagnostics, SaveManager, SceneLoader ; scène principale ;
icône ; démarrage blanc), `export_presets.cfg`, `quality_*`, `audio_manager` (musique et effets
séparés + volumes), `user_settings`, `gameplay.gd`, `hud`, `pause_menu`, `game_over_screen`,
`turret_*`, shaders toon/océan/effets, `arena.gd`, scripts Blender, `budgets.json`, workflows.
`scenes/boot/boot.tscn` n'est plus utilisée (à supprimer si tu veux).

## 5. Fonctionnalités réellement opérationnelles

- **Sauvegarde** (avancée de la phase 7, car AMÉLIORATIONS et STATISTIQUES l'exigent) : JSON versionné,
  écriture atomique, copie `.bak`, valeurs par défaut si invalide.
- **Améliorations permanentes** : PV, puissance, cadence, bonus de pièces, vitesse (10 niveaux,
  coût ×1,5). Effet **réel** sur la partie suivante. **Valeurs provisoires**, non équilibrées.
- **Pièces** : les pièces non dépensées sont versées à la fin de partie, au retour au menu ou au
  redémarrage (jamais deux fois). Records et statistiques mis à jour.
- Réglages : musique/effets (interrupteurs + volumes séparés), sensibilité du joystick (5 crans),
  vibrations, qualité, jeu pendant les améliorations, langue FR/EN/auto, FPS, rapport.
- Bouton retour Android : fermer l'écran ouvert ; au menu, double appui pour quitter.
- Formats d'écran : vérifiés en 9:16 et 9:19,5 (captures).

## 6. Limites, problèmes, tâches restantes

- **Modèles** : amélioration *progressive* (arrondis, reflets de pupille, rendu cartoon), pas une
  remodélisation complète. Environ **+40 % de triangles** sur les personnages (budgets relevés).
  Le héros n'a pas été remodelé. Dis-moi lesquels te déçoivent, je les reprendrai un par un.
- **RÉANIMER** (pub récompensée) : volontairement **absent** tant que la phase 8 n'existe pas ;
  l'écran est prêt (`set_revive_available`).
- **Cadeau et étoile** fournis : non utilisés (aucun endroit fonctionnel ; je n'affiche pas de
  bouton décoratif). Disponibles dans `assets/ui/icons/`.
- Pièces d'une partie **tuée par le système en arrière-plan** : perdues (versement à la fin de partie).
- Phase 7 : il reste les tests de persistance sur téléphone et l'équilibrage des coûts permanents.
- À tester sur téléphone : démarrage blanc, ÉLEVÉ sans plantage, durée du chargement, 60 FPS,
  lisibilité des contours.
