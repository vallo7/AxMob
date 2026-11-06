# AxMob — Phase 3 : combat et systèmes (rapport)

Godot 4.7.2 · GDScript typé · tests headless + simulateur d'équilibrage · **non testé sur téléphone**.

## 1. Vos trois modifications

### Arène agrandie « au maximum »
- Rayon **9,0 → 13,0** (surface ×2,1). Un seul réglage : `arena_radius` dans
  `resources/balancing/game_config.tres`. L'anneau de tourelles (`+1,4`) et le cadrage de la caméra
  (`camera_visible_width()`) en sont **déduits** : rien d'autre à toucher.
- **Limite physique à connaître** : la caméra est à largeur fixe et, en phase 2, l'arène remplissait
  déjà ~86 % de la largeur de l'écran. Un cercle ne peut pas être plus large que l'écran. « Plus
  grand » = plus d'espace de jeu en unités du monde, avec une caméra qui dézoome : l'arène occupe donc
  toujours la largeur, mais **joueur et ennemis paraissent ~25 % plus petits** et il y a plus de
  distance à parcourir. Si c'est trop petit à l'écran, baissez `arena_radius` (11 ou 12).
- Cadrage **mesuré** par un test : arène + 4 tourelles tiennent à l'écran même joueur collé au bord
  (pire cas 0,958 de la demi-largeur ; 1,0 = bord), écrans 9:21, 9:16 et 3:4.
- Conséquences réglées : portées des tourelles ×1,4 (elles dépassent le centre sans couvrir toute
  l'arène : il faut attirer les ennemis), vitesse joueur 5 → 6,5, vitesses ennemies ×1,3, distance
  minimale d'apparition 5 → 7. **Valeurs provisoires**, à juger au toucher.

### Retour haptique complet (vibration)
- Autoload `Haptics` (`scripts/haptics/`). Il écoute les événements du jeu et joue des motifs via
  `Input.vibrate_handheld(durée_ms, amplitude)` (signature vérifiée dans Godot 4.7.2).
- **Permission Android `VIBRATE` ajoutée aux deux presets d'export** (`permissions/vibrate=true`) :
  sans elle, Godot ignore la vibration sur Android.
- 17 motifs (`haptic_patterns.gd`) : contact, élimination, multi-élimination, tir de la tourelle
  lourde, dégâts reçus (léger/fort selon le coup), mort, début/fin de vague, avertissement de boss,
  changement de phase, onde de choc, boss vaincu, achat/refus d'amélioration, appui de bouton,
  avertissement « retour ».
- Règles (`HapticPlanner`, testé) : délai minimal par motif, priorités (une élimination ne coupe pas
  la mort), plafond de vibration cumulée sur 5 s (sauf dégâts/mort/boss), durée minimale 15 ms,
  impulsions trop faibles ignorées, rien en pause.
- Réglage joueur dans le **menu pause** : « VIBRATIONS : Désactivées / Légères / Normales / Fortes »
  (sauvegardé dans `user://settings.cfg`).
- Réglage fin : motifs dans `haptic_patterns.gd`, global dans `resources/balancing/haptics_config.tres`.

### Bouton retour du téléphone
- Constat dans le code source de Godot 4.7.2 : le retour Android envoie `NOTIFICATION_WM_GO_BACK_REQUEST`
  à **tous** les nœuds. Tout est donc centralisé dans l'autoload `UIManager` (pile `BackStack`) ;
  aucun autre script ne traite cette notification (sinon double traitement).
- Comportement : **Accueil** : 1re pression = message « Appuyez encore pour quitter », 2e dans 2 s =
  quitte. **En jeu** : pause ; **en pause** : reprise ; **panneau d'amélioration** : fermeture ;
  **mort** : ignoré ; **défaite** : retour à l'accueil. **Spike perf** : retour à l'accueil.
  Mise en arrière-plan : pause automatique (aussi depuis le panneau). Sur PC, Échap joue le même rôle.
- `quit_on_go_back=false` était déjà réglé : c'est le jeu qui décide de quitter.

## 2. Systèmes de la phase 3
- **Tourelles à 10 niveaux** par catégorie (`TurretLeveling`, courbes + tables explicites pour
  haches/perforation), paliers visuels aux niveaux 4, 7 et 10 (`Tier_1..3`), impulsion à l'achat.
- **Économie** : coût `14 × facteur_catégorie × 1,6^(niveau-1)` (`CostCurve`), dépenses atomiques
  (`EconomyManager.spend`), `UpgradeManager`, panneau 2×2 avec aperçu « stat → stat suivante »,
  pastille sur le bouton TOURELLES quand une amélioration est abordable.
- **Pause pendant les améliorations**, trois modes (menu pause) : arrêt total (défaut), ralenti ×0,25,
  aucune pause. Le joystick ignore les touchers sur le panneau.
- **Niveaux d'ennemis** (`EnemyLevels`) : PV ×1,28, dégâts ×1,14, vitesse ×1,025 (plafonnée à ×1,3),
  récompense ×1,22 par niveau, teinte par palier. Mélange progressif (un tiers des ennemis passe au
  niveau supérieur à la vague suivante) : pas de saut brutal. Remplace la croissance linéaire de la phase 2.
- **Élite** (dès la vague 7) et **boss** toutes les 10 vagues (`WaveTable`, `BossData`) : avertissement
  2 s avant (bandeau, repère directionnel, liseré rouge), 3 phases (66 % / 33 %), onde de choc
  télégraphiée, charge télégraphiée et esquivable (dès la phase 2, visée verrouillée 0,3 s avant),
  invocation de 3 ennemis (phase 3), barre dédiée en haut, jamais interrompu par un impact.
- **Barres de vie ennemies** (affichées ~2,5 s après un impact ; permanentes pour élites et boss).
- **Rythme adaptatif** ±15 % maximum de la cadence d'apparition (PV du joueur + taux d'élimination),
  jamais des stats ennemies. Journal : `pacing_log` dans `balance_config.gd`.
