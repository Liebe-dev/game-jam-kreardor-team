extends Node2D
@export var move_indicator_scene: PackedScene
var active_indicators = [] # Mảng quản lý các ô đang hiện trên màn hình
var player_pawn_scene = preload("res://Pawn.tscn")
var player_king_scene = preload("res://PlayerKing.tscn")
var enemy_pawn_scene = preload("res://Enemy_pawn.tscn")
var enemy_knight_scene = preload("res://Knight.tscn") 
var enemy_bishop_scene = preload("res://Bishop.tscn")
var enemy_rook_scene = preload("res://Rook.tscn")
var enemy_queen_scene = preload("res://Queen.tscn")
@onready var grid_points = $"../GridPoints"
@onready var btn_attack = $"../CanvasLayer/HBoxContainer/Attack"
@onready var btn_defend = $"../CanvasLayer/HBoxContainer/Defend"
var current_turn = 1
@onready var wave_label = $"../CanvasLayer/WaveLabel"
@onready var turn_label = $"../CanvasLayer/TurnLabel"
enum Command { ATTACK, DEFEND, IDLE }
var current_command = Command.IDLE # Mặc định là đứng im

var has_moved_main_piece = false # Kiểm tra xem lượt này đã đi quân chính chưa
var piece_layer: Node2D 
var all_pieces = []
var selected_piece: Piece = null 
var is_player_turn = true     
var board_origin = Vector2(450, 250) 
var cell_size = 80
func is_within_board(pos: Vector2i) -> bool:
	# Giả sử bàn cờ của bạn là 8x8 (từ ô 0 đến 7)
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

# --- CƠ CHẾ WAVE ---

# 1. Hàm đếm số địch còn sống trên bàn cờ
func count_enemies_alive() -> int:
	var enemy_count = 0
	for p in all_pieces:
		# Nếu quân cờ còn tồn tại và tên có chữ "enemy"
		if is_instance_valid(p) and "enemy" in p.name.to_lower():
			enemy_count += 1
	return enemy_count

# 2. Hàm kiểm tra điều kiện qua màn / Thắng game
# --- HÀM 1: CHUYỂN WAVE VÀ BƠM MÁU/HỒI SINH ---
func transition_to_next_wave():
	# 1. Tăng số Wave và cập nhật chữ trên màn hình
	Global.current_wave += 1
	if wave_label:
		wave_label.text = "Wave: " + str(Global.current_wave)
		
	
	# 2. Xử lý quân ta (Hồi máu cho kẻ sống)
	var alive_pawns_count = 0
	# (Giả sử 8 con Tốt ta xuất phát ở hàng Y = 6)
	var default_spawn_positions = [Vector2(0,6), Vector2(1,6), Vector2(2,6), Vector2(3,6), Vector2(4,6), Vector2(5,6), Vector2(6,6), Vector2(7,6)]
	
	for p in all_pieces:
		if is_instance_valid(p) and not ("enemy" in p.name.to_lower()):
			if "Pawn" in p.name:
				alive_pawns_count += 1
				p.hp += 30 # Sống sót qua wave: Hồi 30 máu
				# (Tùy chọn) Giới hạn không cho máu vượt quá tối đa (VD: 50)
				if p.hp > 50: p.hp = 50 
				
				if p.has_node("HealthBar"):
					p.get_node("HealthBar").value = p.hp
					
	# 3. Hồi sinh kẻ chết
	var dead_pawns_count = 8 - alive_pawns_count
	if dead_pawns_count > 0:
		for pos in default_spawn_positions:
			if dead_pawns_count <= 0: break
			
			# Kiểm tra xem cái ô xuất phát đó có bị thằng Tốt nào đứng chiếm chỗ không
			if is_cell_empty(pos): 
				var new_pawn = player_pawn_scene.instantiate()
				piece_layer.add_child(new_pawn)
				all_pieces.append(new_pawn)
				
				new_pawn.grid_pos = pos
				if has_method("grid_to_pixel"): new_pawn.position = grid_to_pixel(pos)
				
				new_pawn.hp = 20 # Chết đi sống lại: 20 máu
				if new_pawn.has_node("HealthBar"):
					new_pawn.get_node("HealthBar").max_value = 50 # Hoặc máu max của bạn
					new_pawn.get_node("HealthBar").value = 20
					
				dead_pawns_count -= 1
				
	# 4. Gọi lính địch ra
	spawn_enemy_wave()

# --- HÀM 2: CÔNG TẮC KIỂM TRA ĐIỀU KIỆN ---
func check_and_trigger_next_wave():
	if Global.current_wave >= 5:
		if game_over_menu:
			game_over_menu.visible = true
		return 
		
	# Thay vì gọi reload_scene, ta gọi hàm bơm máu ở trên
	transition_to_next_wave()
func _ready():
	# Hàm này tự động chạy 1 lần duy nhất khi màn chơi vừa load xong
	if wave_label:
		# Lấy biến current_wave từ file Global đắp vào Label
		wave_label.text = "Wave: " + str(Global.current_wave)
	# Tạo một Node2D làm lớp chứa quân cờ nếu chưa có
	piece_layer = Node2D.new()
	piece_layer.name = "PieceLayer"
	add_child(piece_layer)
	
	spawn_initial_army()


