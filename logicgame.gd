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
func is_within_board(pos: Vector2i) -> bool:
	# Giả sử bàn cờ của bạn là 8x8 (từ ô 0 đến 7)
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

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
		
		# Sửa chỗ này cho khớp với tên node bạn đặt (HealthBar hoặc heath)
		if new_unit.has_node("HealthBar"):
			new_unit.get_node("HealthBar").modulate = Color(1, 0, 0)
			
	all_pieces.append(new_unit)


func calculate_world_position(grid_pos: Vector2i) -> Vector2:
	var skew = grid_pos.y * 4 
	return board_origin + Vector2(grid_pos.x * cell_size + skew, grid_pos.y * cell_size)
func deal_damage(target, amount):
	if not is_instance_valid(target) or target.health <= 0:
		return
		
	# CHẶN ĐỨNG: Nếu dame quá ảo (ví dụ dame âm hoặc bằng 0) thì bỏ qua
	if amount <= 0: return
	target.health -= amount
	print("DEAL DAME: ", target.name, " mất ", amount, " còn ", target.health)
	
	if target.has_node("HealthBar"):
		target.get_node("HealthBar").value = target.health
	
	if target.health <= 0:
		kill_piece(target)
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
	if piece.is_grabbed:
		return
	var target_world = calculate_world_position(target_grid)
	# Gọi hàm move_to_grid mà bạn đã viết trong pawn.gd (hoặc piece.gd)
	piece.move_to_grid(target_grid, target_world)

func find_my_king(my_team: int):
	for p in all_pieces:
		if is_instance_valid(p) and p.team == my_team and "King" in p.name:
			return p
	return null
func queen_grab_counter(queen):
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
	current_command = Command.ATTACK
	btn_attack.modulate = Color(1, 0.5, 0.5) # Sáng lên khi chọn
	btn_defend.modulate = Color(1, 1, 1)     # Nút kia về bình thường

func _on_defend_pressed():
	current_command = Command.DEFEND
	btn_attack.modulate = Color(1, 1, 1)     # Nút kia về bình thường
	btn_defend.modulate = Color(0.5, 0.5, 1) # Sáng lên khi chọn
func _on_end_turn_pressed():
	
	# 1. CHO CÁC PHE DI CHUYỂN TRƯỚC (Tuyệt đối không gây dame giằng co ở đây)
	move_team_logic(1)
	
	await get_tree().create_timer(0.5).timeout
	
	move_team_logic(2)
	
	await get_tree().create_timer(0.2).timeout # Đợi quân địch đứng yên

	# 2. SAU KHI TẤT CẢ ĐÃ ĐỨNG YÊN, MỚI KIỂM TRA XEM AI ĐANG CẠNH AI
	for p in all_pieces:
		if is_instance_valid(p):
			check_and_execute_grab(p)
			
	# 3. GÂY SÁT THƯƠNG GIẰNG CO CUỐI CÙNG (Chỉ một lần duy nhất)
	apply_grab_damage()
	
	# 4. RESET LƯỢT
	has_moved_main_piece = false
	selected_piece = null
func apply_grab_damage():
	# Dictionary để ghi nhớ: Mỗi thực thể chỉ bị tính dame 1 lần duy nhất
	var damage_map = {} 

	# BƯỚC 1: Quét toàn bộ bàn cờ để xác định đối tượng bị ôm
	for p in all_pieces:
		if is_instance_valid(p) and p.is_grabbed:
			# Kiểm tra xem kẻ đang ôm mình còn tồn tại không
			if is_instance_valid(p.grabbed_by):
				damage_map[p] = 10 # Gán mức sát thương là 10
			else:
				# Tự giải thoát nếu đối tác đã "bay màu"
				p.is_grabbed = false
				p.grabbed_by = null
				p.modulate = Color(1, 1, 1)
	# BƯỚC 2: Thực hiện trừ máu đồng loạt từ danh sách đã lọc
	for p in damage_map.keys():
		if is_instance_valid(p) and "health" in p:
			p.health -= damage_map[p]
			
			# Cập nhật thanh máu UI
			if p.has_node("HealthBar"):
				p.get_node("HealthBar").value = p.health
			
			# Kiểm tra chết an toàn để tránh lỗi "Invalid Access"
			if p.health <= 0:
				kill_piece(p)
