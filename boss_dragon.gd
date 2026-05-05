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
