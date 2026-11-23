class_name SpellCatalog
extends Resource

@export var definitions: Array[SpellDefinition] = []
@export var ink_cost_per_character: float = 20.0
@export var multi_target_factor: float = 0.65

func get_by_id(id: StringName) -> SpellDefinition:
	for definition in definitions:
		if definition.id == id:
			return definition
	return null

func get_by_elements(elements: Array) -> SpellDefinition:
	var ordered: Array = elements.duplicate()
	ordered.sort()
	for definition in definitions:
		var candidate: Array = Array(definition.elements)
		candidate.sort()
		if candidate == ordered:
			return definition
	return null