- **Simulateur d'équilibrage** `scripts/tools/simulate_runs.gd` (CSV, option `--god 1`).

## 3. Fichiers
- **Créés (≈ 40)** : `scripts/haptics/*`, `scripts/managers/ui_manager.gd`, `scripts/core/{back_stack,
  double_press,user_settings,cost_curve,turret_leveling,enemy_levels,adaptive_pacing,boss_phases}.gd`,
  `scripts/economy/upgrade_manager.gd`, `scripts/enemies/{boss_state,spawn_order}.gd`,
  `scripts/resources/{boss_data,turret_level_data,wave_table,haptics_config}.gd`,
  `scripts/ui/{turret_card,turret_upgrade_panel,enemy_bars,boss_bar}.gd`, `scripts/tools/{simulate_runs,
  simulation}.gd`, `resources/enemies/{elite,boss}.tres`, `resources/waves/wave_table.tres`,
  `resources/balancing/haptics_config.tres`, 5 fichiers de tests.
- **Modifiés** : `project.godot` (autoloads `UIManager`, `Haptics`), `export_presets.cfg` (VIBRATE),
  `ci.yml` (simulation), gameplay, ennemis, vagues, tourelles, projectiles, HUD, menu pause, caméra,
  `EventBus`, `RunContext`, données `.tres`, bot et capture.

## 4. Tests
- `godot --headless --script res://scripts/tests/run_tests.gd` : **7 359 assertions, 0 échec**
  (phase 2 : 335 ; beaucoup des nouvelles viennent de boucles de vérification).
- Couverts : coûts, 10 niveaux monotones par catégorie, paliers visuels, niveaux d'ennemis, rythme
  borné, phases du boss, cadence des boss, achat (pièces dépensées une fois, refus, niveau max,
  cohérence pièces = récompenses − dépenses sur 150 s), trois modes de pause, boutons du panneau,
  boss (avertissement → apparition, 3 phases annoncées une fois, récompense unique, onde de choc dans
  et hors du rayon, charge télégraphiée et **esquivable**, invocation phase 3 seulement), pile de retour,
  double pression, retour sur Gameplay/Accueil, planificateur et correspondance événement → vibration,
  cadrage de l'arène.
