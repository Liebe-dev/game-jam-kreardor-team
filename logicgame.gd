extends Node2D

@export var move_indicator_scene: PackedScene
@export var endgame_menu: Control 
@export var endgame_title: Label  # Chỗ chứa dòng chữ "Thắng" hoặc "Thua"

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
@onready var wave_label = $"../CanvasLayer/WaveLabel"
@onready var turn_label = $"../CanvasLayer/TurnLabel"

var current_turn = 1
enum Command { ATTACK, DEFEND, IDLE }
var current_command = Command.IDLE # Mặc định là đứng im

var has_moved_main_piece = false # Kiểm tra xem lượt này đã đi quân chính chưa
var piece_layer: Node2D 
var all_pieces = []
var selected_piece = null 
var is_player_turn = true     
var board_origin = Vector2(450, 250) 
var cell_size = 80
var player_unit # Biến lưu trữ quân cờ của người chơi

func _ready():
	# Giả sử bạn tìm quân cờ người chơi thông qua nhóm "player"
	player_unit = get_tree().get_first_node_in_group("player")
	if wave_label:
		# Lấy biến current_wave từ file Global đắp vào Label
		wave_label.text = "Wave: " + str(Global.current_wave)
	# Tạo một Node2D làm lớp chứa quân cờ nếu chưa có
	piece_layer = Node2D.new()
	piece_layer.name = "PieceLayer"
	add_child(piece_layer)
	
	spawn_initial_army()

func is_within_board(pos: Vector2i) -> bool:
	# Giả sử bàn cờ của bạn là 8x8 (từ ô 0 đến 7)
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

# --- CƠ CHẾ WAVE ---

# 1. Hàm đếm số địch còn sống trên bàn cờ
func count_enemies_alive() -> int:
	var enemy_count = 0
	for p in all_pieces:
		# Kẻ nào thuộc Team 2 thì chắc chắn là địch!
		if is_instance_valid(p) and p.team == 2:
			enemy_count += 1
	return enemy_count
# --- HÀM 1: CHUYỂN WAVE VÀ BƠM MÁU/HỒI SINH ---
func transition_to_next_wave():
	# 1. RESET THÔNG SỐ WAVE & TURN
	Global.current_wave += 1
	current_turn = 1 # Reset bộ đếm lượt về 1
	
	# Cập nhật UI (nếu bạn có các Label này)
	if wave_label: wave_label.text = "Wave: " + str(Global.current_wave)
	if turn_label: turn_label.text = "Turn: 1"
		
	# 2. DỌN SẠCH QUÂN ĐỊCH CŨ (Team 2)
	# Bạn có thể gọi hàm clear_old_enemies() nếu đã viết riêng, hoặc dùng đoạn này:
	for i in range(all_pieces.size() - 1, -1, -1):
		var p = all_pieces[i]
		if is_instance_valid(p) and p.team == 2:
			all_pieces.remove_at(i)
			p.queue_free()

	# 3. SẮP XẾP LẠI QUÂN TA (Team 1) - GIỮ MÁU & HỒI MÁU
	var current_pawns = []
	var king_piece = null
	
	# Phân loại quân ta đang có trên sân
	for p in all_pieces:
		if is_instance_valid(p) and p.team == 1:
			if "King" in p.name:
				king_piece = p
			else:
				current_pawns.append(p)
	
	# Duyệt qua 8 vị trí hàng ngang mặc định (hàng 6)
	for i in range(8):
		if i < current_pawns.size():
			# --- LÍNH CÒN SỐNG: NHẤC VỀ & CỘNG THÊM 30 MÁU ---
			var p = current_pawns[i]
			p.grid_pos = Vector2i(i, 6)
			p.position = grid_to_pixel(p.grid_pos)
			
			if "hp" in p:
				p.hp += 30 # Hồi thêm 30 máu cho lính sống sót
				# Cập nhật thanh máu (mở rộng max_value nếu máu vượt ngưỡng)
				if p.has_node("HealthBar"):
					var bar = p.get_node("HealthBar")
					bar.max_value = max(bar.max_value, p.hp)
					bar.value = p.hp
		else:
			# --- LÍNH ĐÃ CHẾT: HỒI SINH MỚI VỚI 20 MÁU ---
			var new_pawn = player_pawn_scene.instantiate()
			new_pawn.team = 1
			piece_layer.add_child(new_pawn)
			all_pieces.append(new_pawn)
			
			new_pawn.set("hp", 20) # Hồi sinh lính chết với 20 máu
			new_pawn.grid_pos = Vector2i(i, 6)
			new_pawn.position = grid_to_pixel(new_pawn.grid_pos)
			
			if new_pawn.has_node("HealthBar"):
				new_pawn.get_node("HealthBar").max_value = 50 
				new_pawn.get_node("HealthBar").value = 20

	# 4. ĐƯA VUA VỀ VỊ TRÍ CŨ
	if is_instance_valid(king_piece):
		king_piece.grid_pos = Vector2i(3, 7)
		king_piece.position = grid_to_pixel(king_piece.grid_pos)

	# 5. GỌI QUÂN ĐỊCH WAVE MỚI
	spawn_enemy_wave()
	
	# 6. XOAY TẤT CẢ MẶT LÊN TRÊN (Sau khi lính đã xuất hiện)
	await get_tree().process_frame
	for p in all_pieces:
		if is_instance_valid(p) and p.has_node("Sprite2D"):
			var sprite = p.get_node("Sprite2D")
			# Giả sử hình quay lưng nằm ở tọa độ y = 64 trên Sprite Sheet
			# Bạn hãy kiểm tra thông số Region trong Inspector của Pawn để điền số đúng
			sprite.region_rect = Rect2(0, 64, 64, 64)

# --- HÀM 2: CÔNG TẮC KIỂM TRA ĐIỀU KIỆN ---
func check_and_trigger_next_wave():
	if Global.current_wave >= 5:
		trigger_victory()
		return 
		
	transition_to_next_wave()

func spawn_initial_army():
	if Global.current_wave == 1:
		for i in range(8):
			var pawn = player_pawn_scene.instantiate()
			pawn.team = 1 # <--- THÊM DÒNG NÀY (Để game biết đây là quân ta)
			piece_layer.add_child(pawn)
			all_pieces.append(pawn)
			pawn.grid_pos = Vector2(i, 6)
			if has_method("grid_to_pixel"): pawn.position = grid_to_pixel(Vector2(i, 6))
			
		if player_king_scene:
			var king = player_king_scene.instantiate()
			king.team = 1 # <--- THÊM DÒNG NÀY (Để game biết Vua cũng là quân ta)
			piece_layer.add_child(king)
			all_pieces.append(king)
			king.grid_pos = Vector2(3, 7) 
			if has_method("grid_to_pixel"): king.position = grid_to_pixel(Vector2(3, 7))

		spawn_enemy_wave()

