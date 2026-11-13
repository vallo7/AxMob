# AxMob — Phase 7 : progression, sauvegarde, et refonte du monde / de l'interface / du son

Version **0.7.0** · Godot 4.7.2 · captures dans `docs/phase7/` · tests : **9 676 vérifications, 0 échec**
(+ lint `gdformat`/`gdlint` propre, validation des assets 0 erreur).

## 1. Tâches réalisées

### Phase 7 proprement dite : progression et sauvegarde
- **Format de sauvegarde v2** : records d'une partie (pièces, éliminations), historique des 10 dernières
  parties, **somme de contrôle** (détecte un fichier tronqué ou altéré → repli automatique sur la copie
  `.bak`), migration v1 → v2 sans aucune perte (testée).
- **Point de reprise** : si l'application passe en arrière-plan en pleine partie puis est tuée par le
  système, les pièces non dépensées et les statistiques de la partie sont versées **une seule fois** au
  prochain lancement (message « Partie interrompue récupérée : +N pièces »). Avant : perdues.
- **Écran Statistiques** refait : RECORDS (vague, temps, pièces et éliminations en une partie), CUMULS,
  DERNIÈRES PARTIES (5 lignes).
- **Tests de persistance** (40 vérifications) : fermeture/redémarrage simulés, migration v1, fichier
  altéré, fichier tronqué, écriture interrompue (`.tmp` orphelin), tout invalide → valeurs par défaut,
  types invalides, historique borné, partie < 3 s non comptée, versement unique, point de reprise
  (récupération unique, supprimé en fin normale, ignoré s'il est altéré).
- **Équilibrage de la méta-progression** (simulateur, mode « immortel » 420 s) : voir §4.

### Refonte demandée
| Demande | Réalisation |
|---|---|
| Couleurs du logo | Interface entièrement recolorée (or / orange / rouge / pierre violette / bleu clair, contour brun comme le logo) ; palette des modèles 3D recolorée (acier → pierre violette, bois orangé, corail à la place du rose) ; ciel doré → indigo ; bannière bleue → pierre |
| Musique | **Nouvelle** : « Island Raid » (jeu, 118 BPM), « Kraken Rising » (boss, 132 BPM), « Golden Shore » (menu, 100 BPM). Ré mineur, batterie nette, basse synthé, cordes staccato, cuivres discrets, flûte. 3 couches qui entrent selon l'intensité ; mélodie clairsemée ; ~4 dB plus bas qu'avant |
| Effets sonores | **49 effets refaits** (plus de bulles/marimba/steel drum) : couches transitoire + corps + queue, hiérarchie par niveaux, 6 nouveaux (sortie de l'eau, du sable, clic enfoncé, pop, whoosh d'écran…) |
| Horizon | Ciel dégradé + soleil, mer lointaine qui se fond dans la brume, 6 îles lointaines, nuages qui dérivent (`HorizonBackdrop`) ; visible surtout dans le menu |
| Navigation fluide et fun | Boutons : écrasement + éclat + rebond élastique + balancement ; écrans : la feuille monte avec rebond, contenu en cascade, whoosh ; menu : entrée en cascade, JOUER qui bat, halo derrière le héros |
| Style cartoon | Contours bruns épais sur boutons/panneaux/icônes, textes avec contour + ombre portée, tuiles à grandes icônes |
| Menu principal | Réagencé « jeux mobiles à succès » : pièces à gauche, réglages à droite, logo, héros au centre, tuiles AMÉLIORATIONS (pastille = achat possible) / STATISTIQUES de part et d'autre, énorme bouton JOUER en bas |
| Icônes de haches | **Modèles 3D rendus** (`scripts/tools/render_icons.gd`) : haches et tourelles |
| Plus de limite d'arène | Toute l'île est l'arène (contour réel de la plage) ; bouée-rebord retirée ; ennemis sortent de l'**eau** (écume, gouttes) ou du **sable** (secousse, fissure, éclats) |
| Tailles / caméra | Système de tailles en mètres (`docs/SIZE_SYSTEM.md`, testé sur les vrais modèles) ; caméra plus proche, oblique (46°), focale 34°, qui suit le joueur |
| Curseur invisible | Le joystick n'apparaît que sous le pouce (fondu + rebond) et disparaît au relâchement |
| Boutons de tourelles | Bouton TOURELLES supprimé ; **4 boutons en bas** (modèle 3D, niveau, prix) : toucher = acheter, appui long = détails |
| Textes soignés | Palette de textes, contour/ombre unifiés, colonnes alignées dans les statistiques |
| Pas de chevauchement | Bloc du haut (PV / pièces / pause, vague / temps), barre du boss juste dessous, bannière au centre, barre des tourelles en bas ; le joystick ignore la barre |
| Barre de vie du boss | Dessinée **au-dessus** du HUD (ordre des nœuds) et placée sous son bloc |

## 2. Fichiers
Créés : `scripts/core/island_shape.gd`, `scripts/core/obstacles.gd`, `scripts/gameplay/horizon_backdrop.gd`,
`scripts/ui/turret_dock.gd`, `scripts/tools/render_icons.gd`, `assets/shaders/ax_{sky,far_sea,island_far}.gdshader`,
`assets/textures/clouds.png`, `assets/ui/icons/model_*.png`, `ui_src/{build_sky_art,build_palette,post_model_icons}.py`,
`scripts/tests/systems/test_phase7_{save,scale}.gd`, `docs/SIZE_SYSTEM.md`, `docs/PHASE7.md`, `docs/phase7/`.
Réécrits : `arena.gd`, `camera_fit.gd`, `main_menu.gd`, `floating_joystick.gd`, `audio_src/{instruments,music_defs,sfx_defs}.py`.
Modifiés : `game_config`, `feel_config`, `run_context`, `player_controller`, `enemy_manager`, `wave_manager`,
`enemy_juice`, `fx_manager`, `hud`, `boss_bar`, `ax_button`, `ax_screen`, `ui_art`, `stats_screen`, `save_data`,
`save_manager`, `sfx_catalog`, `game_audio`, ressources ennemis/boss/hache lourde, `build_ui_art.py`, `candy.py`,
`blender/source/lib/ax.py` (couleurs), tests des phases 3 à 5.
Supprimés (voir `_delete.txt`) : les anciens sons `enemy_spawn_*`.

## 3. Tests
Suite complète : 9 676 vérifications, 0 échec. Nouveaux : sauvegarde v2 (40), tailles (49), cadrage
(île, suivi, 4 tourelles visibles au centre aux formats 9:21 / 9:16 / 3:4), obstacles du décor
(hauts au nord, solides sur le sable), apparition mer/sable, juice d'apparition, dock des tourelles.
Rendu vérifié par captures logicielles (9:16 et 9:19,5) ; audio vérifié par mesures (niveaux, bandes de
fréquences, spectrogramme) — **pas à l'oreille**.

## 4. Équilibrage (simulateur, à confirmer sur téléphone)
- Bot sans habileté : meurt vers 50 s (vague 5), comme aux phases 3 et 5 → pas de régression.
- Mode « immortel » 420 s : sans achat, vague ~18 et ~1 900 pièces ; avec achats, vague 25, ~4 850 pièces,
  tourelles niveau 9-10, 2 boss ; ~0,5 ms par tick.
- Coûts permanents (niveau 0 → 1) : PV 60, puissance 80, cadence 80, pièces 100, vitesse 70 ; un run de
  ~60 pièces paie donc le premier achat en 1 à 2 parties ; tout maximiser coûte ~44 000 pièces (long terme).

## 5. Limites et points à vérifier sur téléphone
- **Musique et effets : jamais écoutés** (je n'ai pas d'oreilles). Les niveaux sont cohérents sur le
  papier ; dis-moi ce qui est trop fort, trop aigu, trop présent — les stems sont réglables dans
  `audio_src/music_defs.py` (colonne `render(..., rms)`).
- **Horizon** : l'inclinaison de jeu (46°) montre surtout de la mer au sommet de l'écran ; le ciel, le
  soleil, les îles et les nuages se voient pleinement dans le menu. Baisser l'inclinaison (`pitch_degrees`)
  les montrerait aussi en jeu, au prix d'une vue moins lisible.
- **Hitbox** : les ennemis ont été agrandis pour correspondre à leur apparence (crabe 0,8 → 1,1 m,
  boss 2,6 → 3,6 m) : la sensation de jeu change légèrement ; le bot n'en souffre pas, mais seul un
  joueur humain peut valider.
- Le joystick invisible, l'achat rapide et l'appui long sont à essayer au pouce.
- Point de reprise : testé par simulation de redémarrage, **pas** avec un vrai kill Android.
- RÉANIMER (pub récompensée) toujours absent : phase 8.
- Le modèle `arena_beach.glb` contient encore la bouée-rebord (retirée à l'exécution) : à nettoyer dans
  Blender si tu veux alléger le modèle.
- Sons Android : toujours à vérifier sur appareil (latence, mixage sur haut-parleur de téléphone : les
  graves sous 150 Hz y sont peu audibles).

## 6. Tâches restantes
Phase 8 (publicités AdMob, RÉANIMER, consentement UMP), phase 9 (optimisation sur appareil réel, 60 FPS),
phase 10 (livraison). Pour la phase 8 : spike AdMob (compatibilité Godot 4.7.2) toujours à faire.
