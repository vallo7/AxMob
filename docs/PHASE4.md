# AxMob — Phase 4 : assets Blender, décor « plage », vibrations (rapport)

Godot 4.7.2 · Blender 5.2 (module `bpy`, headless) · 7 543 assertions ok · 0 erreur de budget d'assets
· **non testé sur téléphone** (je n'ai pas de rendu GPU ni d'appareil : tout rendu ci-dessous est
logiciel, les FPS mesurés ici ne signifient rien).

Planches de contrôle : `docs/phase4/` (`personnages`, `personnages_vue_jeu`, `animations`, `tourelles`,
`haches`, `decor`) et captures du jeu (`jeu_*.png`).

## 1. Vibrations : ce que j'ai trouvé, ce que j'ai fait, ce que je ne sais pas

**Diagnostic.** J'ai relu dans le code source de Godot (version 4.5, la 4.7.2 n'étant pas récupérable
dans mon environnement) le chemin complet `Input.vibrate_handheld` → Android : il est correct. La
permission `VIBRATE` est « normale » (accordée d'office si présente dans l'APK) et le moteur envoie
bien une impulsion à `Vibrator`. En revanche **les motifs de la phase 3 étaient trop faibles pour
être sentis** : impulsions de 15 à 40 ms à 30–60 % d'amplitude (le tap de bouton : 15 ms à 35 %).
Beaucoup de moteurs de téléphone ne rendent rien en dessous de ~25 ms.

**Ce que je ne peux pas exclure** : que l'APK testé ait été construit avant l'ajout de la permission
(phase 3), ou un réglage du téléphone (« vibration au toucher » coupée, mode silencieux).

**Corrections**
- Tous les motifs : impulsions ≥ 25 ms et amplitude ≥ 0,5 ; durée minimale 15 → 28 ms ; plafond cumulé
  1 600 → 2 200 ms / 5 s. Test de non-régression : aucun motif ne retombe sous ces seuils, même au
  niveau « Légères ».
- **Retour haptique sur tous les boutons**, présents et futurs (menus de la phase 6) : un hook global
  dans l'autoload `Haptics` ; un bouton inactif donne le motif « refus ». Avant, seuls les boutons
  fabriqués par `UiKit.button` vibraient.
- **Menu pause → « TESTER LA VIBRATION »** : 300 ms à pleine puissance, hors réglages. Si le téléphone
  ne vibre pas ici, le problème n'est pas dans les motifs ; le message affiche aussi le nombre d'appels
  envoyés au moteur.
- **CI** : `build-android.yml` lit désormais les permissions DANS l'APK (`aapt2 dump permissions`) et
  **échoue si `VIBRATE` manque** ; le fichier est publié avec l'APK.
- En cas d'échec persistant : `adb logcat | grep -i vibrat` (Godot journalise l'absence de permission).

## 2. Direction artistique : plage, fun, hyper casual

