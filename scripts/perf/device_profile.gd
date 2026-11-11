class_name DeviceProfile
extends RefCounted
## Profil de départ selon l'appareil (premier lancement uniquement : ensuite le gouverneur et le
## dernier profil stable prennent le relais). Heuristiques PRUDENTES sur le nom du GPU et la
## mémoire : une erreur ici coûte au pire quelques secondes au mauvais profil avant correction.


## Profil initial conseillé. `ram_mb` <= 0 = inconnu.
static func suggest(adapter: String, ram_mb: int, pixels: int) -> QualityProfile.Tier:
	var gpu: String = adapter.to_lower()
	var tier: QualityProfile.Tier = QualityProfile.Tier.MEDIUM
	if _is_entry_gpu(gpu) or (ram_mb > 0 and ram_mb < 3000):
		tier = QualityProfile.Tier.LOW
	# Écran très défini + GPU de milieu de gamme : le coût des pixels domine, on reste prudent.
	elif pixels > 3_500_000 and not _is_flagship_gpu(gpu):
		tier = QualityProfile.Tier.MEDIUM
	return tier


static func _is_entry_gpu(gpu: String) -> bool:
	for key: String in [
		"mali-400",
		"mali-t",
		"mali-g31",
		"mali-g51",
		"mali-g52",
		"adreno (tm) 3",
		"adreno (tm) 4",
		"adreno (tm) 50",
		"adreno (tm) 51",
		"powervr",
		"sgx"
	]:
		if gpu.contains(key):
			return true
	return false


static func _is_flagship_gpu(gpu: String) -> bool:
	for key: String in [
		"mali-g7",
		"mali-g8",
		"mali-g9",
		"immortalis",
		"adreno (tm) 64",
		"adreno (tm) 65",
		"adreno (tm) 66",
		"adreno (tm) 7",
		"adreno (tm) 8",
		"apple"
	]:
		if gpu.contains(key):
			return true
	return false