func spawn_enemy_wave():
	var wave_setup = []
	
	match Global.current_wave:
		1: 
			wave_setup = [
				{"scene": enemy_pawn_scene, "pos": Vector2(1, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(3, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(5, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(7, 1)}
			]
		2: 
			for i in range(8):
				wave_setup.append({"scene": enemy_pawn_scene, "pos": Vector2(i, 1)})
		3: 
			wave_setup = [
				{"scene": enemy_bishop_scene, "pos": Vector2(2, 0)},
				{"scene": enemy_bishop_scene, "pos": Vector2(5, 0)},
				{"scene": enemy_knight_scene, "pos": Vector2(3, 0)},
				{"scene": enemy_knight_scene, "pos": Vector2(4, 0)}
			]
		4: 
			wave_setup = [
				{"scene": enemy_rook_scene, "pos": Vector2(0, 0)},
				{"scene": enemy_rook_scene, "pos": Vector2(7, 0)},
				{"scene": enemy_pawn_scene, "pos": Vector2(2, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(3, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(4, 1)},
				{"scene": enemy_pawn_scene, "pos": Vector2(5, 1)}
			]
		5: 
			wave_setup = [
				{"scene": enemy_queen_scene, "pos": Vector2(3, 0)},
				{"scene": enemy_queen_scene, "pos": Vector2(4, 0)},
				{"scene": enemy_rook_scene, "pos": Vector2(0, 0)},
				{"scene": enemy_rook_scene, "pos": Vector2(7, 0)},
				{"scene": enemy_knight_scene, "pos": Vector2(1, 0)},
				{"scene": enemy_knight_scene, "pos": Vector2(6, 0)},
				{"scene": enemy_bishop_scene, "pos": Vector2(2, 0)},
				{"scene": enemy_bishop_scene, "pos": Vector2(5, 0)},
				{"scene": enemy_pawn_scene, "pos": Vector2(2, 1)}, 
				{"scene": enemy_pawn_scene, "pos": Vector2(5, 1)}  
			]
			
	for data in wave_setup:
		if data["scene"] == null: continue
		var enemy = data["scene"].instantiate()
		enemy.team = 2 # <--- THÊM DÒNG NÀY (Để game biết đây là quân địch)
		piece_layer.add_child(enemy)
		all_pieces.append(enemy)
		enemy.grid_pos = data["pos"]
		if has_method("grid_to_pixel"):
			enemy.position = grid_to_pixel(data["pos"])
func create_piece(grid_pos: Vector2i, team: int, scene: PackedScene):
	if scene == null: return 
	
	var new_unit = scene.instantiate()
	new_unit.team = team
	new_unit.grid_pos = grid_pos
	
	if scene == player_king_scene:
		new_unit.name = "King_" + str(team)
	elif scene == enemy_rook_scene:
		new_unit.name = "Rook_" + str(team)
	elif scene == enemy_queen_scene:
		new_unit.name = "Queen_" + str(team)
	elif scene == enemy_knight_scene:
		new_unit.name = "Knight_" + str(team)
	elif scene == enemy_bishop_scene:
		new_unit.name = "Bishop_" + str(team)
	else:
		new_unit.name = "Pawn_" + str(team)
		
	piece_layer.add_child(new_unit)
	new_unit.global_position = calculate_world_position(grid_pos)
	
	var sprite = new_unit.get_node("Sprite2D")
	
	if team == 1:
		sprite.frame = 3
	elif team == 2:
		sprite.frame = 0
		if new_unit.has_node("HealthBar"):
			new_unit.get_node("HealthBar").modulate = Color(1, 0, 0)
			
	all_pieces.append(new_unit)

func deal_damage(target, amount):
	if not is_instance_valid(target):
		return
		
	if amount <= 0: return
	
	if target.has_method("take_damage"):
		target.take_damage(amount)

func _input(event):
	if has_moved_main_piece: return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var clicked_grid = calculate_grid_position(click_pos)
		
		if not is_within_board(clicked_grid): return
			
		var piece_at_click = get_piece_at(clicked_grid)
		
		if piece_at_click and piece_at_click.team == 1:
			selected_piece = piece_at_click
			show_highlights(selected_piece) 
			
		elif selected_piece != null:
			var valid_moves = get_valid_moves(selected_piece)
			if clicked_grid in valid_moves:
				if selected_piece.is_grabbed:
					break_grab(selected_piece)
						
				move_piece(selected_piece, clicked_grid)
				selected_piece.has_moved = true
				has_moved_main_piece = true
				
				clear_highlights() 
				selected_piece = null
			else:
				clear_highlights()
				selected_piece = null

func get_piece_at(grid_pos: Vector2i):
	for p in all_pieces:
		if is_instance_valid(p) and p.grid_pos == grid_pos:
			return p
	return null

func is_cell_vacant(grid_pos: Vector2i) -> bool:
	return get_piece_at(grid_pos) == null

func move_piece(piece, target_grid: Vector2i):
	if piece.is_grabbed:
		return
	var target_world = calculate_world_position(target_grid)
	if piece.has_method("move_to_grid"):
		piece.move_to_grid(target_grid, target_world)
	else:
		piece.grid_pos = target_grid
		piece.global_position = target_world
		
	check_and_execute_grab(piece)

func find_my_king(my_team: int):
	for p in all_pieces:
		if is_instance_valid(p) and p.team == my_team and "King" in p.name:
			return p
	return null

func queen_grab_counter(queen):
	var grabber = queen.grabbed_by 
	
	if is_instance_valid(grabber):
		var aim_dir = grabber.grid_pos - queen.grid_pos
		var sprite = queen.get_node_or_null("Sprite2D")
		if sprite:
			if abs(aim_dir.x) > abs(aim_dir.y):
				sprite.frame = 1 if aim_dir.x > 0 else 2 
			else:
				sprite.frame = 0 if aim_dir.y > 0 else 3 
				
	var target_to_hit = queen.grabbed_by
	if not is_instance_valid(target_to_hit): return
	
	var dir_to_grabber = target_to_hit.grid_pos - queen.grid_pos
	var side_dirs = [
		Vector2i(-dir_to_grabber.y, dir_to_grabber.x),
		Vector2i(dir_to_grabber.y, -dir_to_grabber.x)
	]
	
	deal_damage(target_to_hit, 35)
	
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
				break 
	return closest_target

func _on_attack_pressed():
	if current_command == Command.ATTACK:
		current_command = Command.IDLE
		btn_attack.modulate = Color(1, 1, 1) 
	else:
		current_command = Command.ATTACK
		btn_attack.modulate = Color(1, 0.5, 0.5) 
		btn_defend.modulate = Color(1, 1, 1)     

func _on_defend_pressed():
	if current_command == Command.DEFEND:
		current_command = Command.IDLE
		btn_defend.modulate = Color(1, 1, 1)
	else:
		current_command = Command.DEFEND
		btn_defend.modulate = Color(0.5, 0.5, 1) 
		btn_attack.modulate = Color(1, 1, 1)     

func _on_end_turn_pressed():
	move_team_logic(1)
	await get_tree().create_timer(0.3).timeout
	move_team_logic(2)
	await get_tree().create_timer(0.2).timeout 
func _on_spell_button_pressed():
	%MagicDrawingSystem.show() # Sửa lại chữ M và D viết hoa
	# Có thể thêm logic tạm dừng bàn cờ tại đây nếu cần

	for p in all_pieces:
		if is_instance_valid(p):
			check_and_execute_grab(p)
			
	execute_all_combat_logic()
	
	for p in all_pieces:
		if is_instance_valid(p):
			p.has_moved = false
	has_moved_main_piece = false
	selected_piece = null
	current_turn += 1
	if turn_label:
		turn_label.text = "Turn: " + str(current_turn)
	process_ammo_reloads()

	# Sau khi đánh nhau xong, đếm xem địch còn mống nào không
	if count_enemies_alive() <= 0:
		check_and_trigger_next_wave()
func execute_all_combat_logic():
	for p in all_pieces:
		if not is_instance_valid(p): continue
		
		# --- KHI ĐANG TÚM CỔ NHAU (Cận chiến) ---
		if p.is_grabbed:
			# Chuyển tên thành chữ thường hết để không bao giờ bị lỗi Hoa/Thường nữa
			var p_name = p.name.to_lower() 
			
			if "queen" in p_name:
				queen_grab_counter(p) # (Tôi đã sửa lại hàm cận chiến của Hậu cho bạn luôn ở đây)
			elif "knight" in p_name:
				execute_knight_logic(p) 
			elif "bishop" in p_name:         
				execute_bishop_logic(p)
			else: 
				# NẾU LÀ LÍNH THƯỜNG (Hoặc Vua): Cứ bị tóm là chém trả 10 máu!
				if is_instance_valid(p.grabbed_by):
					deal_damage(p.grabbed_by, 10)
		
		# --- KHI ĐỨNG TỰ DO (Đánh xa) ---
		else:
			var p_name = p.name.to_lower()
			if "rook" in p_name:
				execute_rook_logic(p)
			elif "bishop" in p_name:
				execute_bishop_logic(p)
func move_team_logic(team_num: int):
	for p in all_pieces:
		if not is_instance_valid(p) or p.team != team_num: continue
		if p.is_grabbed or "King" in p.name: continue 
		if p.has_moved: continue

		if "Rook" in p.name:
			if not p.is_charging:
				p.is_charging = true
				p.has_moved = true
				p.set_meta("just_charged", true) 
				if p.has_method("update_visuals"): p.update_visuals()
				continue
				
		if team_num == 1:
			if current_command == Command.IDLE: continue 
			elif current_command == Command.DEFEND:
				var king_target = find_my_king(1)
				if king_target:
					var next = get_next_step_towards(p.grid_pos, king_target.grid_pos)
					if is_cell_vacant(next): move_piece(p, next)
				continue

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
			
			var target = find_best_target(p)
			if target:
				var next = get_next_step_towards(p.grid_pos, target.grid_pos)
				if is_cell_vacant(next): move_piece(p, next)

func find_best_target(for_piece):
	var enemy_king = null
	var enemy_soldiers = []
	
	for p in all_pieces:
		if is_instance_valid(p) and p.team != for_piece.team:
			if "King" in p.name: 
				enemy_king = p
			else:
				enemy_soldiers.append(p)
				
	if for_piece.team == 1:
		if enemy_soldiers.size() > 0:
			return get_closest(for_piece, enemy_soldiers)
		return enemy_king
	else:
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

func get_next_step_towards(start: Vector2i, target: Vector2i) -> Vector2i:
	var diff = target - start
	var step = Vector2i(0, 0)
	
	if abs(diff.y) > 0:
		step.y = sign(diff.y)
	elif abs(diff.x) > 0:
		step.x = sign(diff.x)
		
	return start + step

func execute_queen_logic(queen):
	if queen.is_reloading:
		return 

	var target = find_queen_ranged_target(queen) 
	if target:
		create_projectile_effect(queen.global_position, target.global_position)
		deal_damage(target, 25)

		queen.current_ammo -= 1
		if queen.has_node("AmmoBar"):
			queen.get_node("AmmoBar").value = queen.current_ammo
			
		if queen.current_ammo <= 0:
			queen.is_reloading = true
			queen.reload_turns_left = 2

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
	var forward = Vector2i(sign(dir.x), sign(dir.y))
	var side = Vector2i(-forward.y, forward.x) 
	
	var sprite = rook.get_node_or_null("Sprite2D")
	if sprite:
		if forward.x > 0: sprite.frame = 1      
		elif forward.x < 0: sprite.frame = 2    
		elif forward.y > 0: sprite.frame = 0    
		elif forward.y < 0: sprite.frame = 3    
		
	for i in range(1, 4):
		var pos = rook.grid_pos + forward * i
		var unit = get_piece_at(pos)
		if unit and unit.team != rook.team:
			deal_damage(unit, 20)
			apply_knockback(unit, forward, 3, 15)
			
	var sides = [rook.grid_pos + side, rook.grid_pos - side]
	for s_pos in sides:
		var unit = get_piece_at(s_pos)
		if unit and unit.team != rook.team:
			deal_damage(unit, 10)

	var back_pos = rook.grid_pos - forward 
	
	if not is_within_board(back_pos):
		deal_damage(rook, 5)
	elif not is_cell_vacant(back_pos):
		var back_unit = get_piece_at(back_pos)
		deal_damage(rook, 5)
		deal_damage(back_unit, 5)
	else:
		move_piece(rook, back_pos)

func execute_rook_logic(rook):
	if not rook.is_charging:
		return
		
	if rook.has_meta("just_charged") and rook.get_meta("just_charged") == true:
		rook.set_meta("just_charged", false)
		return
		
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		for i in range(1, 4):
			var check_pos = rook.grid_pos + (dir * i)
			
			if not is_within_board(check_pos):
				break 
				
			var target = get_piece_at(check_pos)
			if target:
				if target.team != rook.team:
					execute_rook_attack(rook, target)
					rook.is_charging = false
					if rook.has_method("update_visuals"):
						rook.update_visuals()
					return 
				else:
					break 

	var best_target = find_best_target(rook)
	if best_target:
		var next_step = get_next_step_towards(rook.grid_pos, best_target.grid_pos)
		if is_cell_vacant(next_step):
			move_piece(rook, next_step)

func execute_knight_logic(knight):
	if knight.is_grabbed:
		var grabber = knight.grabbed_by
		if is_instance_valid(grabber):
			deal_damage(grabber, 15)
			
			var push_dir = (grabber.grid_pos - knight.grid_pos).sign()
			
			var _sprite = knight.get_node_or_null("Sprite2D")
			if _sprite:
				if push_dir.x > 0: _sprite.frame = 1      
				elif push_dir.x < 0: _sprite.frame = 2    
				elif push_dir.y > 0: _sprite.frame = 0    
				elif push_dir.y < 0: _sprite.frame = 3    
					
			knight.is_grabbed = false
			grabber.is_grabbed = false
			knight.grabbed_by = null
			grabber.grabbed_by = null
			
			knight.modulate = Color(1, 1, 1)
			if grabber.has_method("update_visuals"):
				grabber.update_visuals()
			
			var hit = apply_knockback(grabber, push_dir, 2, 20)
			
			if hit:
				deal_damage(knight, 10) 
		return
		
	var target = find_best_target(knight)
	if target:
		var diff = target.grid_pos - knight.grid_pos
		if (abs(diff.x) == 2 and abs(diff.y) == 1) or (abs(diff.x) == 1 and abs(diff.y) == 2):
			deal_damage(target, 30)
			
			var retreat_dir = (knight.grid_pos - target.grid_pos).sign()
			var safe_pos = knight.grid_pos + (retreat_dir * 2)
			
			if is_within_board(safe_pos) and is_cell_vacant(safe_pos):
				move_piece(knight, safe_pos)
			return

	var l_moves = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
		Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)
	]
	
	var best_pos = knight.grid_pos
	var min_dist = 9999
	
	for move in l_moves:
		var test_pos = knight.grid_pos + move
		
		if is_within_board(test_pos) and is_cell_vacant(test_pos):
			var dist = abs(target.grid_pos.x - test_pos.x) + abs(target.grid_pos.y - test_pos.y)
			
			if dist < min_dist:
				min_dist = dist
				best_pos = test_pos
				
	var sprite = knight.get_node_or_null("Sprite2D")
	if sprite and best_pos != knight.grid_pos:
		var dir = best_pos - knight.grid_pos
		if abs(dir.x) > abs(dir.y):
			sprite.frame = 1 if dir.x > 0 else 2 
		else:
			sprite.frame = 0 if dir.y > 0 else 3 
			
	if best_pos != knight.grid_pos:
		move_piece(knight, best_pos)

func find_safest_pos(piece):
	var best_pos = piece.grid_pos
	var max_score = -1.0
	
	var threat = find_best_target(piece)
	if not threat: return piece.grid_pos
	
	for x in range(-2, 3):
		for y in range(-2, 3):
			var test_pos = piece.grid_pos + Vector2i(x, y)
			
			if is_within_board(test_pos) and is_cell_vacant(test_pos):
				var score = test_pos.distance_to(threat.grid_pos)
				if score > max_score:
					max_score = score
					best_pos = test_pos
					
	return best_pos

func execute_bishop_logic(bishop):
	if bishop.is_grabbed:
		var grabber = bishop.grabbed_by
		if is_instance_valid(grabber):
			deal_damage(grabber, 10) 
			
			var push_dir = (grabber.grid_pos - bishop.grid_pos).sign()
			
			bishop.is_grabbed = false
			grabber.is_grabbed = false
			bishop.grabbed_by = null
			grabber.grabbed_by = null
			
			apply_knockback(grabber, push_dir, 1, 5)
		return
		
	var diag_dirs = [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	var attacked = false
	
	for dir in diag_dirs:
		for i in range(1, 3): 
			var check_pos = bishop.grid_pos + (dir * i)
			
			if not is_within_board(check_pos): 
				break 
				
			var unit = get_piece_at(check_pos)
			if unit:
				if unit.team != bishop.team:
					create_projectile_effect(bishop.global_position, unit.global_position)
					deal_damage(unit, 35)
					attacked = true
					
					var csprite = bishop.get_node_or_null("Sprite2D")
					if csprite:
						if dir.x > 0: csprite.frame = 1
						elif dir.x < 0: csprite.frame = 2
						elif dir.y > 0: csprite.frame = 0
						elif dir.y < 0: csprite.frame = 3
				break 
				
		if attacked: return 

	var target = find_best_target(bishop)
	if not target: return
	
	var possible_moves = []
	for step in diag_dirs:
		var test_pos = bishop.grid_pos + step
		if is_within_board(test_pos) and is_cell_vacant(test_pos):
			possible_moves.append(test_pos)
			
	var best_move = bishop.grid_pos
	var best_score = 9999
	
	for move in possible_moves:
		var test_diff = target.grid_pos - move
		var deviation = abs(abs(test_diff.x) - abs(test_diff.y)) 
		var dist = abs(test_diff.x) + abs(test_diff.y)
		var score = (deviation * 10) + dist 
		
		if score < best_score:
			best_score = score
			best_move = move
			
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
	if "King" in pawn.name: return 
	if pawn.is_grabbed: return 
	
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var possible_targets = []
	
	for dir in directions:
		var target_pos = pawn.grid_pos + dir
		var target_unit = get_piece_at(target_pos)
		
		if target_unit and target_unit.team != pawn.team:
			possible_targets.append(target_unit)
			
	if possible_targets.size() == 0: return
	
	var soldier_targets = []
	for t in possible_targets:
		if not "King" in t.name:
			soldier_targets.append(t)
			
	var chosen_target = null
	if soldier_targets.size() > 0:
		chosen_target = soldier_targets.pick_random() 
	else:
		chosen_target = possible_targets.pick_random() 
		
	pawn.is_grabbed = true
	pawn.grabbed_by = chosen_target
	
	chosen_target.is_grabbed = true
	if chosen_target.grabbed_by == null:
		chosen_target.grabbed_by = pawn
	
	if pawn.has_method("update_visuals"): pawn.update_visuals()
	if chosen_target.has_method("update_visuals"): chosen_target.update_visuals()
	
	var face_dir = chosen_target.grid_pos - pawn.grid_pos
	var sprite = pawn.get_node_or_null("Sprite2D")
	if sprite:
		if face_dir.x > 0: sprite.frame = 1     
		elif face_dir.x < 0: sprite.frame = 2   
		elif face_dir.y > 0: sprite.frame = 0   
		elif face_dir.y < 0: sprite.frame = 3   
		
	chosen_target.modulate = Color(0.5, 0.5, 0.5)

func break_grab(piece):
	piece.is_grabbed = false
	piece.grabbed_by = null
	if piece.has_method("update_visuals"): piece.update_visuals()
	
	for p in all_pieces:
		if is_instance_valid(p) and p.grabbed_by == piece:
			p.is_grabbed = false
			p.grabbed_by = null
			if p.has_method("update_visuals"): p.update_visuals()

func kill_piece(piece):
	for p in all_pieces:
		if is_instance_valid(p) and p.grabbed_by == piece:
			p.is_grabbed = false
			p.grabbed_by = null
			if p.has_method("update_visuals"): p.update_visuals()
	
	if piece in all_pieces:
		all_pieces.erase(piece)
	
	piece.queue_free()

func apply_knockback(unit, push_dir: Vector2i, max_dist: int, impact_damage: int) -> bool:
	if not is_instance_valid(unit): return false
	
	var current_grid = unit.grid_pos
	var hit_obstacle = false
	
	for i in range(1, max_dist + 1):
		var next_grid = current_grid + push_dir
		
		if not is_within_board(next_grid):
			hit_obstacle = true
			break
			
		if not is_cell_vacant(next_grid):
			hit_obstacle = true
			var obstacle = get_piece_at(next_grid)
			if is_instance_valid(obstacle):
				deal_damage(obstacle, impact_damage) 
			break
			
		current_grid = next_grid
		
	if current_grid != unit.grid_pos:
		move_piece(unit, current_grid)
		
	if hit_obstacle:
		deal_damage(unit, impact_damage) 
		
	return hit_obstacle

func create_projectile_effect(start_pos: Vector2, end_pos: Vector2):
	var bullet = ColorRect.new()
	bullet.color = Color.YELLOW 
	bullet.size = Vector2(15, 15)
	
	bullet.global_position = start_pos - (bullet.size / 2)
	add_child(bullet)
	
	var t = create_tween()
	t.tween_property(bullet, "global_position", end_pos - (bullet.size / 2), 0.2)
	
	t.tween_callback(bullet.queue_free)

func get_valid_moves(piece) -> Array:
	var moves = []
	var directions = []
	var max_dist = 1 

	if "Knight" in piece.name:
		var l_moves = [Vector2i(1,2), Vector2i(2,1), Vector2i(-1,2), Vector2i(-2,1),
					   Vector2i(1,-2), Vector2i(2,-1), Vector2i(-1,-2), Vector2i(-2,-1)]
		for m in l_moves:
			var target = piece.grid_pos + m
			if is_within_board(target) and is_cell_vacant(target): moves.append(target)
		return moves 

	if "Rook" in piece.name:
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		max_dist = 3 
	elif "Bishop" in piece.name:
		directions = [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = 2 
	elif "Queen" in piece.name:
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
					  Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = 8 
	else: 
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
					  Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = 1

	for d in directions:
		for i in range(1, max_dist + 1):
			var target = piece.grid_pos + d * i
			if is_within_board(target) and is_cell_vacant(target):
				moves.append(target)
			else:
				break 
	return moves

func clear_highlights():
	for indicator in active_indicators:
		indicator.queue_free()
	active_indicators.clear()
	
	for p in all_pieces:
		if is_instance_valid(p) and p.has_node("Selector"):
			p.get_node("Selector").visible = false

func show_highlights(piece):
	clear_highlights()
	
	if piece.has_node("Selector"):
		piece.get_node("Selector").visible = true
		
	var moves = get_valid_moves(piece)
	for m_pos in moves:
		if move_indicator_scene:
			var indicator = move_indicator_scene.instantiate()
			add_child(indicator)
			indicator.global_position = calculate_world_position(m_pos)
			active_indicators.append(indicator)

func process_ammo_reloads():
	for p in all_pieces:
		if is_instance_valid(p) and "Queen" in p.name:
			if p.is_reloading:
				p.reload_turns_left -= 1
				
				if p.reload_turns_left <= 0:
					p.is_reloading = false
					p.current_ammo = p.max_ammo 
					
					if p.has_node("AmmoBar"):
						p.get_node("AmmoBar").value = p.current_ammo

# Kiểm tra xem một ô trên lưới có trống hay không
func is_cell_empty(grid_pos: Vector2i) -> bool:
	# 1. Kiểm tra xem có nằm trong phạm vi bàn cờ không (giả sử 8x8)
	if grid_pos.x < 0 or grid_pos.x >= 8 or grid_pos.y < 0 or grid_pos.y >= 8:
		return false
	# 2. Kiểm tra xem có quân cờ nào đang đứng ở đó không
	return get_unit_at(grid_pos) == null

# Thực hiện di chuyển quân cờ và cập nhật vị trí logic
func move_unit_to(unit, new_grid_pos: Vector2i):
	if unit and unit.has_method("set_grid_position"):
		unit.set_grid_position(new_grid_pos)
		# Cập nhật vị trí thực tế trên màn hình (World Position)
		# Giả sử bạn có hàm Global.calculate_world_position từ ảnh image_fd39e1.png
		unit.global_position = Global.calculate_world_position(new_grid_pos)
		print("Đã di chuyển đơn vị tới: ", new_grid_pos)
func grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	var target_grid = grid_points
	if target_grid == null:
		target_grid = get_parent().get_node_or_null("GridPoints")
		
	if target_grid == null: return Vector2.ZERO
		
	# ÉP BUỘC THỨ TỰ TÊN NÚT LÀ: "Y X" (Dọc trước, Ngang sau)
	var marker_name = str(int(grid_pos.y)) + " " + str(int(grid_pos.x))
	
	for child in target_grid.get_children():
		if child.name.strip_edges() == marker_name:
			return child.global_position
			
	return Vector2.ZERO

# --- HÀM 2: CLICK CHUỘT ---
func pixel_to_grid(mouse_pixel_pos: Vector2) -> Vector2i:
	var target_grid = grid_points
	if target_grid == null:
		target_grid = get_parent().get_node_or_null("GridPoints")
		
	if not target_grid: return Vector2i(-1, -1)
	
	var closest_grid = Vector2i(-1, -1)
	var min_dist = 999999.0
	
	for marker in target_grid.get_children():
		var dist = mouse_pixel_pos.distance_to(marker.global_position)
		if dist < min_dist:
			min_dist = dist
			
			var clean_name = marker.name.strip_edges()
			var parts = clean_name.split(" ", false) 
			
			if parts.size() >= 2:
				# Trả về tọa độ cờ: Ngang (X) là số thứ hai, Dọc (Y) là số đầu tiên
				closest_grid = Vector2i(int(parts[1]), int(parts[0])) 
				
	if min_dist > 60: 
		return Vector2i(-1, -1)
		
	return closest_grid
# --- 3. GỘP CÁC HÀM CŨ ĐỂ KHÔNG BỊ "ĐÁ" NHAU ---
func calculate_world_position(grid_pos: Vector2i) -> Vector2:
	return grid_to_pixel(grid_pos)

func calculate_grid_position(world_pos: Vector2) -> Vector2i:
	return pixel_to_grid(world_pos)
func trigger_game_over():
	if endgame_menu:
		endgame_menu.visible = true
		if endgame_title:
			endgame_title.text = "VUA ĐÃ BĂNG HÀ!\nTHẤT BẠI"
			endgame_title.modulate = Color(1, 0, 0) 

func trigger_victory():
	if endgame_menu:
		endgame_menu.visible = true
		if endgame_title:
			endgame_title.text = "VƯỢT QUA WAVE 5!\nCHIẾN THẮNG"
			endgame_title.modulate = Color(1, 1, 0)

func clear_old_enemies():
	# Duyệt ngược mảng để xóa không bị sót
	for i in range(all_pieces.size() - 1, -1, -1):
		var p = all_pieces[i]
		if is_instance_valid(p) and p.team == 2: # Nếu là lính địch (Team 2)
			all_pieces.remove_at(i) # Xóa khỏi danh sách quản lý
			p.queue_free() # Xóa khỏi màn hình

func get_unit_at(grid_pos: Vector2i):
	# Duyệt qua tất cả các quân cờ đang có trên bàn cờ
	# Giả sử các quân cờ nằm trong một nhóm tên là "units"
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.grid_position == grid_pos:
			return unit
	return null
func cast_spell(element_type):
	# 1. Tìm tên file scene cần load từ Dictionary
	var scene_name = SpellDictionary.get_spell_scene_name(element_type)
	
	# 2. Load file .tscn tương ứng
	var spell_path = "res://spells/" + scene_name + ".tscn"
	var spell_resource = load(spell_path)
	
	if spell_resource:
		var spell_instance = spell_resource.instantiate()
		
		# 3. Đặt vị trí xuất phát (vị trí người chơi hoặc tọa độ đã vẽ)
		spell_instance.position = $Player.position 
		
		# 4. Thêm phép vào bàn cờ
		add_child(spell_instance)
		
		# 5. Áp dụng hiệu ứng dựa trên thiết kế của bạn
		apply_spell_effects(element_type, spell_instance)
func get_first_unit_in_direction(start_pos: Vector2i, direction: Vector2i, max_range: int):
	for i in range(1, max_range + 1):
		var check_pos = start_pos + (direction * i)
		var unit = get_unit_at(check_pos) # Hàm get_unit_at bạn đã thêm trước đó
		if unit:
			return unit
	return null
func apply_spell_effects(element, _instance):
	match element:
		SpellDictionary.Element.FIRE:
			print("Gây sát thương 1 lần lên 1 ô")
		SpellDictionary.Element.WATER:
			print("Hồi máu và nhận mực")
		SpellDictionary.Element.EARTH:
			print("Miễn nhiễm sát thương và nhận 3 giấy")
		SpellDictionary.Element.WIND:
			print("Mục tiêu tấn công 2 lần vào lượt sau")

# logicgame.gd

func execute_spell_logic(element_type, target_unit, multiplier, is_multi, is_boosted):
	if is_boosted:
		# Nếu là Ấn gia cường, gọi hàm xử lý đặc biệt
		execute_boosted_logic(element_type, target_unit)
	else:
		# Nếu là Ấn đơn, chạy logic bình thường (có tính multiplier nếu 2 vị trí)
		execute_standard_logic(element_type, target_unit, multiplier, is_multi)
# --- Hệ LỬA (Fire) ---
func execute_fire_logic(target_unit, multiplier):
	if target_unit:
		# Gốc 35 dmg -> Multiplier 0.4 (nếu 2 ô) = 14 dmg
		var final_damage = 35 * multiplier
		target_unit.take_damage(final_damage)
func execute_fire_boosted(target_unit):
	if target_unit:
		# Gốc 35 + 50% = 52.5 sát thương
		target_unit.take_damage(52.5)
		# Tạo ô lửa tại vị trí đó tồn tại 2 lượt
		create_tile_effect(target_unit.grid_position, "fire_zone", 2)
# logicgame.gd

func create_tile_effect(grid_pos: Vector2i, type: String, duration: int, _directions: Array = []):

	print("Tạo hiệu ứng ", type, " tại ", grid_pos, " tồn tại ", duration, " lượt.")

func execute_earth_logic(target_unit, multiplier):
	if target_unit:
		if multiplier < 1.0:
			# Niệm 2 ô: Nhận 40% sát thương (giảm 60%)
			target_unit.add_buff("damage_taken_multiplier", 0.4)
		else:
			# Niệm 1 ô: Miễn nhiễm 100%
			target_unit.add_buff("invulnerable", 1)
	Global.add_paper(int(3 * multiplier))
func execute_earth_boosted(target_unit):
	Global.add_paper(5)
	if target_unit:
		target_unit.add_buff("invulnerable", 1) # Miễn ST lượt này
		target_unit.add_buff("damage_reduction_next_turn", 0.5) # Giảm ST lượt sau
# --- Hệ NƯỚC (Water) ---
func execute_water_logic(target_unit, multiplier):
	if target_unit:
		# Gốc 50 heal -> Multiplier 0.4 (nếu 2 ô) = 20 heal
		target_unit.heal(50 * multiplier)
	Global.add_ink(1)
func execute_water_boosted(target_pos):
	# Tạo vùng hồi máu tồn tại 3 lượt
	create_tile_effect(target_pos, "healing_rain", 3) 
	# Logic cộng mực sẽ được xử lý trong script của ô hiệu ứng (tile_effect.gd)
# --- Hệ GIÓ (Wind) ---
func execute_wind_logic(target_unit, multiplier):
	if target_unit:
		if multiplier < 1.0:
			# Niệm 2 ô: Chỉ cho di chuyển, không đánh 2 lần
			target_unit.add_buff("extra_move", 1)
		else:
			# Niệm 1 ô: Đánh 2 lần
			target_unit.add_buff("double_attack", 1)
func execute_wind_boosted(target_unit, directions):
	if target_unit and directions.size() > 0:
		var dir = directions[0] # Lấy hướng đầu tiên làm chuẩn
		for i in range(2): # Di chuyển 2 ô
			var next_pos = target_unit.grid_position + dir
			if is_cell_empty(next_pos):
				move_unit_to(target_unit, next_pos)
		target_unit.add_buff("disabled", 1) # Vô hiệu hóa 1 lượt
func execute_boosted_logic(element_type, target_unit, directions = []):
	match element_type:
		SpellDictionary.Element.FIRE:
			execute_fire_boosted(target_unit)
		SpellDictionary.Element.EARTH:
			execute_earth_boosted(target_unit)
		SpellDictionary.Element.WATER:
			execute_water_boosted(target_unit)
		SpellDictionary.Element.WIND:
			execute_wind_boosted(target_unit, directions)
# logicgame.gd

func cast_complex_spell(elements, coordinates, directions):
	# 1. Kiểm tra loại phép
	var is_hybrid = elements.size() >= 2
	var is_boosted = elements.size() == 2 and elements[0] == elements[1]
	
	# 2. Tính toán multiplier cho 2 vị trí
	var is_multi = (coordinates.size() >= 4)
	var multiplier = 0.4 if is_multi else 1.0
	
	# 3. Duyệt tọa độ và thi triển
	for i in range(0, coordinates.size(), 2):
		var pair = [coordinates[i], coordinates[i+1]]
		var grid_pos = Global.convert_to_grid(pair)
		var target_unit = get_unit_at(grid_pos)
		
		if is_hybrid and not is_boosted:
			# Gọi logic Hợp Ấn (Lửa+Đất, Lửa+Gió...)
			execute_hybrid_spell(elements, grid_pos, directions)
		else:
			# Gọi logic Ấn đơn hoặc Ấn gia cường
			execute_spell_logic(elements[0], target_unit, multiplier, is_multi, is_boosted)
func calculate_spell_range(directions: Array) -> int:
	# 1 hướng = 8 ô, mỗi hướng thêm vào sẽ giảm tầm xa
	var base_range = 9
	var final_range = base_range - directions.size()
	return max(1, final_range) # Tối thiểu là 1 ô

func get_multiplier_by_range(directions: Array) -> float:
	# Hiệu quả giảm dần theo số lượng hướng
	return max(0.2, 1.0 - (directions.size() - 1) * 0.2)
func execute_earth_direction(target_unit, directions):
	Global.add_paper(3)
	if target_unit:
		target_unit.add_buff("invulnerable", 1) # Miễn ST ô gốc
	
	var max_range = calculate_spell_range(directions)
	for dir in directions:
		var ally = get_first_unit_in_direction(target_unit.grid_position, dir, max_range)
		if ally and not ally.is_enemy:
			ally.add_buff("damage_reduction_1_time", 0.5) # Giảm ST nhận vào
func execute_wind_direction(target_unit, directions):
	if not target_unit: return
	
	# Sắp xếp ưu tiên: Ngang/Dọc trước, Chéo sau
	directions.sort_custom(func(a, b): return abs(a.x) + abs(a.y) < abs(b.x) + abs(b.y))
	
	for dir in directions:
		var new_pos = target_unit.grid_position + dir
		if is_cell_empty(new_pos):
			move_unit_to(target_unit, new_pos)
	
	target_unit.add_buff("rooted", 1) # Vô hiệu hóa di chuyển lượt sau
func execute_element_direction(element, target_unit, directions):
	var max_range = calculate_spell_range(directions)
	var power = get_multiplier_by_range(directions)
	
	if element == SpellDictionary.Element.WATER:
		Global.add_ink(1)

	for dir in directions:
		var extra_target = get_first_unit_in_direction(target_unit.grid_position, dir, max_range)
		if extra_target:
			if element == SpellDictionary.Element.FIRE:
				extra_target.take_damage(35 * power)
			else:
				extra_target.heal(50 * power)
func execute_combined_logic(element, unit, pos, dirs, mult, is_multi, m_range):
	match element:
		SpellDictionary.Element.FIRE:
			# Lửa: 35 dmg gốc -> 14 dmg nếu multi. Gây ST ô gốc và hướng bay.
			if unit: unit.take_damage(35 * mult)
			for d in dirs:
				var extra = get_first_unit_in_direction(pos, d, m_range)
				if extra: extra.take_damage(35 * mult)

		SpellDictionary.Element.EARTH:
			# Đất: Multi -> nhận 40% ST. Single -> Miễn ST hoàn toàn. Nhận giấy.
			if unit:
				if is_multi: unit.add_buff("damage_taken_multiplier", 0.4)
				else: unit.add_buff("invulnerable", 1)
			
			for d in dirs:
				var ally = get_first_unit_in_direction(pos, d, m_range)
				if ally and not ally.is_enemy:
					ally.add_buff("damage_reduction_1_time", 0.5)
			Global.add_paper(int(3 * mult))

		SpellDictionary.Element.WATER:
			# Nước: 50 heal gốc -> 20 heal nếu multi. Nhận mực.
			if unit: unit.heal(50 * mult)
			for d in dirs:
				var extra = get_first_unit_in_direction(pos, d, m_range)
				if extra: extra.heal(50 * mult)
			Global.add_ink(1)

		SpellDictionary.Element.WIND:
			# Gió: Multi -> Chỉ đẩy 1 ô. Single -> Đánh 2 lần.
			if is_multi:
				execute_wind_direction(unit, dirs) # Hàm đẩy mục tiêu bạn đã viết
			else:
				if unit: unit.add_buff("double_attack", 1)
# logicgame.gd

func execute_standard_logic(element_type, target_unit, multiplier, _is_multi):
	match element_type:
		SpellDictionary.Element.FIRE:
			execute_fire_logic(target_unit, multiplier)
		SpellDictionary.Element.EARTH:
			execute_earth_logic(target_unit, multiplier)
		SpellDictionary.Element.WATER:
			execute_water_logic(target_unit, multiplier)
		SpellDictionary.Element.WIND:
			execute_wind_logic(target_unit, multiplier)
# logicgame.gd

# logicgame.gd

func execute_hybrid_spell(elements: Array, target_pos: Vector2i, directions: Array):
	elements.sort() # Đảm bảo thứ tự để khớp cặp
	var e1 = elements[0]
	var e2 = elements[1]

	# --- Lửa + Đất ---
	if e1 == SpellDictionary.Element.EARTH and e2 == SpellDictionary.Element.FIRE:
		var duration = 8 - directions.size()
		create_tile_effect(target_pos, "spreading_fire", duration, directions)
		Global.add_paper(1)
		# Kiểm tra đồng minh trúng phải để cộng thêm giấy
		check_ally_hit_reward(target_pos, 1, "paper")

	# --- Lửa + Gió ---
	elif e1 == SpellDictionary.Element.FIRE and e2 == SpellDictionary.Element.WIND:
		var primary_dir = sort_directions_priority(directions)
		create_moving_aoe(target_pos, "fire_storm", 3, primary_dir)
		# Sát thương xung quanh và đẩy lùi (cần xử lý va chạm tường/vật cản)
		aoe_damage_push_with_collision(target_pos, 20, primary_dir)

	# --- Lửa + Nước ---
	elif e1 == SpellDictionary.Element.FIRE and e2 == SpellDictionary.Element.WATER:
		create_tile_effect(target_pos, "stealth_mist", 3, directions)
		Global.add_ink(1)
		check_ally_hit_reward(target_pos, 0.5, "ink")

	# --- Nước + Gió ---
	elif e1 == SpellDictionary.Element.WATER and e2 == SpellDictionary.Element.WIND:
		clear_tile_effects(target_pos)
		create_tile_effect(target_pos, "purifying_rain", 3, directions)
		check_ally_hit_reward(target_pos, 0.5, "ink")
		if get_unit_at(target_pos) == player_unit: # Giả sử bạn có biến player_unit
			Global.add_paper(-1)

	# --- Nước + Đất ---
	elif e1 == SpellDictionary.Element.EARTH and e2 == SpellDictionary.Element.WATER:
		var duration = 8 - directions.size()
		create_tile_effect(target_pos, "healing_swamp", duration, directions)

	# --- Gió + Đất ---
	elif e1 == SpellDictionary.Element.EARTH and e2 == SpellDictionary.Element.WIND:
		var duration = 8 - directions.size()
		# Tạo các khối đất theo hướng chỉ định
		for dir in directions:
			var wall_pos = target_pos + dir
			if is_cell_empty(wall_pos):
				create_static_obstacle(wall_pos, "earth_barrier", duration)
				# Thưởng giấy cho đồng minh xung quanh
				reward_allies_nearby(wall_pos, 1, "paper")
# Sắp xếp hướng ưu tiên cho Bão lửa/Sương mù
func sort_directions_priority(dirs: Array) -> Vector2i:
	if dirs.is_empty(): return Vector2i.ZERO
	# Ưu tiên Dọc (y != 0) -> Ngang (x != 0) -> Chéo
	dirs.sort_custom(func(a, b): 
		if a.x == 0 and b.x != 0: return true # Dọc ưu tiên hơn
		return false
	)
	return dirs[0]

# Gây ST diện rộng và đẩy lùi
func aoe_damage_and_push(center_pos, damage, _force):
	var neighbors = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
	for offset in neighbors:
		var unit = get_unit_at(center_pos + offset)
		if unit:
			unit.take_damage(damage)
			push_unit(unit, offset) # Hàm đẩy bạn đã viết ở hệ Gió
func create_moving_aoe(pos: Vector2i, type: String, _duration: int, direction: Vector2i):
	# Code để tạo một object hiệu ứng có khả năng tự di chuyển mỗi lượt
	print("Tạo AOE di động: ", type, " tại ", pos, " hướng ", direction)
func create_static_obstacle(grid_pos: Vector2i, _type: String, duration: int):
	# Tạo một thực thể ngăn quân cờ đi vào ô này
	var wall = preload("res://earth_wall.tscn").instantiate()
	add_child(wall)
	wall.grid_position = grid_pos
	wall.duration = duration
	wall.add_to_group("obstacles")
func push_unit(unit, direction: Vector2i):
	var target_pos = unit.grid_position + direction
	if is_cell_empty(target_pos):
		move_unit_to(unit, target_pos)
	else:
		# Nếu bị chặn không đẩy được, nhận thêm sát thương (theo mô tả Bão Lửa)
		unit.take_damage(10) 
		print("Mục tiêu bị chặn, nhận thêm sát thương va chạm!")
func clear_tile_effects(grid_pos: Vector2i):
	# Tìm và xóa các object hiệu ứng (lửa, đầm lầy...) tại ô này
	for effect in get_tree().get_nodes_in_group("tile_effects"):
		if effect.grid_position == grid_pos:
			effect.queue_free()
func check_ally_hit_reward(pos: Vector2i, amount: float, resource_type: String):
	var unit = get_unit_at(pos)
	if unit and not unit.is_enemy:
		if resource_type == "paper":
			Global.add_paper(int(amount))
		elif resource_type == "ink":
			Global.add_ink(amount)
# logicgame.gd

func aoe_damage_push_with_collision(center_pos: Vector2i, damage: float, push_dir: Vector2i):
	# Duyệt 8 ô xung quanh (AOE 3x3)
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0: continue # Bỏ qua ô tâm
			var target_pos = center_pos + Vector2i(x, y)
			var unit = get_unit_at(target_pos)
			
			if unit:
				unit.take_damage(damage)
				# Đẩy mục tiêu theo hướng bão (push_dir)
				push_unit(unit, push_dir) # Hàm push_unit đã thêm ở bước trước
func reward_allies_nearby(origin_pos: Vector2i, amount: int, type: String):
	for x in range(-1, 2):
		for y in range(-1, 2):
			var check_pos = origin_pos + Vector2i(x, y)
			var unit = get_unit_at(check_pos)
			if unit and not unit.is_enemy:
				if type == "paper": Global.add_paper(amount)
				print("Thưởng đồng minh tại: ", check_pos)