- **Un seul matériau pour tout le jeu** : atlas `assets/textures/palette.png` (8×8 couleurs, dégradé
  vertical par cellule = faux éclairage ambiant, grain léger) + shader `ax_toon.gdshader` (demi-Lambert
  enveloppé, liseré de lumière). Les variations passent par des *instance uniforms* (teinte de niveau,
  flash d'impact, armement, lueur) : **aucun nouveau matériau**, batching préservé. Vérifié en rendu
  Compatibility.
- Chaque modèle est un **maillage unique skinné** (personnages : un appel de dessin) construit pièce
  par pièce en Python/`bpy` (primitives paramétriques, boucles de révolution, tubes lofts, biseaux),
  liées à des os-pivots. Aucun modèle de banque d'assets. **Limite assumée** : pas de sculpture
  manuelle ; le style (formes rondes, aplats, dégradés) s'y prête. Les `.blend` et les scripts sont
  livrés pour qu'un artiste raffine n'importe quoi.
- Textures : le sable de l'île est peint procéduralement (`assets/textures/sand.png`, 1024², rides,
  sable mouillé, festons d'écume, grain).

## 3. Modèles livrés

| Asset | Triangles | Os | Animations |
|---|---|---|---|
| `char_player` Vacancier (bob turquoise, lunettes) | 2 836 / 3 000 | 7 | idle, run, hit, death |
| `enemy_basic` Crabe rouge | 1 216 / 1 300 | 12 | idle, run, attack, hit, death |
| `enemy_fast` Crevette rose | 996 / 1 000 | 10 | idem |
| `enemy_heavy` Tortue (carapace hexagonale) | 1 674 / 2 500 | 8 | idem |
| `enemy_elite` Poisson-globe couronné | 1 180 / 2 500 | 7 | idem |
| `enemy_boss` Kraken (6 tentacules à 3 os) | 2 828 / 7 000 | 20 | + charge_windup, charge, roar |
| `turret_rapid` seau de sable, double canon | tous paliers 1 922 / 3 500 | – | – |
| `turret_heavy` tonneau, gros canon | 2 384 / 3 500 | – | – |
| `turret_multi` château de sable, éventail de canons | 1 744 / 3 500 | – | – |
| `turret_pierce` piédestal de pierre, défense de narval | 2 634 / 3 500 | – | – |
| `axe_light/heavy/multi/pierce` | 358 / 448 / 272 / 348 | – | (rotation par le jeu) |
| `arena_beach` île + bouée-rebord | 4 328 / 6 000 | – | – |
| `ocean` | 1 984 / 2 500 | – | shader `ax_ocean` |
| 10 décors (palmier, parasol, serviette, ballon, château, coquillage, étoile de mer, rocher, seau et pelle, planche de surf) | 104 à 1 210 | – | – |

Budgets (`assets/budgets.json`) = ceux du plan §6.2, sauf deux révisions assumées : crabe 1 200 → 1 300
et hache lourde 500 → 600 (cette dernière finalement à 448). Les 28 GLB pèsent 1,3 Mo au total.

Conventions : avant = +Y Blender (= −Z Godot), origine au sol, 1 unité = 1 m, tourelles =
`Base` fixe, `Pivot` (`Head`, `Barrel`>`Muzzle`, `Tier_2`, `Tier_3`), `Tier_1` sur la base.

## 4. Intégration dans le jeu

- `ModelRig` (`scripts/core/model_rig.gd`) : charge le GLB, applique le matériau, **fait avancer les
  animations à la main** au pas fixe (elles respectent donc pause et ralenti), retire la clé dupliquée
  ajoutée par l'export aux boucles, expose flash / teinte / lueur / alerte.
- **Ennemis** : un pool de modèles par type (préchauffé : 6 crabes, 5 crevettes, 3 tortues, 2 élites,
  1 boss). Animation choisie d'après l'état de simulation (poursuite → `run` à la vitesse réelle,
  armement → `attack` calée pour que la frappe tombe à la fin de l'armement, étourdissement → `hit`,
  mort → `death`, boss : `charge_windup`, `charge`, `roar` au changement de phase). Les durées de la
  simulation restent maîtresses. Au-delà de 14 m du joueur, l'animation n'avance qu'un tick sur deux.
  Teinte de niveau (4 paliers) = paramètre de shader. Agrandissement visuel (`visual_scale` dans
  `EnemyData`, crabe ×1,25…) pour la lisibilité ; les rayons de collision ne changent pas.
- **Joueur** : modèle animé (course calée sur la vitesse, `hit`, `death`), clignotement
  d'invulnérabilité conservé, héros agrandi ×1,2 (flèche blanche sur le chapeau = orientation vue de
  dessus).
- **Tourelles** : modèle par catégorie, paliers visibles aux niveaux 4/7/10, recul du canon, distance de
  bouche lue sur le modèle.
- **Haches** : un modèle par catégorie, créé à la demande dans l'emplacement du pool.
- **Arène** (`arena.gd`) : île de sable (échelle = `arena_radius / 13`), bouée rouge et blanche
  **interrompue aux quatre tourelles**, mer animée (shader : eau peu profonde → profonde, écume qui
  pulse au rivage, lignes de vagues), 20 objets de plage posés **hors de la zone de jeu** (test).
  Éclairage et ciel revus pour la plage.
- **Outils** : `scenes/tools/asset_preview.tscn` (planches de contrôle), `validate_assets.gd` étendu
  (triangles, taille, os, une surface par personnage, UV dans l'atlas, nœuds obligatoires, boucles, pose
  au sol).

## 5. Tests et vérifications

- 7 543 assertions ok. Nouveau : `test_phase4.gd` (modèles et animations par état, retour au pool,
  teinte = paramètre et non matériau, tourelles, haches, arène, héros) + 3 tests de vibration.
- Budgets : `validate_assets.gd` → 0 erreur sur les 28 assets.
- Rendu : captures de contrôle (`docs/phase4/jeu_*.png`), rendu logiciel.
- Charge : scénario de 60 ennemis simultanés 1,5–1,8 ms/tick CPU **serveur** (1,4 avant les modèles).

## 6. Limites et ce qui reste

- **Rien n'a été vu sur téléphone** : lisibilité réelle, FPS (60 ennemis skinnés + mer animée en
  Compatibility : à mesurer sur l'appareil plancher, **D8 toujours en attente du modèle de votre
  téléphone**), vibrations.
- L'animation d'un ennemi coûte un `AnimationPlayer` + un squelette de 7 à 20 os ; si le plancher
  décroche, les leviers sont : plafond d'ennemis, animation d'un tick sur deux plus tôt, passage du
  boss/élite seuls en squelette.
- Effets (particules, traînées, éclats de mort, pièces), sons et transitions : **Phase 5**. Le flash de
  bouche des tourelles est encore une sphère provisoire.
- Le menu principal 3D (héros en idle) viendra avec l'interface de la phase 6 ; le modèle et son
  animation `idle` sont prêts.
- `axe_light.py` (phase 0) est remplacé par `axes.py` (les quatre haches).