func spawn_initial_army():
	if Global.current_wave == 1:
		# 1. Khởi tạo 8 con Tốt ta ở hàng ngang số 6
		for i in range(8):
			var pawn = player_pawn_scene.instantiate()
			piece_layer.add_child(pawn)
			all_pieces.append(pawn)
			pawn.grid_pos = Vector2(i, 6)
			if has_method("grid_to_pixel"): pawn.position = grid_to_pixel(Vector2(i, 6))
			
		# 2. Khởi tạo 1 con Vua đứng ở giữa hàng ngang số 7 (bảo kê đằng sau)
		if player_king_scene:
			var king = player_king_scene.instantiate()
			piece_layer.add_child(king)
			all_pieces.append(king)
			# Đặt Vua ở tọa độ X=3, Y=7 (Hoặc X=4 tùy bạn chọn)
			king.grid_pos = Vector2(3, 7) 
			if has_method("grid_to_pixel"): king.position = grid_to_pixel(Vector2(3, 7))

		# 3. Gọi lính địch Wave 1 ra
		spawn_enemy_wave()
func spawn_enemy_wave():
	var wave_setup = []
	
	match Global.current_wave:
		1: # Wave 1: 4 Tốt đan xen
			wave_setup = [
				{"scene": enemy_pawn_scene, "pos": Vector2(1, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(3, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(5, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(7, 1)}
			]
		2: # Wave 2: 8 Tốt
			for i in range(8):
				wave_setup.append({"scene": enemy_pawn_scene, "pos": Vector2(i, 1)})
		3: # Wave 3: 2 Tượng, 2 Mã
			wave_setup = [
				{"scene": enemy_bishop_scene, "pos": Vector2(2, 0)},
				{"scene": enemy_bishop_scene, "pos": Vector2(5, 0)},
				{"scene": enemy_knight_scene, "pos": Vector2(3, 0)},
				{"scene": enemy_knight_scene, "pos": Vector2(4, 0)}
			]
		4: # Wave 4: 2 Xe, 4 Tốt
			wave_setup = [
				{"scene": enemy_rook_scene, "pos": Vector2(0, 0)},
				{"scene": enemy_rook_scene, "pos": Vector2(7, 0)},
				{"scene": enemy_pawn_scene, "pos": Vector2(2, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(3, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(4, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(5, 1)}
			]
		5: # Wave 5: 2 Hậu, 2 Xe, 2 Mã, 2 Tượng, 2 Tốt (trước 2 Tượng)
			wave_setup = [
				{"scene": enemy_queen_scene, "pos": Vector2(3, 0)},
				{"scene": enemy_queen_scene, "pos": Vector2(4, 0)},
				{"scene": enemy_rook_scene, "pos": Vector2(0, 0)},
				{"scene": enemy_rook_scene, "pos": Vector2(7, 0)},
				{"scene": enemy_knight_scene, "pos": Vector2(1, 0)},
				{"scene": enemy_knight_scene, "pos": Vector2(6, 0)},
				{"scene": enemy_bishop_scene, "pos": Vector2(2, 0)},
				{"scene": enemy_bishop_scene, "pos": Vector2(5, 0)},
				{"scene": enemy_pawn_scene, "pos": Vector2(2, 1)}, # Tốt trước Tượng trái
				{"scene": enemy_pawn_scene, "pos": Vector2(5, 1)}  # Tốt trước Tượng phải
			]
			
	# Vòng lặp đẻ quân địch (Giữ nguyên như cũ)
	for data in wave_setup:
		if data["scene"] == null: continue
		var enemy = data["scene"].instantiate()
		piece_layer.add_child(enemy)
		all_pieces.append(enemy)
		enemy.grid_pos = data["pos"]
		if has_method("grid_to_pixel"):
			enemy.position = grid_to_pixel(data["pos"])

func create_piece(grid_pos: Vector2i, team: int, scene: PackedScene):
	if scene == null: return # Tránh crash nếu quên kéo scene
	
	var new_unit = scene.instantiate()
	new_unit.team = team
	new_unit.grid_pos = grid_pos
	
	# --- ĐẶT TÊN CHO CHUẨN ĐỂ CODE NHẬN DIỆN ---
	if scene == king_scene:
		new_unit.name = "King_" + str(team)
	elif scene == rook_scene:
		new_unit.name = "Rook_" + str(team)
	elif scene == queen_scene:
		new_unit.name = "Queen_" + str(team)
	elif scene == knight_scene:
		new_unit.name = "Knight_" + str(team)
	elif scene == bishop_scene:
		new_unit.name = "Bishop_" + str(team)
	else:
		new_unit.name = "Pawn_" + str(team)
		
	piece_layer.add_child(new_unit)
	new_unit.global_position = calculate_world_position(grid_pos)
	
	var sprite = new_unit.get_node("Sprite2D")
	
	# Code quyết định hướng nhìn ban đầu của bạn giữ nguyên
	if team == 1:
		sprite.frame = 3
	elif team == 2:
		sprite.frame = 0
		if new_unit.has_node("HealthBar"):
			new_unit.get_node("HealthBar").modulate = Color(1, 0, 0)
			
	all_pieces.append(new_unit)
func calculate_world_position(grid_pos: Vector2i) -> Vector2:
	# Ghép tọa độ X và Y thành tên node. Ví dụ grid_pos(3, 4) -> "3_4"
	var marker_name = str(grid_pos.y) + " " + str(grid_pos.x)
	
	# Tìm Marker2D có tên đó trong node GridPoints
	var marker = grid_points.get_node_or_null(marker_name)
	
	if marker:
		return marker.global_position
	else:
		return Vector2.ZERO
func deal_damage(target, amount):
	if not is_instance_valid(target):
		return
		
	# CHẶN ĐỨNG: Nếu dame quá ảo (ví dụ dame âm hoặc bằng 0) thì bỏ qua (Code của đồng đội)
	if amount <= 0: return
	
	# Gọi hàm take_damage xịn sò để quân cờ tự lo việc trừ máu, chớp đỏ và chết (Code của bạn)
	if target.has_method("take_damage"):
		target.take_damage(amount)
func _input(event):
	if has_moved_main_piece: return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var clicked_grid = calculate_grid_position(click_pos)
		
		if not is_within_board(clicked_grid): return
			
		var piece_at_click = get_piece_at(clicked_grid)
		
		# Chọn quân mình
		if piece_at_click and piece_at_click.team == 1:
			selected_piece = piece_at_click
			show_highlights(selected_piece) # HIỆN Ô SÁNG
			
		# Di chuyển
		elif selected_piece != null:
			var valid_moves = get_valid_moves(selected_piece)
			if clicked_grid in valid_moves:
				if selected_piece.is_grabbed:
					break_grab(selected_piece)
						
				move_piece(selected_piece, clicked_grid)
				selected_piece.has_moved = true
				has_moved_main_piece = true
				
				clear_highlights() # XÓA Ô SÁNG SAU KHI ĐI
				selected_piece = null
			else:
				# Click vào ô không đi được -> Hủy chọn
				clear_highlights()
				selected_piece = null
func calculate_grid_position(world_pos: Vector2) -> Vector2i:
	var closest_grid = Vector2i(-1, -1)
	var min_distance = 999999.0 # Khởi tạo một khoảng cách ảo rất lớn
	
	# Quét qua toàn bộ 64 ô trên bàn cờ
	for x in range(8):
		for y in range(8):
			var marker_name = str(y) + " " + str(x)
			var marker = grid_points.get_node_or_null(marker_name)
			
			if marker:
				# Đo khoảng cách từ điểm click chuột đến tâm của ô này
				var dist = world_pos.distance_to(marker.global_position)
				
				# Nếu tìm thấy ô nào gần hơn, cập nhật lại
				if dist < min_distance:
					min_distance = dist
					closest_grid = Vector2i(x, y)
					
	return closest_grid
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
	if piece.is_grabbed:
		return
	var target_world = calculate_world_position(target_grid)
	piece.move_to_grid(target_grid, target_world)
	
	# --- THÊM DÒNG NÀY ---
	# Sau khi di chuyển xong tọa độ logic, thử ôm ngay lập tức
	check_and_execute_grab(piece)
func find_my_king(my_team: int):
	for p in all_pieces:
		if is_instance_valid(p) and p.team == my_team and "King" in p.name:
			return p
	return null
func queen_grab_counter(queen):
	# Biến chứa kẻ địch đang ôm/đứng sát Hậu
	var grabber = queen.grabbed_by 
	
	if is_instance_valid(grabber):
		# --- CHÈN THÊM ĐOẠN QUAY MẶT NÀY VÀO TRƯỚC KHI CHÉM ---
		var aim_dir = grabber.grid_pos - queen.grid_pos
		var sprite = queen.get_node_or_null("Sprite2D")
		if sprite:
			if abs(aim_dir.x) > abs(aim_dir.y):
				sprite.frame = 1 if aim_dir.x > 0 else 2 # Nhìn Phải/Trái
			else:
				sprite.frame = 0 if aim_dir.y > 0 else 3 # Nhìn Xuống/Lên
		# --------------------------------------------------------
		
		# (Code cũ của bạn ở dưới giữ nguyên nhé)
		# deal_damage(grabber, 15)
	var target_to_hit = queen.grabbed_by
	if not is_instance_valid(target_to_hit): return
	
	# Xác định hướng từ Hậu đến kẻ ôm để tìm "2 bên cạnh"
	var dir_to_grabber = target_to_hit.grid_pos - queen.grid_pos
	
	# Tính toán 2 ô bên cạnh kẻ đang ôm (vuông góc với hướng ôm)
	var side_dirs = [
		Vector2i(-dir_to_grabber.y, dir_to_grabber.x),
		Vector2i(dir_to_grabber.y, -dir_to_grabber.x)
	]
	
	# 1. Đánh kẻ đang ôm
	deal_damage(target_to_hit, 35)
	
	# 2. Đánh lan sang 2 ô bên cạnh con đó
	for side in side_dirs:
		var side_pos = target_to_hit.grid_pos + side
		var side_unit = get_piece_at(side_pos)
		if side_unit and side_unit.team != queen.team:
			deal_damage(side_unit, 35)
			


func find_queen_ranged_target(queen):
	var directions = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)
	]
	var closest_target = null
	var min_dist = 999
	
	for dir in directions:
		for i in range(1, 8):
			var scan_pos = queen.grid_pos + dir * i
			if not is_within_board(scan_pos): break
			
			var unit = get_piece_at(scan_pos)
			if unit:
				if unit.team != queen.team:
					if i < min_dist:
						min_dist = i
						closest_target = unit
				break # Gặp bất cứ ai cũng dừng hướng đó
	return closest_target

func _on_attack_pressed():
	if current_command == Command.ATTACK:
		# Nếu đang là Attack mà nhấn lại -> Tắt về IDLE
		current_command = Command.IDLE
		btn_attack.modulate = Color(1, 1, 1) 
	else:
		# Nếu đang ở trạng thái khác -> Bật Attack
		current_command = Command.ATTACK
		btn_attack.modulate = Color(1, 0.5, 0.5) # Sáng lên
		btn_defend.modulate = Color(1, 1, 1)     # Tắt nút Defend

func _on_defend_pressed():
	if current_command == Command.DEFEND:
		# Nếu đang là Defend mà nhấn lại -> Tắt về IDLE
		current_command = Command.IDLE
		btn_defend.modulate = Color(1, 1, 1)
	else:
		# Nếu đang ở trạng thái khác -> Bật Defend
		current_command = Command.DEFEND
		btn_defend.modulate = Color(0.5, 0.5, 1) # Sáng lên
		btn_attack.modulate = Color(1, 1, 1)     # Tắt nút Attack
func _on_end_turn_pressed():
	
	# 1. CHO CÁC PHE DI CHUYỂN TRƯỚC (Tuyệt đối không gây dame giằng co ở đây)
	move_team_logic(1)
	
	await get_tree().create_timer(0.3).timeout
	
	move_team_logic(2)
	
	await get_tree().create_timer(0.2).timeout # Đợi quân địch đứng yên

# 2. KIỂM TRA ÔM (Để khóa chân nhau trước khi tính dame)
	for p in all_pieces:
		if is_instance_valid(p):
			check_and_execute_grab(p)
			
	# 3. GÂY SÁT THƯƠNG RIÊNG BIỆT (Thay thế apply_grab_damage)
	execute_all_combat_logic()
	# 4. RESET LƯỢT
	for p in all_pieces:
		if is_instance_valid(p):
			p.has_moved = false
	has_moved_main_piece = false
	selected_piece = null
	current_turn += 1
	if turn_label:
		turn_label.text = "Turn: " + str(current_turn)
	process_ammo_reloads()
func execute_all_combat_logic():
	for p in all_pieces:
		if not is_instance_valid(p): continue
		
		# KHI BỊ ÔM
		if p.is_grabbed:
			if "Queen" in p.name:
				execute_queen_logic(p) 
			elif "Knight" in p.name:
				execute_knight_logic(p) 
			elif "Bishop" in p.name:         
				execute_bishop_logic(p)
			elif "Pawn" in p.name or "King" in p.name:
				if is_instance_valid(p.grabbed_by):
					deal_damage(p.grabbed_by, 10)
		
		# KHI TỰ DO (Được dùng chiêu)
		else:
			if "Rook" in p.name:
				# Tự gọi hàm check xung quanh và khai hỏa của Xe
				execute_rook_logic(p)
			elif "Bishop" in p.name:
				execute_bishop_logic(p)
func move_team_logic(team_num: int):
	for p in all_pieces:
		if not is_instance_valid(p) or p.team != team_num: continue
		if p.is_grabbed or "King" in p.name: continue 
		if p.has_moved: continue

		# --- 1. LOGIC NẠP ĐẠN CHO XE ---
		if "Rook" in p.name:
			if not p.is_charging:
				p.is_charging = true
				p.has_moved = true
				
				# --- DÒNG MỚI BỔ SUNG ---
				# Gắn 1 cái mác ảo báo hiệu Xe vừa nạp đạn trong chính lượt này
				p.set_meta("just_charged", true) 
				
				if p.has_method("update_visuals"): p.update_visuals()
				continue
		# --- 2. LOGIC DI CHUYỂN CỦA PHE TA (TEAM 1) ---
		if team_num == 1:
			if current_command == Command.IDLE: continue 
			elif current_command == Command.DEFEND:
				var king_target = find_my_king(1)
				if king_target:
					var next = get_next_step_towards(p.grid_pos, king_target.grid_pos)
					if is_cell_vacant(next): move_piece(p, next)
				continue

		# --- 3. LOGIC TẤN CÔNG (Team 2 hoặc Team 1 Attack) ---
		if (team_num == 1 and current_command == Command.ATTACK) or team_num == 2:
			var acted = false 
			
			if "Queen" in p.name:
				execute_queen_logic(p)
				acted = true 
			elif "Knight" in p.name:
				execute_knight_logic(p)
				acted = true 
			elif "Bishop" in p.name:
				execute_bishop_logic(p)
				acted = true 
			elif "Rook" in p.name:
				acted = true
			if acted: continue
			
			# Lính thường (Pawn) mới được chạy đi tìm mục tiêu
			var target = find_best_target(p)
			if target:
				var next = get_next_step_towards(p.grid_pos, target.grid_pos)
				if is_cell_vacant(next): move_piece(p, next)
func find_best_target(for_piece: Piece):
	var enemy_king = null
	var enemy_soldiers = []
	
	# Phân loại kẻ địch trên bàn cờ
	for p in all_pieces:
		if is_instance_valid(p) and p.team != for_piece.team:
			if "King" in p.name: 
				enemy_king = p
			else:
				enemy_soldiers.append(p)
				
	# --- TƯ DUY DI CHUYỂN TÁCH BIỆT ---
	
	if for_piece.team == 1:
		# LÍNH PHE TA: Dọn dẹp tàn quân địch trước, hết lính mới đánh Vua địch
		if enemy_soldiers.size() > 0:
			return get_closest(for_piece, enemy_soldiers)
		return enemy_king
		
	else:
		# KẺ ĐỊCH (TEAM 2): Bất chấp tất cả, mục tiêu tối thượng để bước đi là VUA
		if enemy_king: 
			return enemy_king
		return get_closest(for_piece, enemy_soldiers)
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
func execute_queen_logic(queen):
	# 1. Kiểm tra xem Hậu có đang bận nạp đạn không
	if queen.is_reloading:
		return # Bỏ qua, không làm gì cả trong lượt này

	# 2. Tìm mục tiêu (Code cũ của bạn)
	var target = find_queen_ranged_target(queen) 
	
	if target:
		
		# (Code quay mặt sprite giữ nguyên...)
				
		# Bắn đạn 
		create_projectile_effect(queen.global_position, target.global_position)
		await get_tree().create_timer(0.2).timeout 
		
		if is_instance_valid(target):
			deal_damage(target, 25)

		# --- 3. TRỪ ĐẠN SAU KHI BẮN ---
		queen.current_ammo -= 1
		# Cập nhật thanh màu vàng trên đầu Hậu
		if queen.has_node("AmmoBar"):
			queen.get_node("AmmoBar").value = queen.current_ammo
			
		# Nếu bắn hết 3 viên -> Kích hoạt trạng thái nạp đạn
		if queen.current_ammo <= 0:
			queen.is_reloading = true
			queen.reload_turns_left = 2 # Cần 2 turn để nạp đầy
func get_surrounding_cells(pos: Vector2i, dist: int) -> Array:
	var cells = []
	for x in range(-dist, dist + 1):
		for y in range(-dist, dist + 1):
			if x == 0 and y == 0: continue
			var c = pos + Vector2i(x, y)
			if is_within_board(c): cells.append(c)
	return cells
func execute_rook_attack(rook, target_unit):
	var dir = (target_unit.grid_pos - rook.grid_pos)
	# Chuẩn hóa hướng về Vector2i đơn vị (1,0 hoặc 0,1...)
	var forward = Vector2i(sign(dir.x), sign(dir.y))
	var side = Vector2i(-forward.y, forward.x) # Vector vuông góc để tìm 2 bên
	
	# --- BỔ SUNG CODE QUAY MẶT TRƯỚC KHI BẮN ---
	var sprite = rook.get_node_or_null("Sprite2D")
	if sprite:
		if forward.x > 0: sprite.frame = 1      # Bắn sang Phải
		elif forward.x < 0: sprite.frame = 2    # Bắn sang Trái
		elif forward.y > 0: sprite.frame = 0    # Bắn xuống Dưới
		elif forward.y < 0: sprite.frame = 3    # Bắn lên Trên
		
	# --- 1. TẤN CÔNG 3 Ô ĐẰNG TRƯỚC (Gây 20 dame + Đẩy lùi 3 ô) ---
	for i in range(1, 4):
		var pos = rook.grid_pos + forward * i
		var unit = get_piece_at(pos)
		if unit and unit.team != rook.team:
			deal_damage(unit, 20)
			
			# Gọi hàm đẩy lùi (Ví dụ: Đẩy 3 ô, dame va đập 15)
			apply_knockback(unit, forward, 3, 15)
	# --- 2. TẤN CÔNG 2 Ô BÊN CẠNH (Gây 10 dame, không bật lùi) ---
	var sides = [rook.grid_pos + side, rook.grid_pos - side]
	for s_pos in sides:
		var unit = get_piece_at(s_pos)
		if unit and unit.team != rook.team:
			deal_damage(unit, 10)

	# --- 3. LOGIC GIẬT LÙI (RECOIL) ---
	var back_pos = rook.grid_pos - forward # Ô ngay sau lưng
	
	if not is_within_board(back_pos):
		# Sau lưng là biên bàn cờ (coi như tường)
		deal_damage(rook, 5)
	elif not is_cell_vacant(back_pos):
		# Có quân đứng sau (bất kể quân ta hay địch)
		var back_unit = get_piece_at(back_pos)
		deal_damage(rook, 5)
		deal_damage(back_unit, 5)
	else:
		# Sau lưng trống trải -> Bị lùi lại
		move_piece(rook, back_pos)
func execute_rook_logic(rook):
	if not rook.is_charging:
		return
		
	# Nếu vừa nạp đạn lượt này -> Gỡ mác ảo ra, nhịn không bắn, chờ lượt sau
	if rook.has_meta("just_charged") and rook.get_meta("just_charged") == true:
		rook.set_meta("just_charged", false)
		return
		
	# Tầm nhìn hình dấu + (Lên, Xuống, Trái, Phải)
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		# Xe quét xa 3 ô theo đường thẳng
		for i in range(1, 4):
			var check_pos = rook.grid_pos + (dir * i)
			
			if not is_within_board(check_pos):
				break # Đụng tường thì dừng quét hướng này
				
			var target = get_piece_at(check_pos)
			if target:
				if target.team != rook.team:
					# TÌM THẤY ĐỊCH -> KHAI HỎA NGAY VÀ LUÔN!
					execute_rook_attack(rook, target)
					
					# Bắn xong thì mất đạn và reset trạng thái
					rook.is_charging = false
					if rook.has_method("update_visuals"):
						rook.update_visuals()
						
					# Đã bắn thì không đi bộ nữa -> Kết thúc hàm
					return 
				else:
					# Nếu đụng quân mình cản đường đạn -> Dừng quét hướng này
					break 

	# --- BỔ SUNG CHỖ NÀY: NẾU QUÉT 4 HƯỚNG MÀ KHÔNG CÓ AI ĐỂ BẮN -> ĐI BỘ ÁP SÁT ---
	var best_target = find_best_target(rook)
	if best_target:
		var next_step = get_next_step_towards(rook.grid_pos, best_target.grid_pos)
		if is_cell_vacant(next_step):
			move_piece(rook, next_step)
func execute_knight_logic(knight):
# --- TRƯỜNG HỢP 1: NẾU ĐANG BỊ GRAB (Phản đòn) ---
	if knight.is_grabbed:
		var grabber = knight.grabbed_by
		if is_instance_valid(grabber):
			# 1. Gây 15 dame phản đòn
			deal_damage(grabber, 15)
			
			# Xác định hướng đá văng
			var push_dir = (grabber.grid_pos - knight.grid_pos).sign()
			
			# --- BỔ SUNG: QUAY MẶT NHÌN THẲNG MẶT ĐỊCH TRƯỚC KHI ĐÁ ---
			var sprite = knight.get_node_or_null("Sprite2D")
			if sprite:
				if push_dir.x > 0: sprite.frame = 1      # Nhìn Phải
				elif push_dir.x < 0: sprite.frame = 2    # Nhìn Trái
				elif push_dir.y > 0: sprite.frame = 0    # Nhìn Xuống
				elif push_dir.y < 0: sprite.frame = 3    # Nhìn Lên
			
			# 2. GIẢI THOÁT TRẠNG THÁI TRƯỚC! (Mấu chốt để không bị kẹt)
			knight.is_grabbed = false
			grabber.is_grabbed = false
			knight.grabbed_by = null
			grabber.grabbed_by = null
			
			# Trả lại màu sắc bình thường
			knight.modulate = Color(1, 1, 1)
			grabber.update_visuals()
			
			# 3. MỚI GỌI HÀM ĐẨY LÙI (Đá văng 2 ô, đụng tường mất 20 dame)
			var hit = apply_knockback(grabber, push_dir, 2, 20)
			
			# Phản lực: Nếu đá trúng tường/quân khác, Mã cũng đau
			if hit:
				deal_damage(knight, 10) 
				
		return
	# TRƯỜNG HỢP 2: TẤN CÔNG HÌNH L & RÚT LUI
	var target = find_best_target(knight)
	if target:
		var diff = target.grid_pos - knight.grid_pos
		# Kiểm tra tầm L chuẩn: (2 ngang 1 dọc) hoặc (1 ngang 2 dọc)
		if (abs(diff.x) == 2 and abs(diff.y) == 1) or (abs(diff.x) == 1 and abs(diff.y) == 2):
			deal_damage(target, 30)
			
			# Lùi lại 2 ô về phía an toàn
			var retreat_dir = (knight.grid_pos - target.grid_pos).sign()
			var safe_pos = knight.grid_pos + (retreat_dir * 2)
			
			if is_within_board(safe_pos) and is_cell_vacant(safe_pos):
				move_piece(knight, safe_pos)
			return

# --- TRƯỜNG HỢP 3: DI CHUYỂN ÁP SÁT (ĐI CHUẨN HÌNH L) ---
	# Khai báo 8 hướng nhảy chữ L chuẩn của cờ vua
	var l_moves = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
		Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)
	]
	
	var best_pos = knight.grid_pos
	var min_dist = 9999
	
	# AI: Thử từng bước nhảy L, xem bước nào an toàn và gần địch nhất
	for move in l_moves:
		var test_pos = knight.grid_pos + move
		
		# Phải nằm trong bàn cờ và ô đó chưa có ai đứng
		if is_within_board(test_pos) and is_cell_vacant(test_pos):
			# Tính khoảng cách từ vị trí thử nghiệm đến mục tiêu
			var dist = abs(target.grid_pos.x - test_pos.x) + abs(target.grid_pos.y - test_pos.y)
			
			if dist < min_dist:
				min_dist = dist
				best_pos = test_pos
				
	# --- BỔ SUNG QUAY MẶT KHI NHẢY L ---
	var sprite = knight.get_node_or_null("Sprite2D")
	if sprite and best_pos != knight.grid_pos:
		var dir = best_pos - knight.grid_pos
		# Mã nhảy L (2 dọc 1 ngang hoặc 1 dọc 2 ngang). Nhìn theo chiều nhảy xa hơn (2 ô)
		if abs(dir.x) > abs(dir.y):
			sprite.frame = 1 if dir.x > 0 else 2 # Nhìn Phải/Trái
		else:
			sprite.frame = 0 if dir.y > 0 else 3 # Nhìn Xuống/Lên
			
	# Thực hiện bước nhảy
	if best_pos != knight.grid_pos:
		move_piece(knight, best_pos)
func find_safest_pos(piece):
	var best_pos = piece.grid_pos
	var max_score = -1.0
	
	# Tìm kẻ địch đáng gờm nhất để né
	var threat = find_best_target(piece)
	if not threat: return piece.grid_pos
	
	# Kiểm tra các ô di chuyển được (ví dụ tầm chạy 2 ô khi hoảng loạn)
	for x in range(-2, 3):
		for y in range(-2, 3):
			var test_pos = piece.grid_pos + Vector2i(x, y)
			
			if is_within_board(test_pos) and is_cell_vacant(test_pos):
				# Điểm an toàn = khoảng cách tới kẻ địch
				var score = test_pos.distance_to(threat.grid_pos)
				if score > max_score:
					max_score = score
					best_pos = test_pos
					
	return best_pos
func execute_bishop_logic(bishop):
# --- TRƯỜNG HỢP 1: BỊ ÔM (Giải thoát trước, đẩy lùi sau) ---
	if bishop.is_grabbed:
		var grabber = bishop.grabbed_by
		if is_instance_valid(grabber):
			# 1. Gây 10 dame cho kẻ tóm mình
			deal_damage(grabber, 10) 
			
			var push_dir = (grabber.grid_pos - bishop.grid_pos).sign()
			
			# 2. GIẢI THOÁT TRẠNG THÁI TRƯỚC! (Mấu chốt nằm ở đây)
			bishop.is_grabbed = false
			grabber.is_grabbed = false
			bishop.grabbed_by = null
			grabber.grabbed_by = null
			
			# 3. MỚI GỌI HÀM ĐẨY LÙI SAU CÙNG
			apply_knockback(grabber, push_dir, 1, 5)
			
		return
	# --- TRƯỜNG HỢP 2: KHAI HỎA (Quét 4 hướng chéo, Tầm xa 2 ô, Không xuyên lính) ---
	var diag_dirs = [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	var attacked = false
	
	for dir in diag_dirs:
		# Quét xa tối đa 2 ô chéo
		for i in range(1, 3): 
			var check_pos = bishop.grid_pos + (dir * i)
			
			if not is_within_board(check_pos): 
				break # Đụng viền bản đồ -> Dừng tia đạn
				
			var unit = get_piece_at(check_pos)
			if unit:
				# Nếu đụng trúng quân bất kỳ (dù ta hay địch), tia đạn bị chặn lại
				if unit.team != bishop.team:
					# Nếu là ĐỊCH -> Bắn!
					create_projectile_effect(bishop.global_position, unit.global_position)
					deal_damage(unit, 35)
					attacked = true
					
					# Quay mặt khi bắn
					var sprite = bishop.get_node_or_null("Sprite2D")
					if sprite:
						if dir.x > 0: sprite.frame = 1
						elif dir.x < 0: sprite.frame = 2
						elif dir.y > 0: sprite.frame = 0
						elif dir.y < 0: sprite.frame = 3
				
				# Gặp bất kỳ ai cũng `break` vòng lặp của hướng này (Đạn không xuyên)
				break 
				
		if attacked: return # Chỉ bắn 1 viên/lượt rồi nghỉ

	# --- TRƯỜNG HỢP 3: KHÔNG CÓ AI TRONG TẦM BẮN 2 Ô -> ĐI BỘ LÁCH GÓC ---
	var target = find_best_target(bishop)
	if not target: return
	
	var possible_moves = []
	for step in diag_dirs:
		var test_pos = bishop.grid_pos + step
		if is_within_board(test_pos) and is_cell_vacant(test_pos):
			possible_moves.append(test_pos)
			
	var best_move = bishop.grid_pos
	var best_score = 9999
	
	# Tính toán ô để chui vào đường chéo
	for move in possible_moves:
		var test_diff = target.grid_pos - move
		var deviation = abs(abs(test_diff.x) - abs(test_diff.y)) 
		var dist = abs(test_diff.x) + abs(test_diff.y)
		var score = (deviation * 10) + dist 
		
		if score < best_score:
			best_score = score
			best_move = move
			
	# Cập nhật quay mặt khi đi bộ
	var step_dir = best_move - bishop.grid_pos
	var sprite = bishop.get_node_or_null("Sprite2D")
	if sprite:
		if step_dir.x > 0: sprite.frame = 1
		elif step_dir.x < 0: sprite.frame = 2
		elif step_dir.y > 0: sprite.frame = 0
		elif step_dir.y < 0: sprite.frame = 3
		
	if best_move != bishop.grid_pos:
		move_piece(bishop, best_move)
func check_and_execute_grab(pawn):
	# Vua không chủ động ôm ai, và đang bận ôm rồi thì thôi
	if "King" in pawn.name: return 
	if pawn.is_grabbed: return 
	
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var possible_targets = []
	
	# 1. Tìm tất cả các mục tiêu lân cận
	for dir in directions:
		var target_pos = pawn.grid_pos + dir
		var target_unit = get_piece_at(target_pos)
		
		# Khác phe là ôm được (Cho phép ôm chung 1 mục tiêu đang bị kẻ khác ôm)
		if target_unit and target_unit.team != pawn.team:
			possible_targets.append(target_unit)
			
	if possible_targets.size() == 0: return
	
	# 2. Ưu tiên Lính > Vua. Nếu có nhiều lính, CHỌN NGẪU NHIÊN 1 lính
	var soldier_targets = []
	for t in possible_targets:
		if not "King" in t.name:
			soldier_targets.append(t)
			
	var chosen_target = null
	if soldier_targets.size() > 0:
		chosen_target = soldier_targets.pick_random() # Bốc thăm ngẫu nhiên
	else:
		chosen_target = possible_targets.pick_random() # Bốc thăm ngẫu nhiên (chỉ có Vua)
		
# 3. Thực hiện khóa mục tiêu
	pawn.is_grabbed = true
	pawn.grabbed_by = chosen_target
	
	# 4. Báo cho mục tiêu biết là đang bị ôm
	chosen_target.is_grabbed = true
	if chosen_target.grabbed_by == null:
		chosen_target.grabbed_by = pawn
	
	# --- SỬA TÊN BIẾN Ở ĐÂY ---
	pawn.update_visuals()
	chosen_target.update_visuals() # Dùng chosen_target thay vì target_unit
	
	# --- LOGIC QUAY MẶT VỀ PHÍA KẺ BỊ ÔM ---
	var face_dir = chosen_target.grid_pos - pawn.grid_pos
	var sprite = pawn.get_node("Sprite2D")
	if sprite:
		if face_dir.x > 0: sprite.frame = 1     # Nhìn Phải
		elif face_dir.x < 0: sprite.frame = 2   # Nhìn Trái
		elif face_dir.y > 0: sprite.frame = 0   # Nhìn Xuống
		elif face_dir.y < 0: sprite.frame = 3   # Nhìn Lên
		
	# 4. Báo cho mục tiêu biết là đang bị đánh hội đồng
	chosen_target.is_grabbed = true
	# Chỉ gán grabbed_by nếu nó chưa ôm ai (để giữ nguyên mục tiêu ban đầu của nó)
	if chosen_target.grabbed_by == null:
		chosen_target.grabbed_by = pawn
	chosen_target.modulate = Color(0.5, 0.5, 0.5)
func break_grab(piece):
	# 1. Tự giải thoát cho bản thân
	piece.is_grabbed = false
	piece.grabbed_by = null
	piece.update_visuals()
	
	# 2. Tìm TẤT CẢ những kẻ đang bám lấy quân này và đá văng chúng ra
	for p in all_pieces:
		if is_instance_valid(p) and p.grabbed_by == piece:
			p.is_grabbed = false
			p.grabbed_by = null
			# Trả lại màu Trắng cho phe ta, màu Đỏ cho phe địch
			p.update_visuals()

func kill_piece(piece):
	# Giải phóng cho TẤT CẢ đối phương đang ôm quân này
	for p in all_pieces:
		if is_instance_valid(p) and p.grabbed_by == piece:
			p.is_grabbed = false
			p.grabbed_by = null
			p.update_visuals()
	
	# Xóa khỏi mảng quản lý và tiêu hủy
	if piece in all_pieces:
		all_pieces.erase(piece)
	
	piece.queue_free()

# Thêm biến impact_damage (sát thương va đập) vào cuối
func apply_knockback(unit, push_dir: Vector2i, max_dist: int, impact_damage: int) -> bool:
	if not is_instance_valid(unit): return false
	
	var current_grid = unit.grid_pos
	var hit_obstacle = false
	
	for i in range(1, max_dist + 1):
		var next_grid = current_grid + push_dir
		
		# 1. Đụng tường (Biên bàn cờ)
		if not is_within_board(next_grid):
			hit_obstacle = true
			break
			
		# 2. Đụng vật cản (Có quân cờ khác đứng chặn)
		if not is_cell_vacant(next_grid):
			hit_obstacle = true
			var obstacle = get_piece_at(next_grid)
			# Gây sát thương va đập cho kẻ cản đường
			if is_instance_valid(obstacle):
				deal_damage(obstacle, impact_damage) # SỬA Ở ĐÂY
			break
			
		# Nếu ô tiếp theo trống, ghi nhận vị trí mới
		current_grid = next_grid
		
	# Dịch chuyển nạn nhân đến ô trống xa nhất trước khi đụng tường/vật cản
	if current_grid != unit.grid_pos:
		move_piece(unit, current_grid)
		
	# Nếu có va đập, nạn nhân cũng bị chịu sát thương tương ứng
	if hit_obstacle:
		deal_damage(unit, impact_damage) # SỬA Ở ĐÂY
		
	return hit_obstacle

# Hàm tạo viên đạn bay (Dùng chung cho Tượng, Hậu hoặc các quân đánh xa sau này)
func create_projectile_effect(start_pos: Vector2, end_pos: Vector2):
	var bullet = ColorRect.new()
	bullet.color = Color.YELLOW # Màu đạn (Tượng xài đạn vàng)
	bullet.size = Vector2(15, 15)
	
	# Căn giữa viên đạn vào vị trí người bắn
	bullet.global_position = start_pos - (bullet.size / 2)
	add_child(bullet)
	
	# Dùng Tween để tạo hiệu ứng đạn bay cực nhanh (0.2 giây)
	var t = create_tween()
	t.tween_property(bullet, "global_position", end_pos - (bullet.size / 2), 0.2)
	
	# Bay đến nơi thì xóa viên đạn đi
	t.tween_callback(bullet.queue_free)
func get_valid_moves(piece: Piece) -> Array:
	var moves = []
	var directions = []
	var max_dist = 1 # Mặc định là 1 ô (Tốt, Vua)

	# Định nghĩa tầm xa và hướng dựa trên loại quân
	if "Knight" in piece.name:
		var l_moves = [Vector2i(1,2), Vector2i(2,1), Vector2i(-1,2), Vector2i(-2,1),
					   Vector2i(1,-2), Vector2i(2,-1), Vector2i(-1,-2), Vector2i(-2,-1)]
		for m in l_moves:
			var target = piece.grid_pos + m
			if is_within_board(target) and is_cell_vacant(target): moves.append(target)
		return moves # Mã nhảy đặc biệt nên return luôn

	if "Rook" in piece.name:
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		max_dist = 3 # Xe đi thẳng 3 ô
	elif "Bishop" in piece.name:
		directions = [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = 2 # Tượng đi chéo 2 ô
	elif "Queen" in piece.name:
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
					  Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = 8 # Hậu đi full bàn (hoặc tùy bạn chỉnh)
	else: # Pawn hoặc King
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
					  Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = 1

	# Quét các hướng (Dành cho quân đi đường thẳng/chéo)
	for d in directions:
		for i in range(1, max_dist + 1):
			var target = piece.grid_pos + d * i
			if is_within_board(target) and is_cell_vacant(target):
				moves.append(target)
			else:
				break # Bị chặn bởi quân khác hoặc biên thì dừng hướng đó
	return moves
func clear_highlights():
	# Xóa các ô tròn xanh
	for indicator in active_indicators:
		indicator.queue_free()
	active_indicators.clear()
	
	# Tắt viền sáng của quân cũ (nếu có)
	for p in all_pieces:
		if is_instance_valid(p) and p.has_node("Selector"):
			p.get_node("Selector").visible = false

func show_highlights(piece: Piece):
	clear_highlights()
	
	# 1. Hiện viền sáng (Bạn cần thêm 1 Sprite tên "Selector" vào trong Piece.tscn và để ẩn đi)
	if piece.has_node("Selector"):
		piece.get_node("Selector").visible = true
		
	# 2. Hiện các ô có thể đi
	var moves = get_valid_moves(piece)
	for m_pos in moves:
		var indicator = move_indicator_scene.instantiate()
		add_child(indicator)
		indicator.global_position = calculate_world_position(m_pos)
		active_indicators.append(indicator)
func process_ammo_reloads():
	for p in all_pieces:
		if is_instance_valid(p) and "Queen" in p.name:
			if p.is_reloading:
				# Trừ đi 1 turn chờ đợi
				p.reload_turns_left -= 1
				
				# Nếu đã chờ đủ 2 turn
				if p.reload_turns_left <= 0:
					p.is_reloading = false
					p.current_ammo = p.max_ammo # Nạp đầy 3 viên
					
					# Làm đầy lại thanh màu vàng
					if p.has_node("AmmoBar"):
						p.get_node("AmmoBar").value = p.current_ammo
