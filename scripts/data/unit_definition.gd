class_name UnitDefinition
extends Resource
## Shared immutable balance data. Runtime health, ammunition and buffs live on Piece.

enum Kind { SOLDIER, KING, KNIGHT, BISHOP, ROOK, QUEEN, EARTH_WALL, DRAGON }

@export var id: StringName = &"soldier"
@export var kind: Kind = Kind.SOLDIER
@export var max_health: int = 500
@export var melee_damage: float = 10.0
@export var ranged_damage: float = 0.0
@export var counter_damage: float = 10.0
@export var secondary_damage: float = 0.0
@export var impact_damage: int = 0
@export var self_impact_damage: int = 0
@export var attack_range: int = 1
@export var move_range: int = 1
@export var push_distance: int = 0
@export var retreat_distance: int = 0
@export var ammo_capacity: int = 3
@export var reload_turns: int = 2

static func is_kind(unit: Object, expected: Kind) -> bool:
	return is_instance_valid(unit) and unit.get("unit_kind") == expected
