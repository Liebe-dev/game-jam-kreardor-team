extends Node2D

@export var pawn_scene: PackedScene 
@export var king_scene: PackedScene
@export var knight_scene: PackedScene 
@export var rook_scene: PackedScene   
@export var bishop_scene: PackedScene 
@export var queen_scene: PackedScene
@onready var grid_points = $"../GridPoints"
@onready var btn_attack = $"../CanvasLayer/HBoxContainer/Attack"
@onready var btn_defend = $"../CanvasLayer/HBoxContainer/Defend"
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

func _ready():
	# Tạo một Node2D làm lớp chứa quân cờ nếu chưa có
	piece_layer = Node2D.new()
	piece_layer.name = "PieceLayer"
	add_child(piece_layer)
	
	spawn_initial_army()


func spawn_initial_army():
	create_piece(Vector2i(4, 7), 1, king_scene)
	for i in range(2):
		create_piece(Vector2i(i, 6), 1, pawn_scene)
	create_piece(Vector2i(3, 0), 2, king_scene)
	#for i in range(8):
	create_piece(Vector2i(1, 1), 2, rook_scene)

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
		sprite.modulate = Color(1, 0.4, 0.4)
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
	# Nếu đã đi quân chính rồi thì không cho click nữa
	if has_moved_main_piece:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var clicked_grid = calculate_grid_position(click_pos)
		
		# Bỏ qua nếu người chơi click ra ngoài bàn cờ
		if not is_within_board(clicked_grid): 
			return
			
		var piece_at_click = get_piece_at(clicked_grid)
		
		# Bước 1: Chọn quân của mình (Team 1)
		if piece_at_click and piece_at_click.team == 1:
			selected_piece = piece_at_click
			# Bạn có thể thêm code làm sáng quân cờ được chọn ở đây nếu muốn
			
		# Bước 2: Di chuyển quân đã chọn vào ô trống
		elif selected_piece != null:
			if is_cell_vacant(clicked_grid):
				
				# --- KIỂM TRA ĐIỀU KIỆN 8 Ô XUNG QUANH ---
				var dist_x = abs(clicked_grid.x - selected_piece.grid_pos.x)
				var dist_y = abs(clicked_grid.y - selected_piece.grid_pos.y)
				
				# Nếu khoảng cách trục X và Y đều <= 1, nghĩa là nằm trong 8 ô liền kề
				if dist_x <= 1 and dist_y <= 1:
					
					# Giải thoát trạng thái ôm (nếu có) trước khi di chuyển
					if selected_piece.is_grabbed:
						break_grab(selected_piece)
						
					# Lệnh di chuyển thực tế
					move_piece(selected_piece, clicked_grid)
					selected_piece.has_moved = true
					has_moved_main_piece = true # Khóa lại sau khi đi 1 quân
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
func execute_all_combat_logic():
	for p in all_pieces:
		if not is_instance_valid(p): continue
		
		# KHI BỊ ÔM
		if p.is_grabbed:
			if "Queen" in p.name:
				execute_queen_logic(p) 
			elif "Knight" in p.name:
				execute_knight_logic(p) 
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
				p.has_moved = true # Đánh dấu dùng lượt để nạp
				if p.has_method("update_visuals"):
					p.update_visuals()
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
	if not rook.is_charging:
		return
		
	# Tầm nhìn hình dấu + (Lên, Xuống, Trái, Phải)
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		# Xe quét xa 3 ô theo đường thẳng (vì đòn đánh của bạn lan 3 ô)
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
					return # Chỉ tấn công 1 lần mỗi lượt
				else:
					# Nếu đụng quân mình cản đường đạn -> Không bắn xuyên qua đồng đội được
					break
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
	piece.modulate = Color(1, 1, 1) if piece.team == 1 else Color(1, 0.4, 0.4)
	
	# 2. Tìm TẤT CẢ những kẻ đang bám lấy quân này và đá văng chúng ra
	for p in all_pieces:
		if is_instance_valid(p) and p.grabbed_by == piece:
			p.is_grabbed = false
			p.grabbed_by = null
			# Trả lại màu Trắng cho phe ta, màu Đỏ cho phe địch
			p.modulate = Color(1, 1, 1) if p.team == 1 else Color(1, 0.4, 0.4)
func kill_piece(piece):
	# Giải phóng cho TẤT CẢ đối phương đang ôm quân này
	for p in all_pieces:
		if is_instance_valid(p) and p.grabbed_by == piece:
			p.is_grabbed = false
			p.grabbed_by = null
			p.modulate = Color(1, 1, 1) if p.team == 1 else Color(1, 0.4, 0.4)
	
	# Xóa khỏi mảng quản lý và tiêu hủy
	if piece in all_pieces:
		all_pieces.erase(piece)
	
	piece.queue_free()