func move_team_logic(team_num: int):
	# --- LƯỢT CỦA VUA ---
	for p in all_pieces:
		if is_instance_valid(p) and p.team == team_num and "King" in p.name:
			var target_pos = king_move_logic(p)
			if target_pos != p.grid_pos:
				move_piece(p, target_pos)

	# --- LƯỢT CỦA CÁC QUÂN CÒN LẠI ---
	for p in all_pieces:
		if not is_instance_valid(p) or p.team != team_num or "King" in p.name: 
			continue
		
		# Nếu quân đang bị ôm, nó sẽ thực hiện phản đòn trong execute_logic và dừng lại
		var acted = false
		
		if "Queen" in p.name:
			execute_queen_logic(p)
			acted = true # Hậu luôn ưu tiên bắn hoặc phản đòn
		elif "Rook" in p.name:
			execute_rook_logic(p)
			acted = true # Xe nạp đạn hoặc húc
		elif "Knight" in p.name:
			execute_knight_logic(p)
			acted = true # Mã phản đòn hoặc đá hình L
		elif "Bishop" in p.name:
			execute_bishop_logic(p)
			acted = true # Tượng bắn dấu X hoặc rút lui
			
		# Nếu là quân đặc biệt đã thực hiện chiêu thức thì bỏ qua phần đi bộ
		if acted: continue
		# 3. DI CHUYỂN (Dành cho Tốt hoặc các quân chưa làm gì)
		var target = null
		if team_num == 1 and current_command == Command.DEFEND:
			target = find_my_king(1)
		else:
			target = find_best_target(p)
			
		if target:
			var next = get_next_step_towards(p.grid_pos, target.grid_pos)
			if is_cell_vacant(next):
				move_piece(p, next)
				# Sau khi Tốt đi xong, cho nó thử ôm địch luôn
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
func execute_queen_logic(queen):
	# TRƯỜNG HỢP 1: ĐANG BỊ GRAB (Đánh gần cực mạnh)
	if queen.is_grabbed:
		queen_grab_counter(queen)
		return # Bị ôm thì không di chuyển được
		
	# TRƯỜNG HỢP 2: KHÔNG BỊ GRAB
	var target = find_queen_ranged_target(queen)
	if target:
		# Tấn công tầm xa 25 dame
		deal_damage(target, 25)
	else:
		# TRƯỜNG HỢP 3: KHÔNG CÓ ĐỊCH TRONG TẦM (Di chuyển như Cờ Vua)
		var move_pos = get_queen_move_towards_king(queen)
		if move_pos != queen.grid_pos:
			move_piece(queen, move_pos)

