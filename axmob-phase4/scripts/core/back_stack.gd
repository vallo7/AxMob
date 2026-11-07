class_name BackStack
extends RefCounted
## Pile de gestionnaires du bouton retour. Le dernier écran ouvert répond en premier ; un
## gestionnaire retourne vrai s'il a consommé l'événement, sinon le suivant est interrogé.
## Logique pure (testable sans moteur) : UIManager y branche la notification Android.

var _owners: Array[Object] = []
var _handlers: Array[Callable] = []


func push(owner: Object, handler: Callable) -> void:
	remove(owner)
	_owners.append(owner)
	_handlers.append(handler)


## Retire le gestionnaire d'un propriétaire (sans effet s'il n'y en a pas).
func remove(owner: Object) -> void:
	var i: int = _owners.find(owner)
	if i >= 0:
		_owners.remove_at(i)
		_handlers.remove_at(i)


func size() -> int:
	return _owners.size()


func has(owner: Object) -> bool:
	return _owners.has(owner)


## Interroge du haut vers le bas ; retourne vrai si quelqu'un a consommé le retour.
## Les propriétaires détruits sont purgés au passage.
func dispatch() -> bool:
	var i: int = _owners.size() - 1
	while i >= 0:
		if i >= _owners.size():
			i = _owners.size() - 1
			continue
		if not is_instance_valid(_owners[i]) or not _handlers[i].is_valid():
			_owners.remove_at(i)
			_handlers.remove_at(i)
		elif _handlers[i].call() as bool:
			return true
		i -= 1
	return false
