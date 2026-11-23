extends Node2D
var unit_kind: UnitDefinition.Kind = UnitDefinition.Kind.DRAGON

var hp = 1000
var is_grabbed = false
var team = 2 
var grid_pos = Vector2i(3, 0) 
var occupied_cells = [] 
var current_attack_index = 0

func _ready():

	for x in range(3):
		for y in range(3):
			occupied_cells.append(grid_pos + Vector2i(x, y))


var active_buffs: Dictionary = {}

var immunities: Array = ["root", "frozen", "stun"] 

func add_buff(buff_name: String, duration: int):

	if buff_name in immunities:
		print("Boss Rồng gầm lên: Tao miễn nhiễm với ", buff_name)
		return
		

	if active_buffs.has(buff_name):
		active_buffs[buff_name] = max(active_buffs[buff_name], duration)
	else:
		active_buffs[buff_name] = duration
		
	if buff_name == "burn":
		modulate = Color(1, 0.5, 0.5)