# Hàm di chuyển thông minh cho Hậu khi không có mục tiêu
func get_queen_move_towards_king(queen):
	var enemy_king = find_best_target(queen)
	if not enemy_king: return queen.grid_pos
	
	# Tìm hướng tốt nhất (Dọc, Ngang, Chéo) để áp sát Vua địch
	var diff = enemy_king.grid_pos - queen.grid_pos
	var step = Vector2i(sign(diff.x), sign(diff.y))
	var target_cell = queen.grid_pos + step
	
	if is_cell_vacant(target_cell) and is_within_board(target_cell):
		return target_cell
	return queen.grid_pos

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
	
	# --- 1. TẤN CÔNG 3 Ô ĐẰNG TRƯỚC (Gây 20 dame + Đẩy lùi 3 ô) ---
	for i in range(1, 4):
		var pos = rook.grid_pos + forward * i
		var unit = get_piece_at(pos)
		if unit and unit.team != rook.team:
			deal_damage(unit, 20)
			# Đẩy lùi kẻ địch 3 ô
			var push_pos = unit.grid_pos + forward * 3
			if is_within_board(push_pos) and is_cell_vacant(push_pos):
				move_piece(unit, push_pos)
			else:
				deal_damage(unit, 10) # Sát thương va chạm nếu không đẩy được
	
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
	# 1. Tìm danh sách địch trong 8 ô xung quanh
	var neighbors = get_surrounding_cells(rook.grid_pos, 1)
	var enemies = []
	for cell in neighbors:
		var p = get_piece_at(cell)
		if p and p.team != rook.team:
			enemies.append(p)
			
	# Nếu không có địch xung quanh, hủy nạp đạn và đứng yên
	if enemies.size() == 0:
		rook.is_charging = false
		return
	# 2. Nếu đã nạp đạn xong từ lượt trước -> KHAI HỎA
	if rook.is_charging:
		# Chọn mục tiêu ưu tiên:
		var target = null
		
		# Ưu tiên 1: Kẻ đang Grab mình
		if rook.is_grabbed and is_instance_valid(rook.grabbed_by):
			target = rook.grabbed_by
		else:
			# Ưu tiên 2: Kẻ ít máu nhất
			enemies.sort_custom(func(a, b): return a.health < b.health)
			target = enemies[0]
			
		# Thực hiện đòn đánh (Hàm húc càn và giật lùi đã viết ở câu trước)
		execute_rook_attack(rook, target)
		rook.is_charging = false # Bắn xong thì hết nạp đạn
		
	# 3. Nếu chưa nạp đạn -> Bắt đầu nạp đạn
	else:
		rook.is_charging = true
		# Bạn có thể thêm hiệu ứng đổi màu để người chơi biết Xe sắp bắn
		if rook.has_node("Sprite2D"):
			rook.get_node("Sprite2D").modulate = Color(2, 1, 1) # Chuyển sang sắc đỏ rực
func execute_knight_logic(knight):
	# TRƯỜNG HỢP 1: NẾU ĐANG BỊ GRAB (Phản đòn)
	if knight.is_grabbed:
		var grabber = knight.grabbed_by
		if is_instance_valid(grabber):
			# 1. Gây 15 dame phản đòn
			deal_damage(grabber, 15)
			
			# 2. Tính toán đẩy lùi
			var push_dir = (grabber.grid_pos - knight.grid_pos).sign()
			var land_pos = grabber.grid_pos + (push_dir * 2)
			
			if is_within_board(land_pos) and is_cell_vacant(land_pos):
				move_piece(grabber, land_pos)
				print("Mã đá văng kẻ ôm!")
			else:
				# VA CHẠM: Gây thêm 10 dame cho cả 2 nếu va tường/đơn vị khác
				deal_damage(grabber, 10)
				deal_damage(knight, 10) # Va chạm mạnh, Mã cũng đau
				
				# Kiểm tra an toàn trước khi gây dame cho vật cản (tránh lỗi hình 3e317f)
				var obstacle = get_piece_at(land_pos)
				if is_instance_valid(obstacle) and "health" in obstacle:
					deal_damage(obstacle, 10)
			
			# 3. GIẢI PHÓNG TRẠNG THÁI (Đồng bộ màu sắc)
			knight.is_grabbed = false
			grabber.is_grabbed = false
			knight.grabbed_by = null
			grabber.grabbed_by = null
			
			# Trả về màu bình thường
			knight.modulate = Color(1, 1, 1)
			grabber.modulate = Color(1, 1, 1)
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

	# TRƯỜNG HỢP 3: DI CHUYỂN ÁP SÁT (Nếu chưa đánh được ai)
	var next_step = get_next_step_towards(knight.grid_pos, target.grid_pos)
	if is_cell_vacant(next_step):
		move_piece(knight, next_step)
