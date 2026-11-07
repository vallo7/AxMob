class_name CostCurve
extends RefCounted
## Coût du passage du niveau n à n+1 : base × facteur × multiplicateur^(n-1) (cahier des charges).


static func cost(base: float, multiplier: float, level: int, scale: float = 1.0) -> int:
	return maxi(roundi(base * scale * pow(multiplier, float(maxi(level, 1) - 1))), 1)


## Coût cumulé pour passer du niveau 1 au niveau `to_level`.
static func total_to(base: float, multiplier: float, to_level: int, scale: float = 1.0) -> int:
	var sum: int = 0
	for n: int in range(1, to_level):
		sum += cost(base, multiplier, n, scale)
	return sum
