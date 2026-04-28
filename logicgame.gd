extends Node2D

@export var pawn_scene: PackedScene 
@export var king_scene: PackedScene 
@onready var btn_attack = $"../CanvasLayer/HBoxContainer/Attack"
@onready var btn_defend = $"../CanvasLayer/HBoxContainer/Defend"
enum Command { ATTACK, DEFEND }
var current_command = Command.ATTACK # Mặc định là CÔNG

var has_moved_main_piece = false # Kiểm tra xem lượt này đã đi quân chính chưa
var piece_layer: Node2D 
var all_pieces = []
var selected_piece: Piece = null 
var is_player_turn = true     
var board_origin = Vector2(450, 250) 
var cell_size = 80

func _ready():
	# Tạo một Node2D làm lớp chứa quân cờ nếu chưa có
	piece_layer = Node2D.new()
	piece_layer.name = "PieceLayer"
	add_child(piece_layer)
	
	spawn_initial_army()

func spawn_initial_army():
	create_piece(Vector2i(4, 7), 1, king_scene)
	for i in range(8):
		create_piece(Vector2i(i, 6), 1, pawn_scene)
	create_piece(Vector2i(3, 0), 2, king_scene)
	for i in range(8):
		create_piece(Vector2i(i, 1), 2, pawn_scene)

func create_piece(grid_pos: Vector2i, team: int, scene: PackedScene):
	if scene == null: return # Tránh crash nếu quên kéo scene
	
	var new_unit = scene.instantiate()
	new_unit.team = team
	new_unit.grid_pos = grid_pos
	
	if scene == king_scene:
		new_unit.name = "King_" + str(team)
	piece_layer.add_child(new_unit)
	new_unit.global_position = calculate_world_position(grid_pos)
	
	if team == 2:
		var sprite = new_unit.get_node("Sprite2D")
		sprite.modulate = Color(1, 0.4, 0.4)
		sprite.flip_v = true
		
		# Sửa chỗ này cho khớp với tên node bạn đặt (HealthBar hoặc heath)
		if new_unit.has_node("HealthBar"):
			new_unit.get_node("HealthBar").modulate = Color(1, 0, 0)
			
	all_pieces.append(new_unit)


func calculate_world_position(grid_pos: Vector2i) -> Vector2:
	var my_skew = grid_pos.y * 4 
	return board_origin + Vector2(grid_pos.x * cell_size + skew, grid_pos.y * cell_size)

func _input(event):
	# Nếu đã đi quân chính rồi thì không cho click nữa
	if has_moved_main_piece:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var clicked_grid = calculate_grid_position(click_pos)
		var piece_at_click = get_piece_at(clicked_grid)
		
		# Bước 1: Chọn quân của mình (Team 1)
		if piece_at_click and piece_at_click.team == 1:
			selected_piece = piece_at_click
			
		# Bước 2: Di chuyển quân đã chọn vào ô trống
		elif selected_piece != null:
			if is_cell_vacant(clicked_grid):
				move_piece(selected_piece, clicked_grid)
				has_moved_main_piece = true # Khóa lại sau khi đi 1 quân
				selected_piece = null

func calculate_grid_position(world_pos: Vector2) -> Vector2i:
	var relative_pos = world_pos - board_origin
	# Dựa trên công tính toán của bạn ở hàm calculate_world_position
	var y = int(round(relative_pos.y / cell_size))
	var x = int(round((relative_pos.x - (y * 4)) / cell_size))
	return Vector2i(x, y)

# Hàm tìm xem tại ô (x, y) có quân nào đang đứng không
func get_piece_at(grid_pos: Vector2i):
	for p in all_pieces:
		if is_instance_valid(p) and p.grid_pos == grid_pos:
			return p
	return null

# Kiểm tra ô có trống hay không
func is_cell_vacant(grid_pos: Vector2i) -> bool:
	return get_piece_at(grid_pos) == null