func king_move_logic(king):
	# Yêu cầu 1: Vua luôn miễn nhiễm với trạng thái bị ôm (Grab)
	king.is_grabbed = false 
	
	# Yêu cầu 2: Chỉ di chuyển khi có địch xung quanh
	var possible_moves = get_surrounding_cells(king.grid_pos, 1)
	var enemies_nearby = []
	
	# Tìm tất cả quân địch trong 8 ô xung quanh
	for cell in possible_moves:
		var p = get_piece_at(cell)
		if p and p.team != king.team:
			enemies_nearby.append(p)
			
	# Nếu không có địch thì đứng yên
	if enemies_nearby.size() == 0:
		return king.grid_pos
		
	# Nếu có địch, tìm ô an toàn nhất trong 8 ô
	var best_move = king.grid_pos
	var max_safety_score = -1.0
	
	for move in possible_moves:
		if is_cell_vacant(move):
			# Điểm an toàn = Tổng khoảng cách tới tất cả các quân địch ở gần
			var safety_score = 0.0
			for enemy in enemies_nearby:
				safety_score += move.distance_to(enemy.grid_pos)
			
			if safety_score > max_safety_score:
				max_safety_score = safety_score
				best_move = move
				
	return best_move
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
	# TRƯỜNG HỢP 1: NẾU ĐANG BỊ GRAB
	if bishop.is_grabbed:
		var grabber = bishop.grabbed_by
		if is_instance_valid(grabber):
			# 1. Đòn đánh bật lùi (như đã bàn)
			deal_damage(grabber, 10)
			var push_dir = (grabber.grid_pos - bishop.grid_pos).sign()
			var land_pos = grabber.grid_pos + push_dir
			
			if is_within_board(land_pos) and is_cell_vacant(land_pos):
				move_piece(grabber, land_pos)
			else:
				deal_damage(grabber, 10) # Va chạm
			
			# 2. Giải phóng Grab
			bishop.is_grabbed = false
			grabber.is_grabbed = false
			bishop.grabbed_by = null
			grabber.grabbed_by = null
			
			# 3. DI CHUYỂN ĐẾN VỊ TRÍ AN TOÀN NHẤT
			var safe_pos = find_safest_pos(bishop)
			if safe_pos != bishop.grid_pos:
				move_piece(bishop, safe_pos)
		return

	# TRƯỜNG HỢP 2: TẤN CÔNG TẦM XA (Dấu X)
	var target = find_best_target(bishop)
	if target:
		var diff = target.grid_pos - bishop.grid_pos
		if abs(diff.x) == abs(diff.y):
			deal_damage(target, 35)
			return 

	# TRƯỜNG HỢP 3: DI CHUYỂN BÌNH THƯỜNG
	var next_step = get_next_step_towards(bishop.grid_pos, target.grid_pos)
	if is_cell_vacant(next_step):
		move_piece(bishop, next_step)
func check_and_execute_grab(pawn):
	if pawn.is_grabbed: return 
	
	# Kiểm tra 4 ô xung quanh
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var target_pos = pawn.grid_pos + dir
		var target_unit = get_piece_at(target_pos)
		
		# Điều kiện: Có địch, khác team, không phải Vua
		if target_unit and target_unit.team != pawn.team and not "King" in target_unit.name:
			pawn.is_grabbed = true
			pawn.grabbed_by = target_unit
			target_unit.is_grabbed = true
			target_unit.grabbed_by = pawn
			
			# Hiệu ứng đổi màu để biết là đã Grab thành công
			pawn.modulate = Color(0.5, 0.5, 0.5) 
			target_unit.modulate = Color(0.5, 0.5, 0.5)
			break
func kill_piece(piece):
	# Giải phóng cho đối phương nếu đang bị ôm
	if piece.is_grabbed and is_instance_valid(piece.grabbed_by):
		var partner = piece.grabbed_by
		partner.is_grabbed = false
		partner.grabbed_by = null
	
	# Xóa khỏi mảng quản lý
	if piece in all_pieces:
		all_pieces.erase(piece)
	
	piece.queue_free()
