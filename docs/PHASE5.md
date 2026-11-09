# AxMob — Phase 5 : game feel, son, caméra, performance (rapport)

Godot 4.7.2 · 8 945 assertions ok (7 543 en phase 4) · lint/format propres · 0 erreur de budget d'assets
· **non testé sur téléphone, et je n'ai écouté aucun son** (je n'ai ni appareil, ni GPU, ni oreilles :
tout rendu ci-dessous est logiciel, les FPS mesurés ici ne signifient rien ; le son a été vérifié par
des mesures, pas à l'écoute). Voir §9 pour la liste honnête de ce qui reste à valider par toi.

Planches de contrôle : `docs/phase5/` — `camera_avant_apres.png`, `hache_lourde_zone.png`,
`modele_heros_arrondi.png`, `modele_crabe_arrondi.png`, `sons_spectrogrammes.png`, `rapport_audio.md`.

## 1. Ce que tu as demandé → ce qui est fait

| Demande | Réalisation |
|---|---|
| Animations plus dynamiques et fun (mobs, haches) | Couche d'animation **procédurale** par ennemi (§3) + vol des haches vivant (§2) |
| La grosse hache fait des dégâts de zone | Rayon 3,4 m (4,4 m au niveau 10), dégâts décroissants, repoussement, onde de choc (§2) |
| Dégâts des haches augmentés | **+40 %** sur les 4 haches (§2) |
| Sound design professionnel | 82 fichiers synthétisés, 3 morceaux adaptatifs, ambiance, mixage à bus (§5) |
| Caméra plus dynamique + plus en plongée | 70° → **60°**, 8 comportements dynamiques, secousses, hit-stop (§4) |
| S10e + tous les téléphones, qualité optimale | Profils Bas/Moyen/Élevé, gouverneur automatique, rendu 3D adaptatif (§6) |
| Système de fluidité (animations, effets, graphismes) | Interpolation physique, 6 appels de dessin pour tous les effets, shaders sans coût CPU, réchauffage (§6) |
| Textures plus lisses, graphismes plus ronds et fun | Palette sans grain, sable lissé, éclairage adouci, formes arrondies (§7) |

## 2. Haches : dégâts, zone, animation

**Dégâts** (`resources/turrets/*.tres`) : rapide 8 → 11 · multiple 9 → 12,5 · perforante 14 → 20 ·
lourde 40 → 56. Simulateur d'équilibrage (4 parties × 240 s, mêmes graines, bot qui ne manœuvre pas) :
éliminations +3 % / +19 %, pièces +10 % / +34 %, ennemis simultanés à l'écran 8,2 → 6,0 (ils meurent
plus vite). **Ce n'est PAS un équilibrage validé** : le bot ne ressemble pas à un joueur ; c'est à
toi de dire si le jeu est devenu trop facile.

**Zone de la hache lourde** (`ProjectileData.splash_*`, `EventBus.axe_splash`) :
- le touché en direct prend les dégâts pleins (jamais frappé deux fois) ;
- les voisins dans le rayon prennent 80 % des dégâts au centre → 45 % au bord (décroissance
  linéaire), puis la résistance de l'ennemi s'applique ; repoussés du centre ;
- rayon 3,4 m, ×1,03 par niveau (**4,4 m** au niveau 10) ; le panneau d'amélioration affiche « Zone » ;
- une élimination par la zone rapporte sa récompense **une seule fois** ; les morts/invulnérables sont ignorés.

**Animation du vol** (`ProjectileManager`) : apparition « pop » élastique à la bouche, oscillation
propre à chaque hache, petit saut du lancer (la lourde : 1,5 m), coup d'échelle à chaque impact,
**flux lumineux** par hache (un seul MultiMesh pour toutes). Chaque catégorie a son style dans son
`.tres` (couleur de traînée, longueur, oscillation…).

## 3. Mobs : animation procédurale (`EnemyJuice` + `resources/enemies/juice_*.tres`)