# Lệnh điều khiển quân cờ di chuyển thực tế
func move_piece(piece: Piece, target_grid: Vector2i):
	var target_world = calculate_world_position(target_grid)
	# Gọi hàm move_to_grid mà bạn đã viết trong pawn.gd (hoặc piece.gd)
	piece.move_to_grid(target_grid, target_world)

func find_my_king(my_team: int):
	for p in all_pieces:
		if is_instance_valid(p) and p.team == my_team and "King" in p.name:
			return p
	return null

func _on_attack_pressed():
	current_command = Command.ATTACK
	btn_attack.modulate = Color(1, 0.5, 0.5) # Sáng lên khi chọn
	btn_defend.modulate = Color(1, 1, 1)     # Nút kia về bình thường

func _on_defend_pressed():
	current_command = Command.DEFEND
	btn_attack.modulate = Color(1, 1, 1)     # Nút kia về bình thường
	btn_defend.modulate = Color(0.5, 0.5, 1) # Sáng lên khi chọn
func _on_end_turn_pressed() -> void:
	
	# CHO QUÂN TA (TEAM 1) ĐI
	move_team_logic(1)
	
	# Đợi 0.5 giây cho mượt rồi cho quân Địch đi
	await get_tree().create_timer(0.5).timeout
	
	# CHO QUÂN ĐỊCH (TEAM 2) ĐI
	move_team_logic(2)
	
	# Reset để lượt sau có thể dùng chuột di chuyển tiếp
	has_moved_main_piece = false
	selected_piece = null

# 2. Hàm xử lý di chuyển cho từng phe
func move_team_logic(team_num: int):
	for p in all_pieces:
		if is_instance_valid(p) and p.team == team_num:
			# Vua luôn đứng yên
			if "King" in p.name: continue 
			
			var target = null
			
			# Nếu là phe mình (Team 1) và đang bật chế độ DEFEND/PROTECT
			if team_num == 1 and current_command == Command.DEFEND:
				target = find_my_king(1) # Tìm đường về cứu Vua
			else:
				target = find_best_target(p) # Chế độ Attack: đi tìm địch
				
			if target:
				# Tính toán ô tiếp theo để tiến về phía mục tiêu
				var next = get_next_step_towards(p.grid_pos, target.grid_pos)
				if is_cell_vacant(next):
					move_piece(p, next)
# 3. Hàm tìm mục tiêu (Đây là "Bộ não" của AI)
func find_best_target(for_piece: Piece):
	var enemy_king = null
	var enemy_soldiers = []
	
	# Tìm xem đối phương có những ai
	for p in all_pieces:
		if is_instance_valid(p) and p.team != for_piece.team:
			if "King" in p.name: 
				enemy_king = p
			else:
				enemy_soldiers.append(p)
				
	# TƯ DUY:
	if for_piece.team == 1: # Quân ta: Tìm lính trước, hết lính mới đánh Vua
		if enemy_soldiers.size() > 0:
			return get_closest(for_piece, enemy_soldiers)
		return enemy_king
	else: # Quân địch: Lao thẳng vào Vua của bạn
		if enemy_king: return enemy_king
		return get_closest(for_piece, enemy_soldiers)

# 4. Các hàm hỗ trợ tính toán (Dán vào cuối file)
func get_closest(for_piece, list):
	var closest = null
	var min_dist = 9999
	for p in list:
		var d = abs(p.grid_pos.x - for_piece.grid_pos.x) + abs(p.grid_pos.y - for_piece.grid_pos.y)
		if d < min_dist:
			min_dist = d
			closest = p
	return closest
# Hàm tìm ô tiếp theo để đến gần mục tiêu nhất

func get_next_step_towards(start: Vector2i, target: Vector2i) -> Vector2i:
	var diff = target - start
	var step = Vector2i(0, 0)
	
	# Ưu tiên tiến theo trục dọc (Y) trước, sau đó mới đến trục ngang (X)
	if abs(diff.y) > 0:
		step.y = sign(diff.y)
	elif abs(diff.x) > 0:
		step.x = sign(diff.x)
		
	return start + step
