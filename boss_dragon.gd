extends Node2D

var hp = 1000
var is_grabbed = false
var team = 2 
var grid_pos = Vector2i(3, 0) # Vị trí ô gốc (trên cùng bên trái)
var occupied_cells = [] # Danh sách các ô boss chiếm (VD: 3x3)
var current_attack_index = 0

func _ready():
	# Giả sử Boss 3x3 (9 ô)
	for x in range(3):
		for y in range(3):
			occupied_cells.append(grid_pos + Vector2i(x, y))
# Bên trong file boss_dragon.gd

var active_buffs: Dictionary = {}
# Boss Rồng to bự nên miễn nhiễm với các hiệu ứng khống chế (chỉ nhận sát thương burn)
var immunities: Array = ["root", "frozen", "stun"] 

func add_buff(buff_name: String, duration: int):
	# 1. BOSS CHECK: Nếu buff nằm trong danh sách miễn nhiễm thì văng ra luôn!
	if buff_name in immunities:
		print("Boss Rồng gầm lên: Tao miễn nhiễm với ", buff_name)
		return # KHÔNG cho phép add buff
		
	# 2. Nếu không kháng (ví dụ dính "burn"), thì nhận buff như bình thường
	if active_buffs.has(buff_name):
		active_buffs[buff_name] = max(active_buffs[buff_name], duration)
	else:
		active_buffs[buff_name] = duration
		
	if buff_name == "burn":
		modulate = Color(1, 0.5, 0.5)