Appliquée au modèle PAR-DESSUS les clips Blender, réglable sans code, un profil par type :
rebonds avec **écrasement/étirement** (volume conservé), balancement, penchement, respiration à
l'arrêt, **apparition** élastique (saut hors du sable + tour sur soi), **anticipation** avant le coup
(accroupissement puis élan vers l'avant), **réaction à l'impact** (écrasement + inclinaison dans le sens
du coup, qui retombe), **mort stylée** (crabe : gonfle et éclate · crevette : vrille 3 tours ·
tortue : s'aplatit · poisson-globe : éclate en tournant · kraken : tremble et s'enfonce). Le héros
reçoit aussi rebond de course, penchement, respiration, écrasement au coup ; les tourelles s'écrasent
au tir (plus fort pour la lourde). **Limite** : je n'ai pas re-animé les clips Blender eux-mêmes ;
tout le « fun » nouveau est dans cette couche procédurale (plus simple à régler sur téléphone).

## 4. Caméra (`CameraRig`, `CameraFit`, `FeelConfig`)

- **60°** au lieu de 70° (`pitch_degrees`). Comme la perspective agrandit le bas de l'arène quand la vue
  est oblique, la distance n'est plus « à largeur fixe » mais **calculée** (`CameraFit`) pour que
  l'arène ET les 4 tourelles tiennent dans l'écran au pire cas : 92,5 % de la demi-largeur, écrans
  9:21 à 3:4 (test automatique).
- Dynamique : anticipation du déplacement (0,35 s), **inclinaison latérale** 1,6° en courant, élévation
  −1,8° à pleine vitesse, dé-zoom léger quand la foule se resserre, **coups de zoom à ressort**
  (combat, impact de zone, coup subi) et poussée directionnelle, **secousses** (amplitude = trauma²)
  réservées aux gros événements (coup subi, zone, onde du boss, mort du boss), bornées.
- **Arrêt sur image** 40 ms sur une zone touchant ≥ 2 ennemis (1 fois / 0,35 s max) ; mort du boss :
  100 ms + ralenti 0,9 s à 35 % ; mort du héros : ralenti. Tout se coupe (`hitstop_*`, `shake_scale = 0`
  pour l'accessibilité).
- Le cadrage reste testé : `cadrage : largeur pire cas 0.925, hauteur pire cas 0.568`.

## 5. Son (`audio_src/` → `assets/audio/`, `AudioManager`, `GameAudio`)

**Tout est synthétisé par du code** (NumPy/SciPy, graines fixes → reproductible, aucune licence, tout
remplaçable). Techniques : couches transitoire + corps + queue, synthèse modale (bois, métal, coques),
FM pour les cloches, balayages de hauteur et de filtre, craquements poissonniens, réverbération par
convolution, saturation douce, fondus anti-clic. Sons tonals accordés en **do majeur pentatonique**
pour s'accorder avec la musique.

- **45 effets, 82 fichiers** (PCM 16 bits mono, ~3 Mo) : 4 lancers + 4 impacts de haches ; 5 « matières »
  d'ennemis (coque, mou, creux, bulle, kraken) × impact et mort ; zone lourde ; boss (avertissement,
  rugissement, charge, onde, phase, mort) ; apparition, armement ; **pièces en gamme montante**
  (la hauteur monte avec la série) ; série d'éliminations ; vague (début/fin), défaite, amélioration ;
  héros (coup, mort, pas dans le sable) ; interface.
- **Musique originale**, 3 morceaux de plage : « Sunny Chase » (jeu, 112 BPM, do majeur), « Kraken Rumble »
  (boss, 126 BPM, la mineur), « Lagoon » (menu, 96 BPM). Jeu et boss = **3 couches synchronisées**
  (rythme / harmonie / mélodie, `AudioStreamSynchronized`) : le rythme joue toujours, l'harmonie entre
  quand tu déclenches le combat (et reste 5 s), la mélodie quand la foule grossit ou après la vague 3.
  Boucles sans couture (la queue de réverbération est repliée sur le début).
- **Ambiance** de plage en boucle (mer, écume, vent, 3 mouettes discrètes).
- **Mixage** : bus Music / SFX / UI / Ambience → Master (limiteur dur −0,8 dB) ; SFX = compresseur +
  « air » ; 5 sous-bus de **panoramique** (un son se place dans le champ stéréo selon sa position) ;
  atténuation avec la distance ; **polyphonie** limitée par profil de qualité avec priorités (l'alerte
  de dégâts n'est jamais perdue) ; rotation des variantes sans répétition + variation de hauteur ;
  délai minimal et nombre max d'instances par son ; **ducking** de la musique sous les gros impacts ;
  musique étouffée (passe-bas) en pause. Menu pause : bouton « SON » (musique+effets / effets / silence).
- **Vérifié** : aucun écrêtage, pas de composante continue, couches de même durée (à 10 ms), boucles
  sans saut, tous les fichiers du catalogue présents et aucun orphelin (test), spectrogrammes
  cohérents (`docs/phase5/sons_spectrogrammes.png`), niveaux dans `rapport_audio.md`.
- **Non vérifié : l'écoute.** Je ne peux pas juger si c'est « agréable ». Une synthèse par code atteint
  vite ses limites (voix, textures organiques) ; je l'ai poussée au maximum mais, si tu veux un rendu
  de studio, il faudra un sound designer. Chaque son est remplaçable en gardant son nom de fichier.

## 6. Performance et fluidité

**Effets : 6 appels de dessin pour TOUS** (étincelles, fumées, anneaux, pièces, ombres, flux de haches). Les particules sont des **instances de MultiMesh dont le mouvement est calculé dans le shader**
à partir de l'instant de naissance : le CPU écrit une fois par particule (à l'émission) puis n'y touche
plus ; plafonds de pool par profil, au plafond la plus ancienne est recyclée (zéro allocation en jeu).
Les **fausses ombres** (taches douces) ancrent les personnages au sol pour presque rien.

**Profils** (`QualityProfile`) — rien ne change le gameplay (ni ennemis, ni dégâts) :

| | Bas | Moyen | Élevé |
|---|---|---|---|
| Rendu 3D (méga-pixels) | 0,95 | 1,45 | 2,1 |
| → S10e 1080×2280 | 62 % | 77 % | 92 % |
| Anticrénelage MSAA | non | non | 2× |
| Densité d'effets / ombres | 0,45 / non | 0,75 / oui | 1,0 / oui |
| Animation des ennemis lointains | 1 tick sur 3 > 9 m | 1/2 > 12 m | 1/2 > 14 m |
| Détail de la mer | aplat | + reflets | + vagues |
| Sons simultanés | 12 | 16 | 20 |

L'interface reste dessinée en **résolution native** (seule la 3D est réduite).

**Gouverneur** (`QualityGovernor`, logique pure, testée avec des durées simulées) : descend vite (2 fenêtres
de 2,5 s trop lentes, ou 1 très lente), **monte prudemment** (12 s sans raté, puis *sonde* le profil du
dessus ; si la sonde échoue, retour + plafond pour la session, donc pas de yo-yo), ignore les images >
250 ms (chargement), mémorise le dernier profil stable. Premier lancement : Moyen, puis Élevé si stable.
Menu pause : « QUALITÉ : AUTO / BAS / MOYEN / ÉLEVÉ ». L'overlay debug affiche FPS, ms CPU, profil, échelle 3D.

**Fluidité** : **interpolation physique** du moteur activée (la simulation à 60 Hz est lissée à
l'affichage : sans saccade de battement sur 60/90/120 Hz), jitter fix coupé, rattrapage limité à 4 pas
(ralenti plutôt que spirale), horloge des effets interpolée aussi, **réchauffage du rendu** (modèles et
shaders envoyés au GPU avant le premier ennemi : pas de micro-saccade à la première apparition).

**Mesures (CPU serveur, headless, informatif)** : 60 ennemis = 1,8 ms/tick (2,6 en phase 4 sur une autre
exécution : bruit machine) ; grille 400 ennemis ≈ 1,0 ms. **Le coût GPU réel sur le S10e est inconnu.**

## 7. Style : plus lisse, plus rond, plus fun

Palette : plus de grain, dégradé adouci, +7 % de saturation ; sable : plus de grain ni de cailloux,
ondulations réduites, flou final ; shader : courbe de lumière adoucie ; normales lissées jusqu'à 66°
(38° avant) ; yeux/articulations/pinces à 10×6 facettes (au lieu de 8×4) ; boîtes visibles chanfreinées.
Coût : +10 à +25 % de triangles → **budgets révisés** (héros 3 600, crabe 1 650, crevette 1 300,
parasol 450 ; justifié dans `assets/budgets.json`), 0 erreur. Je n'ai pas fait de sculpture manuelle
(limite de la phase 4 inchangée) : si le résultat n'est pas assez rond à ton goût, donne-moi
les pièces à arrondir.

## 8. Fichiers

**Nouveaux** : `scripts/fx/` (FxManager, FxBatch, BlobShadows, TrailBatch) · `scripts/perf/` (QualityProfile,
QualityGovernor, QualityManager) · `scripts/audio/` (AudioManager, SfxCatalog, GameAudio) ·
`scripts/gameplay/{camera_fit,feel_director}.gd` · `scripts/enemies/enemy_juice.gd` ·
`scripts/resources/{feel_config,juice_profile}.gd` · `resources/balancing/feel_config.tres` ·
`resources/enemies/juice_*.tres` · 8 shaders `assets/shaders/ax_fx_*`, `ax_vignette` · `audio_src/` (6 scripts
Python) · `assets/audio/` (82 WAV, 8 OGG) · `scripts/tools/fx_showcase.gd` · `.github/workflows/audio-export.yml` ·
tests `test_phase5*.gd`.
**Modifiés** : camera_rig, projectile_manager, enemy_manager, enemy, turret, player_controller, hud, pause_menu,
gameplay (+ scène), arena, event_bus, user_settings, data_registry, ui_kit, boot, ax_toon/ax_ocean, scripts Blender
(`lib/ax.py`, `arena_beach.py`, `decor.py`), tous les `.glb` et textures régénérés, `project.godot`
(interpolation physique, autoloads QualityManager et AudioManager), ci.yml, README.

## 9. Ce que je n'ai PAS pu vérifier — à tester sur ton S10e

Je ne peux pas : lancer sur un téléphone, mesurer le GPU, écouter, juger la sensation. Installe l'APK debug
(GitHub Actions) et dis-moi :
1. **Fluidité** : l'overlay (en haut à gauche) montre-t-il ~60 FPS en grande vague ? Quel profil choisit
   « AUTO » après 20 s ? Une saccade au changement de profil ? Chauffe du téléphone après 10 min ?
2. **Caméra** : 60° te convient ? (plus bas = `pitch_degrees`, ex. 55). Secousses/zoom trop forts
   (`shake_scale`, `punch_*`) ? Inclinaison latérale gênante (`bank_degrees = 0`) ?
3. **Arrêt sur image** de 40 ms sur la zone : agréable ou « hachure » (`hitstop_splash = 0`) ?
4. **Son** : niveaux relatifs (musique vs effets vs pièces), sons agaçants ou trop répétitifs, musique
   adaptative (l'harmonie entre-t-elle bien au premier contact ?), basses sur les haut-parleurs du téléphone.
5. **Équilibre** : +40 % de dégâts + zone, trop facile ? (dégâts dans `resources/turrets/*.tres`).
6. **Style** : assez rond/lisse/fun ? Effets trop chargés (`fx_scale`) ou trop discrets ?

## 10. Restant / limites

- Menu principal et réglages complets (volumes séparés musique/effets, curseurs) : **phase 6** ; en attendant,
  boutons dans le menu pause. Le menu actuel (placeholder) joue déjà « Lagoon ».
- Pas de nombres de dégâts flottants, pas de post-traitement (bloom) : volontairement, pour le coût GPU.
- Clips Blender non ré-animés (§3). Réglages `FeelConfig` = hypothèses à régler au toucher.
- Le gouverneur ne mesure que les durées d'image (le moteur Compatibility n'expose pas le temps GPU).
- Android : non testé ; la nouvelle dépendance `AudioStreamSynchronized` et l'interpolation physique des
  MultiMesh (Godot ≥ 4.3) sont couvertes par les tests headless, pas par un appareil.