- `gdformat` / `gdlint` : propres. Budgets d'assets : 0 erreur. Captures de contrôle (xvfb) :
  `docs/captures/phase3_*.png`.
- Un message `ERROR: ConfigFile parse error` apparaît dans les tests : il est **voulu** (test d'un
  fichier de réglages volontairement corrompu → valeurs par défaut).

### Ce qui n'est PAS testé
- **Aucun test sur un vrai téléphone** : ressenti des vibrations (amplitude, durée, intensité des
  moteurs variables), bouton retour réel (3 boutons ET navigation par gestes), lisibilité de la taille
  de l'arène, performances. Le retour est testé en envoyant la même notification que Godot.
- La vibration dépend aussi des réglages du téléphone (vibration coupée, ne pas déranger).

## 5. Simulation d'équilibrage (indicatif)
- Le bot **ne joue pas comme vous**. Sans soin, il meurt vers **55 s (vague 5)**, quelle que soit la
  politique d'achat : à ce stade il ne dit rien de la difficulté humaine ; il confirme seulement que
  ~50 pièces sont gagnées en ~55 s (premier achat vers 14 s).
- Mode `--god 1` (joueur soigné, dégâts comptés) — progression à long terme, 600 s :
  sans achat : vague ~19, 1 boss vaincu ; en améliorant : vague ~28, 2 boss vaincus, **les 4 tourelles
  au niveau 10 vers 600 s (~6 800 pièces)**. Premier achat ~14 s, puis un toutes les 15-25 s au début :
  rythme régulier. Pièces cumulées ≫ coûts après le maximum : la méta-progression (phase 7) devra
  les absorber.
- Détail : `reports/balance_runs.csv` et `_timeline.csv` (artefact de la CI).
- Choix provisoires issus de ces mesures : multiplicateur de coût 1,5 → 1,6 (tourelles au maximum
  plus tard), niveau maximal des ennemis 12 → 20 (sinon la difficulté plafonne à la vague ~34).

## 6. Écarts au plan et points d'attention
- Autoloads : `UIManager` et `Haptics` s'ajoutent à `EventBus` (3). Avec GameManager, SaveManager,
  AudioManager et AdManager prévus, on dépasserait les 6 du plan : `Haptics` pourra fusionner avec
  l'audio en un gestionnaire de retours (phase 5).
- Niveaux de tourelles générés par courbes (`TurretData`) plutôt que 40 lignes écrites à la main ;
  `TurretData.levels` permet de remplacer la table entière.
- `user://settings.cfg` (vibrations, mode d'amélioration) est provisoire : la phase 7 le reprendra
  dans `SaveManager` (versionnage, migrations).
- Matériaux ennemis : un par (type, teinte, état), partagés ; à remplacer par un paramètre de shader
  en phase 4 (budget « une douzaine de matériaux »).
- Une charge de boss trop lointaine est impossible (portée = vitesse × durée) : il poursuit alors.
- Le panneau d'amélioration occupe le bas de l'écran (≈ 39 %) : en modes « ralenti » et « aucune
  pause » il cache le bas de l'arène.

## 7. À tester sur téléphone (liste)
1. Vibrations : sentez-vous contact, coup reçu, mort, boss ? Trop fortes/faibles ? Testez les quatre
   niveaux du menu pause. Pas de vibration du tout : vérifiez les réglages du téléphone.
2. Retour : en jeu, en pause, panneau ouvert, défaite, accueil (double pression), boutons ET gestes.
3. Taille de l'arène : lisibilité du joueur/ennemis ; ajustez `arena_radius`, `player_speed`.
4. Économie : rythme d'achat, coût des niveaux ; boss : durée du combat, lisibilité des télégraphes.
5. FPS avec 60 ennemis (overlay debug) ; indiquez le modèle du téléphone (décision D8).

## 8. Restant
Phase 4 (assets Blender), 5 (game feel, sons), 6 (interface complète), 7 (sauvegarde, records,
améliorations permanentes), 8 (publicités), 9 (optimisation sur appareil), 10 (livraison).
