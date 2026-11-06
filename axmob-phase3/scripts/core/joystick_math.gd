class_name JoystickMath
extends RefCounted
## Passe d'un décalage en pixels à un vecteur de commande (longueur 0..1)
## avec zone morte radiale reparamétrée (pas de saut à la sortie de la zone).


static func from_offset(offset: Vector2, radius: float, deadzone: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var magnitude: float = clampf(offset.length() / radius, 0.0, 1.0)
	if magnitude <= deadzone:
		return Vector2.ZERO
	var scaled: float = (magnitude - deadzone) / (1.0 - deadzone)
	return offset.normalized() * scaled
