class_name LocStrings
extends RefCounted
## Textes de l'interface (clé -> {fr, en}). Généré à la main : un test vérifie que chaque clé a les
## deux
## langues et que chaque clé utilisée dans le code existe.

const STRINGS: Dictionary = {
	"tur_name_rapid": {"fr": "Rapide", "en": "Rapid"},
	"tur_name_heavy": {"fr": "Lourde", "en": "Heavy"},
	"tur_name_multi": {"fr": "Multiple", "en": "Multi"},
	"tur_name_pierce": {"fr": "Perforante", "en": "Piercing"},
	"load_assets": {"fr": "Chargement des ressources", "en": "Loading resources"},
	"load_scene": {"fr": "Construction de la scène", "en": "Building the scene"},
	"load_warm": {"fr": "Préparation des effets", "en": "Preparing effects"},
	"play": {"fr": "JOUER", "en": "PLAY"},
	"upgrades": {"fr": "AMÉLIORATIONS", "en": "UPGRADES"},
	"settings": {"fr": "RÉGLAGES", "en": "SETTINGS"},
	"statistics": {"fr": "STATISTIQUES", "en": "STATISTICS"},
	"close": {"fr": "FERMER", "en": "CLOSE"},
	"back": {"fr": "RETOUR", "en": "BACK"},
	"resume": {"fr": "REPRENDRE", "en": "RESUME"},
	"restart": {"fr": "RECOMMENCER", "en": "RESTART"},
	"main_menu": {"fr": "MENU PRINCIPAL", "en": "MAIN MENU"},
	"quit_hint": {"fr": "Appuyez encore pour quitter", "en": "Press again to quit"},
	"unit_hp": {"fr": "PV", "en": "HP"},
	"on": {"fr": "OUI", "en": "ON"},
	"off": {"fr": "NON", "en": "OFF"},
	"max": {"fr": "MAX", "en": "MAX"},
	"level_of": {"fr": "Niv. %d / %d", "en": "Lv. %d / %d"},
	"not_enough": {"fr": "Pièces insuffisantes", "en": "Not enough coins"},
	"max_level": {"fr": "Niveau maximal", "en": "Max level"},
	"loading": {"fr": "CHARGEMENT", "en": "LOADING"},
	"loading_failed": {"fr": "Chargement impossible", "en": "Loading failed"},
	"retry": {"fr": "RÉESSAYER", "en": "RETRY"},
	"best_wave": {"fr": "Record : vague %d", "en": "Best: wave %d"},
	"wallet": {"fr": "Pièces", "en": "Coins"},
	"menu_tap_hint": {"fr": "Appuie sur JOUER !", "en": "Tap PLAY!"},
	"perm_hp_name": {"fr": "Points de vie", "en": "Hit points"},
	"perm_hp_desc": {"fr": "PV maximum du héros", "en": "Maximum hero HP"},
	"perm_power_name": {"fr": "Puissance", "en": "Power"},
	"perm_power_desc":
	{"fr": "Dégâts des tourelles dès le départ", "en": "Turret damage from the start"},
	"perm_rate_name": {"fr": "Cadence", "en": "Fire rate"},
	"perm_rate_desc": {"fr": "Cadence de tir des tourelles", "en": "Turret fire rate"},
	"perm_coins_name": {"fr": "Bonus de pièces", "en": "Coin bonus"},
	"perm_coins_desc": {"fr": "Plus de pièces par ennemi", "en": "More coins per enemy"},
	"perm_speed_name": {"fr": "Vitesse", "en": "Speed"},
	"perm_speed_desc": {"fr": "Le héros court plus vite", "en": "The hero runs faster"},
	"buy": {"fr": "AMÉLIORER", "en": "UPGRADE"},
	"now_next": {"fr": "%s  →  %s", "en": "%s  →  %s"},
	"stat_best_time": {"fr": "Meilleur temps", "en": "Best time"},
	"stat_best_wave": {"fr": "Meilleure vague", "en": "Best wave"},
	"stat_kills": {"fr": "Ennemis éliminés", "en": "Enemies defeated"},
	"stat_coins": {"fr": "Pièces gagnées", "en": "Coins earned"},
	"stat_bosses": {"fr": "Boss vaincus", "en": "Bosses defeated"},
	"stat_games": {"fr": "Parties jouées", "en": "Games played"},
	"stat_playtime": {"fr": "Temps de jeu", "en": "Play time"},
	"set_music": {"fr": "Musique", "en": "Music"},
	"set_sfx": {"fr": "Effets sonores", "en": "Sound effects"},
	"set_music_vol": {"fr": "Volume de la musique", "en": "Music volume"},
	"set_sfx_vol": {"fr": "Volume des effets", "en": "Effects volume"},
	"set_joystick": {"fr": "Sensibilité du joystick", "en": "Joystick sensitivity"},
	"set_graphics": {"fr": "Qualité graphique", "en": "Graphics quality"},
	"set_haptics": {"fr": "Vibrations", "en": "Vibration"},
	"set_upgrade_pause": {"fr": "Jeu pendant les améliorations", "en": "Game while upgrading"},
	"set_language": {"fr": "Langue", "en": "Language"},
	"set_report": {"fr": "COPIER LE RAPPORT TECHNIQUE", "en": "COPY TECHNICAL REPORT"},
	"set_report_done": {"fr": "Rapport copié", "en": "Report copied"},
	"set_test_vibration": {"fr": "TESTER LA VIBRATION", "en": "TEST VIBRATION"},
	"quality_AUTO": {"fr": "AUTO", "en": "AUTO"},
	"quality_LOW": {"fr": "BAS", "en": "LOW"},
	"quality_MEDIUM": {"fr": "MOYEN", "en": "MEDIUM"},
	"quality_HIGH": {"fr": "ÉLEVÉ", "en": "HIGH"},
	"quality_locked":
	{
		"fr":
		"ÉLEVÉ désactivé après un plantage. Nouvel essai automatique après quelques lancements stables.",
		"en":
		"HIGH was disabled after a crash. It will be retried automatically after a few stable launches."
	},
	"quality_note": {"fr": "Profil actuel : %s", "en": "Current profile: %s"},
	"crash_notice":
	{
		"fr": "Le jeu s'est fermé de façon inattendue : la qualité a été réduite.",
		"en": "The game closed unexpectedly: quality was reduced."
	},
	"haptics_0": {"fr": "Désactivées", "en": "Off"},
	"haptics_1": {"fr": "Légères", "en": "Light"},
	"haptics_2": {"fr": "Normales", "en": "Normal"},
	"haptics_3": {"fr": "Fortes", "en": "Strong"},
	"pause_mode_0": {"fr": "Arrêt total", "en": "Full stop"},
	"pause_mode_1": {"fr": "Ralenti", "en": "Slow motion"},
	"pause_mode_2": {"fr": "Aucune pause", "en": "No pause"},
	"sens_0": {"fr": "Très douce", "en": "Very low"},
	"sens_1": {"fr": "Douce", "en": "Low"},
	"sens_2": {"fr": "Normale", "en": "Normal"},
	"sens_3": {"fr": "Vive", "en": "High"},
	"sens_4": {"fr": "Très vive", "en": "Very high"},
	"pause_title": {"fr": "PAUSE", "en": "PAUSE"},
	"defeat": {"fr": "DÉFAITE", "en": "DEFEAT"},
	"new_record": {"fr": "NOUVEAU RECORD !", "en": "NEW RECORD!"},
	"res_wave": {"fr": "Vague atteinte", "en": "Wave reached"},
	"res_time": {"fr": "Temps de survie", "en": "Survival time"},
	"res_kills": {"fr": "Éliminations", "en": "Defeated"},
	"res_coins": {"fr": "Pièces gagnées", "en": "Coins earned"},
	"res_banked": {"fr": "Pièces conservées", "en": "Coins kept"},
	"play_again": {"fr": "REJOUER", "en": "PLAY AGAIN"},
	"revive": {"fr": "RÉANIMER", "en": "REVIVE"},
	"wave_fmt": {"fr": "VAGUE %d", "en": "WAVE %d"},
	"boss_alert": {"fr": "BOSS !", "en": "BOSS!"},
	"phase_fmt": {"fr": "PHASE %d", "en": "PHASE %d"},
	"boss_down": {"fr": "BOSS VAINCU", "en": "BOSS DEFEATED"},
	"turrets": {"fr": "TOURELLES", "en": "TURRETS"},
	"boss_bar": {"fr": "%s  ·  PHASE %d", "en": "%s  ·  PHASE %d"},
	"tur_level": {"fr": "NIV %d/%d", "en": "LV %d/%d"},
	"tur_max": {"fr": "NIVEAU MAX", "en": "MAX LEVEL"},
	"tur_upgrade": {"fr": "AMÉLIORER", "en": "UPGRADE"},
	"st_damage": {"fr": "Dégâts", "en": "Damage"},
	"st_rate": {"fr": "Cadence", "en": "Fire rate"},
	"st_range": {"fr": "Portée", "en": "Range"},
	"st_axes": {"fr": "Haches", "en": "Axes"},
	"st_zone": {"fr": "Zone", "en": "Area"},
	"st_pierce": {"fr": "Perforation", "en": "Pierce"},
	"coins_fmt": {"fr": "%d pièces", "en": "%d coins"},
	"tip_1":
	{
		"fr": "Frôle les ennemis : c'est le contact qui déclenche les tourelles !",
		"en": "Brush past enemies: contact is what fires the turrets!"
	},
	"tip_2":
	{
		"fr": "Regroupe les ennemis pour que la hache perforante les traverse tous.",
		"en": "Bunch enemies up so the piercing axe goes through them all."
	},
	"tip_3":
	{
		"fr": "La hache lourde fait des dégâts de zone : vise les groupes.",
		"en": "The heavy axe deals area damage: aim for crowds."
	},
	"tip_4":
	{
		"fr": "Les pièces non dépensées sont conservées pour les améliorations permanentes.",
		"en": "Unspent coins are kept for permanent upgrades."
	},
	"tip_5":
	{
		"fr": "Un boss arrive toutes les 10 vagues : garde de la place pour esquiver !",
		"en": "A boss arrives every 10 waves: keep room to dodge!"
	},
	"tip_6":
	{
		"fr": "Ne reste jamais collé au bord : tu pourrais te faire encercler.",
		"en": "Never hug the edge: you could get surrounded."
	},
	"tip_7":
	{
		"fr": "Améliore les tourelles régulièrement, mais pense aussi à épargner.",
		"en": "Upgrade turrets regularly, but remember to save some coins."
	},
	"tip_8":
	{
		"fr": "Quand les PV sont bas, l'écran pulse : il est temps de reculer !",
		"en": "When HP is low the screen pulses: time to back off!"
	},
}
