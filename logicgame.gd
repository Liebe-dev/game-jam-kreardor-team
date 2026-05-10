extends Node2D
@onready var win_screen = get_node("/root/board/WinPanel")
@onready var lose_screen = get_node("/root/board/LosePanel")
@export var move_indicator_scene: PackedScene
@export var endgame_menu: Control
@export var endgame_title: Label
const SPELL_EFFECT_SCENE = preload("res://spell_effect.tscn")
var active_indicators = []
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
var dragon_res = load("res://boss_dragon.tscn")
var boss = dragon_res.instantiate()
var current_turn = 1
enum Command { ATTACK, DEFEND, IDLE }
var current_command = Command.IDLE
var current_attack_index = 0
var has_moved_main_piece = false
var piece_layer: Node2D
var all_pieces = []
var selected_piece = null
var is_player_turn = true
var board_origin = Vector2(450, 250)
var cell_size = 80
var player_unit
var player_pieces_backup = []
const FIRE_TILE_SCENE = preload("res://fire_tile.tscn")
var max_waves = 5
func _ready():
	win_screen.hide()
	lose_screen.hide()
	add_to_group("logic_board")
	player_unit = get_tree().get_first_node_in_group("player")
	if wave_label:
		wave_label.text = "Wave: " + str(Global.current_wave)
	piece_layer = Node2D.new()
	piece_layer.name = "PieceLayer"
	add_child(piece_layer)
	
	spawn_initial_army()
	backup_player_pieces()
# Hàm phụ để đếm số lần 1 ô bị trúng phép
func _add_to_impact_map(map: Dictionary, pos: Vector2i):
	if map.has(pos):
		map[pos] += 1
	else:
		map[pos] = 1

# Kiểm tra xem tọa độ có nằm trong bàn cờ 8x8 không
func is_within_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8
func count_enemies_alive() -> int:
	var enemy_count = 0
	for p in all_pieces:
		if is_instance_valid(p) and p.team == 2:
			enemy_count += 1
	return enemy_count
func transition_to_next_wave():
	Global.current_wave += 1
	current_turn = 1
	
	if wave_label: wave_label.text = "Wave: " + str(Global.current_wave)
	if turn_label: turn_label.text = "Turn: 1"
	for i in range(all_pieces.size() - 1, -1, -1):
		var p = all_pieces[i]
		if is_instance_valid(p) and p.team == 2:
			all_pieces.remove_at(i)
			p.queue_free()
	if Global.current_wave == 1:
		spawn_initial_army()
		await get_tree().process_frame
		for p in all_pieces:
			if is_instance_valid(p) and p.has_node("Sprite2D"):
				p.get_node("Sprite2D").region_rect = Rect2(0, 64, 64, 64)
		return
	var current_pawns = []
	var king_piece = null
	for p in all_pieces:
		if is_instance_valid(p) and p.team == 1:
			if "King" in p.name:
				king_piece = p
			else:
				current_pawns.append(p)
	for i in range(8):
		if i < current_pawns.size():
			var p = current_pawns[i]
			p.grid_pos = Vector2i(i, 6)
			p.position = grid_to_pixel(p.grid_pos)
			
			if "hp" in p:
				p.hp += 30
				if p.has_node("HealthBar"):
					var bar = p.get_node("HealthBar")
					bar.max_value = max(bar.max_value, p.hp)
					bar.value = p.hp
		else:
			var new_pawn = player_pawn_scene.instantiate()
			new_pawn.team = 1
			piece_layer.add_child(new_pawn)
			all_pieces.append(new_pawn)
			new_pawn.set("hp", 20)
			new_pawn.grid_pos = Vector2i(i, 6)
			new_pawn.position = grid_to_pixel(new_pawn.grid_pos)
			if new_pawn.has_node("HealthBar"):
				new_pawn.get_node("HealthBar").max_value = 50
				new_pawn.get_node("HealthBar").value = 20
	if is_instance_valid(king_piece):
		king_piece.grid_pos = Vector2i(3, 7)
		king_piece.position = grid_to_pixel(king_piece.grid_pos)
	spawn_enemy_wave()
	await get_tree().process_frame
	for p in all_pieces:
		if is_instance_valid(p) and p.has_node("Sprite2D"):
			var sprite = p.get_node("Sprite2D")
			sprite.region_rect = Rect2(0, 64, 64, 64)
	await get_tree().process_frame
	for p in all_pieces:
		if is_instance_valid(p):
			for child in p.get_children():
				if child is Sprite2D:
					if p.team == 1:
						child.frame = 1
					else:
						child.frame = 0
				elif child is AnimatedSprite2D:
					if p.team == 1:
						child.play("up")
					else:
						child.play("down")
	backup_player_pieces()


func check_and_trigger_next_wave():
	if count_enemies_alive() <= 0:
		if Global.current_wave >= max_waves:
			# Nếu hết wave, hiện màn hình thắng (có sẵn ảnh trong đó)
			win_screen.show()
			get_tree().paused = true # Tạm dừng game
		else:
			transition_to_next_wave()
	get_tree().paused = false # Hoặc true tùy cách bạn xử lý
	force_release_all_grabs()
func spawn_initial_army():
	if Global.current_wave == 1:
		for i in range(8):
			var pawn = player_pawn_scene.instantiate()
			pawn.team = 1
			piece_layer.add_child(pawn)
			all_pieces.append(pawn)
			pawn.grid_pos = Vector2i(i, 6)
			if has_method("grid_to_pixel"): pawn.global_position = grid_to_pixel(pawn.grid_pos)
		if player_king_scene:
			var king = player_king_scene.instantiate()
			king.team = 1
			piece_layer.add_child(king)
			all_pieces.append(king)
			king.grid_pos = Vector2i(3, 7)
			if has_method("grid_to_pixel"): king.global_position = grid_to_pixel(king.grid_pos)
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
		enemy.team = 2
		piece_layer.add_child(enemy)
		all_pieces.append(enemy)
		enemy.grid_pos = Vector2i(data["pos"].x, data["pos"].y)
		if has_method("grid_to_pixel"):
			enemy.global_position = grid_to_pixel(enemy.grid_pos)
func spawn_final_boss():
	boss.hp = 1000
	boss.grid_pos = Vector2i(3, 0)
	boss.position = grid_to_pixel(boss.grid_pos)
	piece_layer.add_child(boss)
	all_pieces.append(boss)
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
func deal_damage(unit, amount):
	if not is_instance_valid(unit): return
	
	unit.current_health -= amount
	if unit.has_node("HealthBar"):
		unit.get_node("HealthBar").value = unit.current_health
		
	# Check nếu KING chết
	if unit.current_health <= 0:
		if "King" in unit.name:
			show_lose_screen()
		else:
			# --- CHÈN ĐOẠN NÀY VÀO TRƯỚC KHI XÓA LÍNH ---
			# Quét xem có ai đang ôm cái xác này, hoặc bị cái xác này ôm không thì gỡ ra
			for p in all_pieces:
				if is_instance_valid(p):
					if p.get("grabbed_by") == unit or p == unit.get("grabbed_by"):
						p.set("is_grabbed", false)
						p.set("grabbed_by", null)
						p.z_index = 0
						# Kéo người sống sót thả lại xuống đất
						if "grid_pos" in p and p.has_method("grid_to_pixel"):
							p.position = grid_to_pixel(p.grid_pos)
						if p.has_method("update_visuals"):
							p.update_visuals()
			# ---------------------------------------------
			
			# Xóa lính chết khỏi bàn cờ
			all_pieces.erase(unit)
			unit.queue_free()
func _input(event):
	if has_moved_main_piece: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var clicked_grid = calculate_grid_position(click_pos)
		if not is_within_board(clicked_grid): return
		var piece_at_click = get_piece_at(clicked_grid)
		if piece_at_click and piece_at_click.team == 1 and not "EarthBlock" in piece_at_click.name:
			selected_piece = piece_at_click
			show_highlights(selected_piece)
		elif selected_piece != null:
			var valid_moves = get_valid_moves(selected_piece)
			if clicked_grid in valid_moves:
				if selected_piece.is_grabbed:
					force_release_all_grabs(selected_piece)
				move_piece(selected_piece, clicked_grid)
				selected_piece.has_moved = true
				has_moved_main_piece = true
				clear_highlights()
				selected_piece = null
			else:
				clear_highlights()
				selected_piece = null
	if event is InputEventKey and event.pressed:
		
		# Trả lại tên cũ là coords cho các phím dưới khỏi báo lỗi
		var coords = ["B", "2"] #"E", "4" 
		var dirs = [] 
		dirs.append(Vector2i(1, 0))   # Phải (Right)
		#dirs.append(Vector2i(-1, 0))  # Trái (Left)
		#dirs.append(Vector2i(0, -1))  # Lên (Up)
		#dirs.append(Vector2i(0, 1))   # Xuống (Down)
		#dirs.append(Vector2i(1, 1)) 
		#dirs.append(Vector2i(-1, 1)) 

		if event.keycode == KEY_1:
			print("[TEST] Phép Lửa")
			cast_complex_spell([SpellDictionary.Element.FIRE], coords, dirs)
			
		elif event.keycode == KEY_2:
			print("[TEST] Phép Nước")
			cast_complex_spell([SpellDictionary.Element.WATER], coords, dirs)
		
		# Các phím dưới tự động hết lỗi!
			
		elif event.keycode == KEY_3:
			print("[DEBUG] CƠ BẢN 3: Gió")
			cast_complex_spell([SpellDictionary.Element.WIND], coords, dirs)
			
		elif event.keycode == KEY_4:
			print("[DEBUG] CƠ BẢN 4: Đất")
			cast_complex_spell([SpellDictionary.Element.EARTH], coords, dirs)
		# 2. NHÓM PHÉP GIA CƯỜNG (2 Nguyên tố GIỐNG nhau)
		elif event.keycode == KEY_5:
			print("[DEBUG] GIA CƯỜNG 1: Lửa x2 (Vụ nổ lớn)")
			cast_complex_spell([SpellDictionary.Element.FIRE, SpellDictionary.Element.FIRE], coords, dirs)
			
		elif event.keycode == KEY_6:
			print("[DEBUG] GIA CƯỜNG 2: Nước x2 (Siêu hồi máu)")
			cast_complex_spell([SpellDictionary.Element.WATER, SpellDictionary.Element.WATER], coords, dirs)
			
		elif event.keycode == KEY_7:
			print("[DEBUG] GIA CƯỜNG 3: Gió x2 (Liên hoàn kích)")
			cast_complex_spell([SpellDictionary.Element.WIND, SpellDictionary.Element.WIND], coords, dirs)
			
		elif event.keycode == KEY_8:
			print("[DEBUG] GIA CƯỜNG 4: Đất x2 (Siêu phòng thủ)")
			cast_complex_spell([SpellDictionary.Element.EARTH, SpellDictionary.Element.EARTH], coords, dirs)
		# 3. NHÓM PHÉP HỢP ẤN (2 Nguyên tố KHÁC nhau)
		elif event.keycode == KEY_9:
			print("[DEBUG] HỢP ẤN 1: Lửa + Nước -> Hơi nước (Gây mù)")
			cast_complex_spell([SpellDictionary.Element.FIRE, SpellDictionary.Element.WATER], coords, dirs)
			
		elif event.keycode == KEY_0:
			print("[DEBUG] HỢP ẤN 2: Lửa + Gió -> Bão lửa (Giảm giáp)")

			cast_complex_spell([SpellDictionary.Element.FIRE, SpellDictionary.Element.WIND], coords, [Vector2i(1, 0)])
			
		elif event.keycode == KEY_Q:
			print("[DEBUG] HỢP ẤN 3: Lửa + Đất -> Dung nham (Gây cháy)")
			cast_complex_spell([SpellDictionary.Element.FIRE, SpellDictionary.Element.EARTH], coords, dirs)
			
		elif event.keycode == KEY_W:
			print("[DEBUG] HỢP ẤN 4: Nước + Gió -> Bão tuyết (Đóng băng)")
			cast_complex_spell([SpellDictionary.Element.WATER, SpellDictionary.Element.WIND], coords, dirs)
			
		elif event.keycode == KEY_E:
			print("[DEBUG] HỢP ẤN 5: Nước + Đất -> Đầm lầy (Làm chậm)")
			cast_complex_spell([SpellDictionary.Element.WATER, SpellDictionary.Element.EARTH], coords, dirs)
			
		elif event.keycode == KEY_R:
			print("[DEBUG] HỢP ẤN 6: Gió + Đất -> ()")
			cast_complex_spell([SpellDictionary.Element.WIND, SpellDictionary.Element.EARTH], coords, dirs)
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
	
	for p in all_pieces:
		# Gộp chung is_instance_valid cho gọn
		if is_instance_valid(p):
			# [LỖI 1: BẠN QUÊN TRỪ LƯỢT CHOÁNG]
			if "stun_turns" in p and p.stun_turns > 0:
				p.stun_turns -= 1 # Trừ lượt choáng
			
		if "root_turns" in p and p.root_turns > 0:
			p.root_turns -= 1 # Trừ lượt trói chân
			
		var s_turns = p.stun_turns if "stun_turns" in p else 0
		var r_turns = p.root_turns if "root_turns" in p else 0
		
		if s_turns <= 0 and r_turns <= 0:
			if "current_wind_visual" in p:
				var wind_visual = p.current_wind_visual
				if is_instance_valid(wind_visual):
					wind_visual.queue_free()
				p.current_wind_visual = null # Xóa dấu vết

	# 1. BÁO CHO TRẠM QUẢN LÝ Ô HIỆU ỨNG CHẠY
	# Lửa sẽ đốt máu và tự đếm ngược lượt tắt
	process_all_tile_effects()
	
	# Vì bàn cờ của bạn là 8x8, ta sẽ dùng 2 vòng lặp quét qua tất cả các ô
	for x in range(8):
		for y in range(8):
			var pos = Vector2i(x, y)
			
			# [LỖI 2 - NGUYÊN NHÂN CHÍNH GÂY LIỆT NÚT]
			# Code cũ của bạn là get_unit_at, nhưng hàm của bạn tên là get_piece_at!
			var unit = get_piece_at(pos) # <--- SỬA LẠI THÀNH get_piece_at
			
			if unit != null and unit.has_method("on_turn_end"):
				unit.on_turn_end()
				
	move_team_logic(1)
	await get_tree().create_timer(0.3).timeout
	move_team_logic(2)
	await get_tree().create_timer(0.2).timeout
	
	for p in all_pieces:
		if is_instance_valid(p):
			check_and_execute_grab(p)
			
	execute_all_combat_logic()
	
	for p in all_pieces:
		if is_instance_valid(p):
			if "has_moved" in p:
				p.has_moved = false
				
	has_moved_main_piece = false
	selected_piece = null
	current_turn += 1
	
	if turn_label:
		turn_label.text = "Turn: " + str(current_turn)
		
	Global.has_casted_spell = false
	%ClosedScrollButton.show()
	process_ammo_reloads()
	
	if count_enemies_alive() <= 0:
		check_and_trigger_next_wave()
		
	process_all_tile_effects() # (Lưu ý: Bạn đang gọi hàm này 2 lần ở đầu và cuối, nếu không phải chủ đích thì có thể xóa bớt 1 cái đi nhé)
	
	var pieces_to_remove = [] # Tạo mảng phụ để chứa các tường sắp vỡ
	
	for p in all_pieces:
		if is_instance_valid(p) and "EarthBlock" in p.name:
			if "duration" in p:
				p.duration -= 1
				print("[Khối Đất] Thời gian còn: ", p.duration, " lượt")
				
				if p.duration <= 0:
					print("[Khối Đất] Tường đã sụp đổ!")
					pieces_to_remove.append(p)
					
	# Xóa các khối đất hết hạn khỏi mảng và bàn cờ
	for p in pieces_to_remove:
		all_pieces.erase(p)
		p.queue_free()
func execute_all_combat_logic():
	for p in all_pieces:
		if not is_instance_valid(p): continue
		
		if is_tile_foggy(p.grid_pos):
			print(p.name, " đang ở trong Sương Mù, mất lượt tấn công/grab!")
			continue
		# BÊN NÀY CHỈ CHẶN ĐÁNH, KHÔNG CÓ DẤU TRỪ (-) NÀO HẾT
		if "stun_turns" in p and p.stun_turns > 0:
			continue
		# ------------------------------------
	for p in all_pieces:
		if not is_instance_valid(p): continue
		if p.is_grabbed:
			var p_name = p.name.to_lower()
			if "queen" in p_name:
				queen_grab_counter(p)
			elif "knight" in p_name:
				execute_knight_logic(p)
			elif "bishop" in p_name:
				execute_bishop_logic(p)
			else:
				if is_instance_valid(p.grabbed_by):
					deal_damage(p.grabbed_by, 10)
		else:
			var p_name = p.name.to_lower()
			if "rook" in p_name:
				execute_rook_logic(p)
			elif "bishop" in p_name:
				execute_bishop_logic(p)
func move_team_logic(team_num: int):
	for p in all_pieces:
		if not is_instance_valid(p) or p.team != team_num: continue
		
		# --- CHỐT CHẶN CẢ CHOÁNG VÀ TRÓI CHÂN Ở ĐÂY ---
		var is_stunned = "stun_turns" in p and p.stun_turns > 0
		var is_rooted = "root_turns" in p and p.root_turns > 0
		
		if is_stunned or is_rooted:
			var reason = "Choáng (Gió)" if is_stunned else "Trói chân (Đầm lầy)"
			print("Lính ", p.name, " đang bị ", reason, " -> AI bỏ qua di chuyển!")
			
			# -- TRỪ LƯỢT CHOÁNG --
			if is_stunned:
				p.stun_turns -= 1
				if p.stun_turns <= 0:
					var wind_visual = p.get("current_wind_visual")
					if is_instance_valid(wind_visual):
						wind_visual.queue_free()
						p.set("current_wind_visual", null)
			
			# -- TRỪ LƯỢT TRÓI CHÂN --
			if is_rooted:
				p.root_turns -= 1
				
			# Lệnh continue này sẽ hất văng lính, AI KHÔNG THỂ bắt nó đi bộ được nữa
			continue
	for p in all_pieces:
		if not is_instance_valid(p) or p.team != team_num: continue
		if p.get("is_grabbed") == true or "King" in p.name or "boss" in p.name.to_lower() or "dragon" in p.name.to_lower():
			continue
		if "EarthBlock" in p.name: 
			continue
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
func execute_boss_turn():
	match current_attack_index:
		0: scream_pushback()
		1: fire_breath_single()
		2: claw_swipe()
		3: triple_fireball()

	current_attack_index = (current_attack_index + 1) % 4

func scream_pushback():
	for p in all_pieces:
		if is_instance_valid(p) and p.team == 1:
			p.grid_pos.y += 2
			p.grid_pos.y = clamp(p.grid_pos.y, 0, 7)
			p.position = grid_to_pixel(p.grid_pos)

func fire_breath_single():
	var players = get_all_team_units(1)
	if players.size() > 0:
		var target = players.pick_random()
		deal_damage(target, 20)
		target.set("burn_ticks", 2)

func claw_swipe():
	for x in range(3, 3 + 3):
		var target_pos = Vector2i(x, 0 + 3)
		var unit = find_unit_at(target_pos)
		if unit: deal_damage(unit, 25)
func triple_fireball():
	for i in range(3):
		var center = Vector2i(randi()%8, randi()%8)
		for x in range(-1, 2):
			for y in range(-1, 2):
				var unit = find_unit_at(center + Vector2i(x, y))
				if unit: deal_damage(unit, 15)
func check_and_execute_grab(pawn):
	if "King" in pawn.name or "EarthBlock" in pawn.name: return
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
		
	if "EarthBlock" in pawn.name or "EarthBlock" in chosen_target.name:
		return
		
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

func force_release_all_grabs(piece = null):
	selected_piece = null
	
	# Quét toàn bộ bàn cờ và thả tất cả lính ra
	for p in all_pieces:
		if is_instance_valid(p):
			p.set("is_grabbed", false)
			p.set("grabbed_by", null)
			
			# Đưa lính về chính giữa ô vuông (chống kẹt lơ lửng)
			if "grid_pos" in p and has_method("grid_to_pixel"):
				p.position = grid_to_pixel(p.grid_pos)
			
			# Tắt hiệu ứng viền/bóng
			if p.has_method("update_visuals"):
				p.update_visuals()

func kill_piece(piece):
	for p in all_pieces:
		if is_instance_valid(p) and p.grabbed_by == piece:
			p.is_grabbed = false
			p.grabbed_by = null
			if p.has_method("update_visuals"): p.update_visuals()
	
	if piece in all_pieces:
		all_pieces.erase(piece)
	
	piece.queue_free()

func apply_knockback(unit, push_dir: Vector2i, max_dist: int, impact_damage: int = 0) -> bool:
	if not is_instance_valid(unit): return false
	
	var start_grid = unit.grid_pos
	print("--- TEST KNOCKBACK ---")
	print("1. Lính ở ô: ", start_grid, " | Bị đẩy hướng: ", push_dir)
	
	if push_dir == Vector2i(0, 0):
		print("LỖI: Hướng đẩy là (0,0), lính không thể di chuyển!")
		return false
	
	var current_grid = start_grid
	var hit_obstacle = false
	
	for i in range(max_dist):
		var next_grid = current_grid + push_dir
		
		if not is_within_board(next_grid):
			print("2. Chạm biên bàn cờ tại: ", next_grid)
			hit_obstacle = true
			break
			
		if not is_cell_vacant(next_grid):
			print("2. Bị chặn bởi vật cản tại: ", next_grid)
			hit_obstacle = true
			var obstacle = get_piece_at(next_grid)
			if is_instance_valid(obstacle) and impact_damage > 0:
				deal_damage(obstacle, impact_damage)
			break
			
		current_grid = next_grid
		print("2. Ô ", next_grid, " an toàn.")
		
	if current_grid != start_grid:
		print("3. Cập nhật lính tới đích: ", current_grid)
		
		# Cập nhật logic bàn cờ của bạn
		move_piece(unit, current_grid)
		
		# ÉP ĐỔI HÌNH ẢNH (Phòng trường hợp move_piece của bạn quên làm)
		var tween = create_tween()
		tween.tween_property(unit, "global_position", grid_to_pixel(current_grid), 0.2).set_trans(Tween.TRANS_SINE)
		
	else:
		print("3. Lính không nhúc nhích được bước nào!")
		
	if hit_obstacle and impact_damage > 0:
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

func is_cell_empty(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= 8 or grid_pos.y < 0 or grid_pos.y >= 8:
		return false
	return get_unit_at(grid_pos) == null
func move_unit_to(unit, new_grid_pos: Vector2i):
	if "active_buffs" in unit and unit.active_buffs.has("root"):
		return
	if unit and unit.has_method("set_grid_position"):
		unit.set_grid_position(new_grid_pos)
		unit.global_position = Global.calculate_world_position(new_grid_pos)
	if unit and unit.has_method("set_grid_position"):
		unit.set_grid_position(new_grid_pos)
func grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	var target_grid = grid_points
	if target_grid == null:
		target_grid = get_parent().get_node_or_null("GridPoints")
		
	if target_grid == null: return Vector2.ZERO
	var marker_name = str(int(grid_pos.y)) + " " + str(int(grid_pos.x))
	
	for child in target_grid.get_children():
		if child.name.strip_edges() == marker_name:
			return child.global_position
			
	return Vector2.ZERO
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
				closest_grid = Vector2i(int(parts[1]), int(parts[0]))
				
	if min_dist > 60:
		return Vector2i(-1, -1)
		
	return closest_grid
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
	for i in range(all_pieces.size() - 1, -1, -1):
		var p = all_pieces[i]
		if is_instance_valid(p) and p.team == 2:
			all_pieces.remove_at(i)
			p.queue_free()
func get_unit_at(pos: Vector2i):
	for p in all_pieces:
		if is_instance_valid(p):
			if Vector2i(p.grid_pos) == Vector2i(pos):
				return p
	return null

func get_first_unit_in_direction(start_pos: Vector2i, direction: Vector2i, max_range: int):
	for i in range(1, max_range + 1):
		var check_pos = start_pos + (direction * i)
		var unit = get_unit_at(check_pos)
		if unit:
			return unit
	return null

func cast_complex_spell(elements, coordinates, directions):
	# 1. Kiểm tra an toàn
	if elements.is_empty() or coordinates.size() < 2:
		print("[LogicGame] Bỏ qua vì thiếu nguyên tố hoặc tọa độ!")
		return
		
	# 2. XỬ LÝ TỌA ĐỘ THÔNG MINH (HỖ TRỢ ĐA MỤC TIÊU)
	var target_grids = []
	for i in range(0, coordinates.size(), 2):
		if i + 1 < coordinates.size():
			var char1 = coordinates[i]
			var char2 = coordinates[i+1]
			
			var letter = char1 if char1.to_upper() in ["A","B","C","D","E","F","G","H"] else char2
			var number = char2 if char2 in ["1","2","3","4","5","6","7","8"] else char1
			
			if letter != "" and number != "":
				var grid_pos = Global.convert_to_grid([letter, number])
				target_grids.append(grid_pos)
			
	if target_grids.is_empty():
		print("[LogicGame] Lỗi tọa độ không hợp lệ!")
		return

	# ==========================================
	# 3. TRẠM ĐIỀU PHỐI PHÉP THUẬT TỔNG
	# ==========================================
	
	# --- TRƯỜNG HỢP 1: PHÉP ĐƠN (1 Nguyên Tố) ---
	if elements.size() == 1:
		match elements[0]:
			SpellDictionary.Element.FIRE:
				execute_new_fire_spell(target_grids, directions)
			SpellDictionary.Element.WATER:
				execute_new_water_spell(target_grids, directions)
			SpellDictionary.Element.EARTH:
				execute_new_earth_spell(target_grids, directions)
			SpellDictionary.Element.WIND:
				execute_new_wind_spell(target_grids, directions) # Cứ viết sẵn tên hàm, sau này tạo hàm sau

	# --- TRƯỜNG HỢP 2: PHÉP KÉP (2 Nguyên Tố) ---
	elif elements.size() == 2:
		
		# A. Phép Gia Cường (2 Nguyên tố GIỐNG NHAU)
		if elements[0] == elements[1]:
			match elements[0]:
				SpellDictionary.Element.FIRE:
					execute_new_fire_fire_spell(target_grids, directions)
				SpellDictionary.Element.WATER:
					execute_new_water_water_spell(target_grids, directions)
				SpellDictionary.Element.EARTH:
					execute_new_earth_earth_spell(target_grids, directions)
				SpellDictionary.Element.WIND:
					execute_new_wind_wind_spell(target_grids, directions)
					
		# B. Phép Lai / Hybrid (2 Nguyên tố KHÁC NHAU)
		else:
			# Đặt biến kiểm tra sự tồn tại (Không quan tâm thứ tự gõ trước sau)
			var has_fire = SpellDictionary.Element.FIRE in elements
			var has_water = SpellDictionary.Element.WATER in elements
			var has_earth = SpellDictionary.Element.EARTH in elements
			var has_wind = SpellDictionary.Element.WIND in elements
			
			# Lửa + Nước (hoặc Nước + Lửa)
			if has_fire and has_water: 
				execute_new_fire_water_spell(target_grids, directions)
				
			# Lửa + Đất
			elif has_fire and has_earth:
				execute_new_fire_earth_spell(target_grids, directions)
				
			# Lửa + Gió
			elif has_fire and has_wind:
				execute_new_fire_wind_spell(target_grids, directions)
				
			# Nước + Đất
			elif has_water and has_earth:
				execute_new_water_earth_spell(target_grids, directions)
				
			# Nước + Gió
			elif has_water and has_wind:
				execute_new_water_wind_spell(target_grids, directions)
				
			# Đất + Gió
			elif has_earth and has_wind:
				execute_new_wind_earth_spell(target_grids, directions)
func execute_new_fire_spell(target_grids: Array, directions: Array):
	print("[Phép Lửa] Bắt đầu gọi thiên thạch...")
	
	# Gọi hàm lõi: Base 35, loại "damage", hiệu ứng "lua"
	execute_aoe_effect(target_grids, directions, 35.0, "damage", "lua")

func execute_new_fire_fire_spell(target_grids: Array, directions: Array):
	
	# 1. Sát thương gây ra khi phép vừa chạm vào người lính (50% cộng thêm)
	var base_damage = 52.5 
	
	var impact_map = execute_aoe_effect(target_grids, directions, base_damage, "damage", "lua")
	
	# 3. Tạo Ô Lửa trên TẤT CẢ các ô bị ảnh hưởng bởi phép
	# (Ô Lửa này sẽ cháy mãi, nó không biết gì về vụ nổ ở bước 2)
	for grid_pos in impact_map.keys():
		add_tile_effect(grid_pos, "fire_tile", 2)
func execute_new_water_spell(target_grids: Array, directions: Array):
	print("[Phép Nước] Bắt đầu dội mưa...")
	
	# Gọi hàm lõi: Base 50, loại "heal", hiệu ứng "nuoc"
	execute_aoe_effect(target_grids, directions, 50.0, "heal", "nuoc")
	
	Global.add_ink(250)
# --- PHÉP NƯỚC - NƯỚC ---
func execute_new_water_water_spell(target_grids: Array, directions: Array):
	var impact_map = execute_aoe_effect(target_grids, directions, 0, "heal", "nuoc")
	for grid_pos in impact_map.keys():
		add_tile_effect(grid_pos, "water_tile", 3)
# --- C. PHÉP GIÓ (Đẩy lùi) ---
func execute_new_wind_spell(target_grids: Array, directions: Array):
	print("[Phép Gió] Kích hoạt!")
	if target_grids.is_empty(): return
	
	var has_direction = not directions.is_empty()
	
	for i in range(target_grids.size()):
		var grid_pos = target_grids[i]
		var dir = Vector2i.ZERO
		
		# Phân bổ hướng cho nhiều mũi tên
		if has_direction:
			dir = directions[i] if i < directions.size() else directions[0]
			
		# SỬ DỤNG ĐÚNG HÀM CỦA BẠN: get_piece_at
		var unit = get_piece_at(grid_pos) 
		
		# --- QUAN TRỌNG: GỌI DẬY HIỆU ỨNG CŨ Ở ĐÂY ---
		if active_tile_effects.has(grid_pos):
			var old_effect = active_tile_effects[grid_pos]["type"]
			_trigger_immediate_tile_effect(grid_pos, old_effect, unit)
			
		# --- XỬ LÝ ĐẨY LÙI VÀ BUFF CỦA GIÓ ---
		if not has_direction:
			play_wind_visual(grid_pos, "gio")
			if is_instance_valid(unit) and unit.has_method("add_buff"):
				unit.add_buff("double_attack", 0, 1)
		else:
			play_wind_visual(grid_pos, "giogio")
			if is_instance_valid(unit):
				var target_push_pos = grid_pos + dir
				# KIỂM TRA CHẶN ĐƯỜNG CŨNG DÙNG get_piece_at
				var is_blocked = not is_within_board(target_push_pos) or is_instance_valid(get_piece_at(target_push_pos))
				
				if not is_blocked:
					apply_knockback(unit, dir, 1, 0)
					if unit.has_method("add_buff"):
						unit.add_buff("stun", 0, 1)
				else:
					if unit.has_method("add_buff"):
						unit.add_buff("stun", 0, 1)
func execute_new_wind_wind_spell(target_grids: Array, directions: Array):
	var dir_count = directions.size()
	
	if dir_count == 0:
		# TRƯỜNG HỢP 1: Không có hướng -> Vô hiệu hóa 2 lượt
		for grid_pos in target_grids:
			var target_unit = get_piece_at(grid_pos)
			if is_instance_valid(target_unit) and target_unit.has_method("add_buff"):
				target_unit.add_buff("stun", 0, 3)
				
	elif dir_count == 1:
		# TRƯỜNG HỢP 2: 1 hướng -> Đẩy 2 ô và vô hiệu hóa 1 lượt
		var push_dir = directions[0]
		
		execute_aoe_effect(target_grids, directions, 0, "none", "giogio") 
		
		for grid_pos in target_grids:
			var target_unit = get_piece_at(grid_pos)
			if is_instance_valid(target_unit):
				
				# ---> SỬA SỐ 0 Ở ĐÂY THÀNH 15 (Hoặc sát thương bạn muốn) <---
				apply_knockback(target_unit, push_dir, 2, 15) 
				
				if target_unit.has_method("add_buff"):
					target_unit.add_buff("stun", 0, 2)
					
	else:
		# TRƯỜNG HỢP 3: > 2 hướng -> Vô hiệu hóa diện rộng 1 lượt
		var aoe_grids = target_grids.duplicate()
		for origin in target_grids:
			for dir in directions:
				var affected_grid = origin + dir
				if not aoe_grids.has(affected_grid):
					aoe_grids.append(affected_grid)
		
		for grid_pos in aoe_grids:
			var target_unit = get_piece_at(grid_pos)
			if is_instance_valid(target_unit) and target_unit.has_method("add_buff"):
				target_unit.add_buff("stun", 0, 2)
# --- D. PHÉP ĐẤT (Phòng thủ) ---
func execute_new_earth_spell(target_grids: Array, directions: Array):
	# Gửi "" để báo cho hệ thống biết: "Đừng vẽ gì lên đất cả, lính sẽ tự bật khiên!"
	execute_aoe_effect(target_grids, directions, 1.0, "earth_buff", "")
	Global.add_paper(3)
# --- PHÉP ĐẤT - ĐẤT ---
# Ví dụ hàm của bạn đang là thế này:
func execute_new_earth_earth_spell(target_grids: Array, directions: Array):
	Global.add_paper(5)
	execute_aoe_effect(target_grids, directions, 0.5, "earth_earth_buff", "")
#--------------------------------------------------
#phep gop
func execute_new_fire_water_spell(target_grids: Array, directions: Array):
	print("[Sương Mù] Kích hoạt sương mù bảo vệ!")
	if target_grids.is_empty(): return
	
	# Thưởng 50 mực ngay khi niệm
	Global.add_ink(50)
	
	# 1. Tính toán thời gian tồn tại (Gốc 5 lượt)
	var duration = 5
	if target_grids.size() >= 2:
		duration -= 2 # Phạt nếu chọn 2 tọa độ
	duration = max(1, duration)
	
	# 2. Xử lý hướng trôi (Chỉ nhận 1 hướng duy nhất)
	var spread_dirs = []
	if directions.size() == 1:
		spread_dirs = directions
	else:
		spread_dirs = [] # Đứng im nếu hướng không xác định
		
	# 3. Đặt ô sương mù (Chỉ lấy tọa độ đầu tiên để tránh lỗi nhân bản)
	var center_pos = target_grids[0]
	add_tile_effect(center_pos, "fog_tile", duration, spread_dirs, true)
func execute_new_fire_wind_spell(target_grids: Array, directions: Array):
	print("[Bão Lửa] Kích hoạt bão lửa 3x3!")
	if target_grids.is_empty(): return
	
	# 1. Tính toán thời gian tồn tại
	var duration = 5
	if target_grids.size() >= 2:
		duration -= 2 # Giảm 2 lượt nếu chọn từ 2 tọa độ trở lên
	duration = max(1, duration)
	
	# 2. Xử lý hướng gió (Chỉ nhận 1 hướng)
	var spread_dirs = []
	if directions.size() == 1:
		spread_dirs = directions
	else:
		print("[Bão Lửa] Hướng gió hỗn loạn, bão sẽ đứng im!")
		spread_dirs = [] 
		
	# 3. Nổ hiệu ứng ban đầu
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	
	# 4. Đặt Tâm Bão xuống bàn cờ
	for grid_pos in target_grids:
		add_tile_effect(grid_pos, "firestorm_tile", duration, spread_dirs, true)
func execute_new_water_earth_spell(target_grids: Array, directions: Array):
	print("[Đầm Lầy] Kích hoạt vũng lầy!")
	
	# Nhận thưởng ngay khi niệm
	Global.paper_count += 1
	
	# Tính toán số lượt (Giống hệt Lava)
	var duration = 10
	var dir_count = directions.size()
	
	if dir_count > 1: duration -= (dir_count - 1)
	if target_grids.size() >= 2: duration -= 4
	duration = max(1, duration)
	
	# Kích hoạt hiệu ứng và đặt ô Đầm lầy gốc
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	
	for grid_pos in target_grids:
		add_tile_effect(grid_pos, "swamp_tile", duration, directions, true)
func execute_new_fire_earth_spell(target_grids: Array, directions: Array):
	print("[Dung Nham] Kích hoạt dòng chảy!")
	Global.paper_count += 1
	var duration = 10
	var dir_count = directions.size()
	
	if dir_count > 1: duration -= (dir_count - 1)
	if target_grids.size() >= 2: duration -= 4
	duration = max(1, duration)
	
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	
	# GỌI HÀM CHUNG THAY VÌ HÀM RIÊNG
	for grid_pos in target_grids:
		add_tile_effect(grid_pos, "lava_tile", duration, directions)

# Hàm tạo Ô lửa đặc biệt (Có thể lan truyền)


func execute_new_water_wind_spell(target_grids: Array, directions: Array):
	print("[Cơn Mưa] Kích hoạt đám mây di chuyển!")

	if target_grids.is_empty(): return

	# 1. Tính toán số lượt tồn tại (Giả sử cơ bản là 4 lượt)
	var duration = 6
	
	# Giảm 2 lượt nếu người chơi tham lam chọn từ 2 tọa độ trở lên
	if target_grids.size() >= 2:
		duration -= 2
		
	duration = max(1, duration) # Đảm bảo mây luôn tồn tại ít nhất 1 lượt

	# 2. Xử lý hướng di chuyển của mây
	var spread_dirs = []
	if directions.size() == 1:
		# Đúng 1 hướng -> Mây sẽ trôi theo hướng đó
		spread_dirs = directions
	else:
		# Nếu chọn > 1 hướng (hoặc 0 hướng) -> Mây bị kẹt gió, đứng im tại chỗ
		print("[Cơn Mưa] Gió nhiễu loạn! Đám mây sẽ đứng im.")
		spread_dirs = [] 

	# 3. Kích hoạt hiệu ứng nổ bề mặt (nếu bạn muốn có animation lúc vừa gọi phép)
	execute_aoe_effect(target_grids, directions, 0, "none", "")

	# 4. Đặt đám mây gốc xuống đất
	for grid_pos in target_grids:
		add_tile_effect(grid_pos, "rain_tile", duration, spread_dirs)
func execute_new_wind_earth_spell(target_grids: Array, directions: Array, aoe_value_modifier: float = 1.0):
	if target_grids.is_empty(): return
	
	var origin = target_grids[0]
	var dir_count = directions.size()
	
	# Tính toán lượt và máu
	var duration = max(1, 9 - dir_count) 
	var base_hp = 500.0
	var final_hp = int(base_hp * aoe_value_modifier)
	
	# Danh sách các ô sẽ dựng tường
	var block_grids = [origin]
	for dir in directions:
		var next_grid = origin + dir
		if not block_grids.has(next_grid):
			block_grids.append(next_grid)
			
	# Phát animation AOE tại các ô
	execute_aoe_effect(block_grids, directions, 0, "none", "")
	
	var adj_dirs = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	
	for grid in block_grids:
		if not is_within_board(grid): continue
		
		# LUẬT 1: Không thể tạo trên ô có người -> Trả 1 giấy
		if not is_cell_vacant(grid):
			Global.paper_count += 1 # Sửa lại đúng tên biến Giấy của bạn
			print("Ô có người! Hoàn 1 giấy.")
			continue
			
		# LUẬT 2: Spawn Khối Đất
		spawn_earth_block(grid, final_hp, duration)
		
		# LUẬT 3: Buff đồng minh xung quanh & Nhận 1 giấy/đồng minh
		for adj in adj_dirs:
			var adj_grid = grid + adj
			var unit = get_piece_at(adj_grid)
			
			if is_instance_valid(unit) and unit.get("team") == 1:
				Global.paper_count += 1
				print("Buff đồng minh tại ", adj_grid, ". Nhận 1 giấy.")
				if unit.has_method("add_buff"):
					unit.add_buff("damage_reduction", 0.5, duration) # Buff giảm 50% DMG
func get_all_team_units(team_num: int) -> Array:
	var units = []
	for p in all_pieces:
		if is_instance_valid(p) and p.get("team") == team_num:
			units.append(p)
	return units
func find_unit_at(pos: Vector2i):
	for p in all_pieces:
		if is_instance_valid(p) and p.grid_pos == pos:
			return p
	return null
# Thêm hàm này vào logicgame.gd

func get_king_piece():
	for piece in all_pieces: # (Lưu ý: all_pieces hoặc biến chứa mảng lính của bạn)
		if piece.name == "EnemyKing" or piece.name == "PlayerKing":
			return piece
	return null
# --- 1. HÀM BẮN ĐẠN ---

# --- 2. HÀM NỔ ANIMATION ---
func play_spell_animation(grid_pos: Vector2i, anim_name: String, target_unit = null):
	var effect = SPELL_EFFECT_SCENE.instantiate()
	effect.visible = false 
	get_tree().current_scene.add_child(effect)
	
	# 1. Lấy tọa độ gốc
	var base_pos = Vector2.ZERO
	if target_unit != null:
		base_pos = target_unit.global_position
	else:
		base_pos = grid_to_pixel(grid_pos)
		
	# 2. CỘNG THÊM OFFSET ĐỂ CĂN GIỮA
	# Ví dụ: Vector2(0, -30) sẽ đẩy phép dịch lên trên 30 pixel.
	# Bạn có thể tăng giảm 2 số (X, Y) này cho đến khi nó nằm ngay giữa ô nhé!
	effect.global_position = base_pos + Vector2(0, -30) 
		
	effect.play(anim_name)
	effect.visible = true 
	effect.animation_finished.connect(effect.queue_free)
	
# ==========================================
# HÀM LÕI: TÍNH TOÁN VÀ GÂY SÁT THƯƠNG/HỒI MÁU AOE
# ==========================================
func execute_aoe_effect(target_grids: Array, directions: Array, base_value: float, effect_type: String, ground_anim: String) -> Dictionary:
	# 1. Tính toán hệ số
	var is_multi_target = target_grids.size() > 1
	var multi_factor = 0.4 if is_multi_target else 1.0
	var direction_factor = 1.0 / (directions.size() + 1)
	# Giá trị thực tế trên MỖI LẦN CHẠM
	var value_per_hit = base_value * multi_factor * direction_factor
	
	# 2. Gom nhóm chồng lấp (Stacking)
	var impact_map = {} 
	for center_pos in target_grids:
		_add_to_impact_map(impact_map, center_pos)
		for dir in directions:
			var offset_pos = center_pos + Vector2i(dir.x, dir.y)
			if is_within_board(offset_pos):
				_add_to_impact_map(impact_map, offset_pos)


	# 3. Thi triển lên bàn cờ
	for grid_pos in impact_map.keys():
		var hit_count = impact_map[grid_pos]
		var total_value = value_per_hit * hit_count
		var target_unit = get_unit_at(grid_pos)
		
		# LUẬT 1: Chỉ cho nổ mặt đất nếu phép đó ĐƯỢC CẤP TÊN (như "lua", "nuoc")
		if ground_anim != "":
			play_spell_animation(grid_pos, ground_anim, target_unit)
			
		# LUẬT 2: Giao toàn quyền hiệu ứng cho Trạm Kiểm Soát
		if target_unit != null:
			var push_dir = directions[0] if directions.size() > 0 else Vector2i.ZERO
			apply_unit_effect(target_unit, effect_type, total_value, grid_pos, push_dir)
		else:
			if ground_anim == "":
				print(" -> Ô ", grid_pos, " trống. Phép bay xuyên qua, không có tác dụng.")
	return impact_map
# ==========================================
# TRẠM KIỂM SOÁT HIỆU ỨNG (TÁCH RIÊNG)
# ==========================================
func apply_unit_effect(unit, effect_type: String, value: float, grid_pos: Vector2i, dir: Vector2i = Vector2i.ZERO):
	var unit_name = unit.name 
	
	match effect_type:
		"heal":
			if unit.has_method("heal"):
				unit.heal(value)
				print(" -> Ô ", grid_pos, " Hồi ", value, " máu cho [", unit_name, "]")
				
		"damage":
			deal_damage(unit, value)
			print(" -> Ô ", grid_pos, " Nổ ", value, " sát thương lên [", unit_name, "]")
			
		"earth_buff":
			if unit.has_method("add_buff"):
				unit.add_buff("damage_reduction", value, 1) # Phép Đất thường: 1 lượt
				
		"earth_earth_buff":
			if unit.has_method("add_buff"):
				unit.add_buff("damage_reduction", value, 2) # Phép Đất-Đất: 2 lượt
				
		"stun_1":
			if unit.has_method("add_buff"):
				unit.add_buff("stun", 1.0, 1) # Vô hiệu hóa 1 lượt
		"stun_2":
			if unit.has_method("add_buff"):
				unit.add_buff("stun", 1.0, 2) # Vô hiệu hóa 2 lượt
		"knockback_2":
			if is_instance_valid(unit):
				apply_knockback(unit, dir, 2, 5)
		_:
			print(" -> Ô ", grid_pos, " có hiệu ứng không xác định!")
# ==========================================
# TRẠM QUẢN LÝ Ô HIỆU ỨNG TRÊN BÀN CỜ
# ==========================================
var active_tile_effects = {} # Cấu trúc: { Vector2i(x,y) : {"type": "fire", "turns": 2} }

# 1. Hàm tạo ô hiệu ứng
func add_tile_effect(grid_pos: Vector2i, effect_type: String, duration: int, spread_dirs: Array = [], is_center: bool = true, is_first_spawn: bool = true):
	# --- TRẠM KIỂM SOÁT ĐÁ/TƯỜNG (Chuẩn 100%) ---
	var piece = get_piece_at(grid_pos)
	if is_instance_valid(piece):
		var p_name = piece.name.to_lower() # Chuyển tên thành chữ thường để dễ bắt
		# Chỉ cần tên có chữ wall, earth hoặc rock là chặn đứng ngay lập tức
		if "wall" in p_name or "earth" in p_name or "rock" in p_name:
			print("Vướng cục đá/tường đất tại ", grid_pos, " -> Hủy phép!")
			return 
	# --------------------------------------------
	# ------------------------------------------
	
	if active_tile_effects.has(grid_pos):
		return
		
	var spawned_visual = SPELL_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(spawned_visual)
	
	var base_pos = grid_to_pixel(grid_pos)
	var final_offset = Vector2(0, 0)
	
	match effect_type:
		"water_tile":
			spawned_visual.play("nuocnuoc")
			final_offset = Vector2(0, 10)
			spawned_visual.z_index = 40
		"fire_tile":
			spawned_visual.play("lualua")
			final_offset = Vector2(0, -30)
			spawned_visual.z_index = 100
		"rain_tile": 
			spawned_visual.play("nuocgio")
			spawned_visual.z_index = 100
		"lava_tile": 
			spawned_visual.play("luadat") 
			final_offset = Vector2(0, -30)
			spawned_visual.z_index = 100
		"swamp_tile": # <--- THÊM ĐẦM LẦY VÀO ĐÂY
			spawned_visual.play("nuocdat") # Đảm bảo bạn có tạo animation này nhé
			final_offset = Vector2(0, -10) # Bù trừ Y nếu cần để nó nằm sát mặt đất
			spawned_visual.z_index = 40
		"firestorm_tile": # <--- THÊM BÃO LỬA
			spawned_visual.play("luagio") # Chắc chắn bạn đã tạo animation tên này
			final_offset = Vector2(0, -30)
			spawned_visual.z_index = 100
		"fog_tile": 
			final_offset = Vector2(0, -20)
			spawned_visual.z_index = 150 
			
			# Luôn luôn chạy luanuoc1
			spawned_visual.play("luanuoc1")
			
			if is_first_spawn:
				# Nếu mới đẻ ra -> Chạy từ hình đầu tiên (khói bốc lên)
				spawned_visual.frame = 0
			else:
				# Nếu đang trôi đi -> Nhảy thẳng vào hình số 2 (sương mù lờ mờ)
				spawned_visual.frame = 2 
			
			# --- TUYỆT CHIÊU HACK VÒNG LẶP ---
			var custom_loop = func():
				if is_instance_valid(spawned_visual) and spawned_visual.animation == "luanuoc1":
					# Mỗi khi Godot định lặp lại từ đầu (về 0), ta bẻ lái nó sang hình số 2
					spawned_visual.frame = 2
					
			# Lắng nghe tín hiệu lặp lại
			if not spawned_visual.animation_looped.is_connected(custom_loop):
				spawned_visual.animation_looped.connect(custom_loop)
		
		
	spawned_visual.global_position = base_pos + final_offset
	
	# 1. Khai báo thông tin lưu trữ vào mảng (Giữ nguyên như cũ)
	active_tile_effects[grid_pos] = {
		"type": effect_type,
		"turns": duration,
		"visual_node": spawned_visual,
		"is_new": true,
		"spread_dirs": spread_dirs,
		"is_center": is_center, 
		"age": 0              
	} # <--- LƯU Ý DẤU ĐÓNG NGOẶC NHỌN Ở ĐÂY
	
	# 2. DÁN ĐOẠN CODE GÂY SÁT THƯƠNG RA BÊN NGOÀI (Nằm dưới dấu } ở trên)
	if is_first_spawn and is_instance_valid(piece):
		match effect_type:
			"swamp_tile":
				if piece.has_method("add_buff"): piece.add_buff("root", 0, 3)
				print("-> Đầm lầy vừa trúng đích, trói chân ngay lập tức: ", piece.name)
			"fire_tile", "lava_tile", "firestorm_tile":
				if piece.has_method("take_damage"): piece.take_damage(10.0) 
				print("-> Lửa vừa rơi trúng đầu, đốt ngay lập tức: ", piece.name)
			"water_tile", "rain_tile":
				if piece.has_method("heal"): piece.heal(20)
func process_all_tile_effects():
	var grids_to_remove = []
	var new_puddle_tiles = [] # Dùng chung cho cả Dung Nham và Đầm Lầy
	var new_rain_tiles = [] 
	var new_firestorm_tiles = []
	var new_fog_tiles = []
	
	for grid_pos in active_tile_effects.keys():
		var effect = active_tile_effects[grid_pos]
		
		# 1. ĐỒNG BỘ THỜI GIAN
		effect["turns"] -= 1
		
		if effect["turns"] <= 0: 
			grids_to_remove.append(grid_pos)
			continue
		
		if effect.get("is_new", false):
			effect["is_new"] = false
			continue
			
		effect["age"] = effect.get("age", 0) + 1
		var current_age = effect["age"]
		
		match effect["type"]:
			"water_tile":
				var unit = get_unit_at(grid_pos)
				if unit:
					if unit.has_method("heal"): unit.heal(20)
					if unit.get("team") == 1: Global.add_ink(50)
					
			"fire_tile", "lava_tile": 
				var unit = get_unit_at(grid_pos)
				if unit: 
					deal_damage(unit, 10.0)
					if effect["type"] == "lava_tile" and unit.get("team") == 1:
						Global.paper_count -= 1
						
			"swamp_tile": # <--- HIỆU ỨNG CỦA ĐẦM LẦY Ở ĐÂY
				var unit = get_unit_at(grid_pos)
				if is_instance_valid(unit):
					# Hồi máu qua mỗi lượt
					if unit.has_method("heal"): 
						unit.heal(20) 
					# Trói chân (Root)
					if unit.has_method("add_buff"):
						unit.add_buff("root", 0, 2)
					if unit.get("team") == 1: 
						Global.add_ink(50)
					
								
			"rain_tile":
				# --- PHẦN 1: CODE HỒI MÁU VÀ NHẬN MỰC CỦA BẠN (Đã giữ nguyên) ---
				var unit = get_unit_at(grid_pos)
				if is_instance_valid(unit):
					if unit.has_method("heal"): unit.heal(50)
					if unit.get("team") == 1:
						Global.add_ink(50)
						if "King" in unit.name or "Player" in unit.name:
							Global.paper_count -= 1

				# --- PHẦN 2: LOGIC DI CHUYỂN RẮN SĂN MỒI ---
				if effect.get("is_center", false): # NẾU Ô NÀY ĐANG LÀ CÁI ĐẦU
					for dir in effect.get("spread_dirs", []):
						var next_pos = grid_pos + dir
						if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
							# Sinh ra Đầu mới
							new_rain_tiles.append({
								"pos": next_pos,
								"turns": effect["turns"], 
								"dirs": [dir], 
								"is_center": true,
								"is_first_spawn": false
							})
							# Giáng chức Đầu cũ thành Đuôi
							effect["is_center"] = false
							effect["tail_life"] = 1 
				else: # NẾU LÀ CÁI ĐUÔI
					if effect.has("tail_life"):
						effect["tail_life"] -= 1
						# Đuôi sống hết 1 lượt thì xóa
						if effect["tail_life"] <= 0:
							if not grids_to_remove.has(grid_pos):
								grids_to_remove.append(grid_pos)
			"fog_tile":
				# --- CHỈ CHỨA LOGIC DI CHUYỂN RẮN SĂN MỒI ---
				if effect.get("is_center", false): # NẾU Ô NÀY ĐANG LÀ CÁI ĐẦU
					for dir in effect.get("spread_dirs", []):
						var next_pos = grid_pos + dir
						if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
							# Sinh ra Đầu mới
							new_fog_tiles.append({
								"pos": next_pos,
								"turns": effect["turns"], 
								"dirs": [dir], 
								"is_center": true,
								"is_first_spawn": false
							})
							# Giáng chức Đầu cũ thành Đuôi
							effect["is_center"] = false
							effect["tail_life"] = 1 
				else: # NẾU LÀ CÁI ĐUÔI
					if effect.has("tail_life"):
						effect["tail_life"] -= 1
						# Đuôi sống hết 1 lượt thì xóa
						if effect["tail_life"] <= 0:
							if not grids_to_remove.has(grid_pos):
								grids_to_remove.append(grid_pos)
			"firestorm_tile":
				var base_dmg = 15.0 # Sát thương cơ bản
				var center_pos_i = Vector2i(grid_pos)
				
				# 1. NỔ NGAY TẠI CHỖ HIỆN TẠI
				apply_firestorm_impact(center_pos_i, base_dmg)
				
				# Logic di chuyển Tâm bão
				if effect.get("is_center", false):
					for dir in effect.get("spread_dirs", []):
						var next_pos = center_pos_i + dir
						
						if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
							new_firestorm_tiles.append({
								"pos": next_pos,
								"turns": effect["turns"], 
								"dirs": [dir] 
							})
							
							# 2. CHỐT CHẶN: QUÉT SÁT THƯƠNG Ở Ô TIẾP THEO MÀ BÃO VỪA ĐI TỚI
							# Điều này khiến lính không thể kịp chạy thoát
							apply_firestorm_impact(next_pos, base_dmg)
							
							# Xóa tâm bão ở ô cũ để nó di chuyển dứt khoát
							if not grids_to_remove.has(center_pos_i):
								grids_to_remove.append(center_pos_i)
				
				# Logic di chuyển Tâm bão
				if effect.get("is_center", false):
					for dir in effect.get("spread_dirs", []):
						var next_pos = center_pos_i + dir
						
						if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
							new_firestorm_tiles.append({
								"pos": next_pos,
								"turns": effect["turns"], 
								"dirs": [dir] 
							})
							
							# Xóa tâm bão ở ô cũ để nó di chuyển dứt khoát
							if not grids_to_remove.has(center_pos_i):
								grids_to_remove.append(center_pos_i)
			
		# --- LOGIC LAN TRUYỀN 3x3 GỘP CHUNG (LAVA & SWAMP) ---
		if effect["type"] in ["lava_tile", "swamp_tile"] and effect.get("is_center", false):
			for dir in effect.get("spread_dirs", []):
				var is_orthogonal = (abs(dir.x) + abs(dir.y) == 1)
				var is_diagonal = (abs(dir.x) + abs(dir.y) == 2)
				var should_spread = false
				
				if current_age == 1 and is_orthogonal: should_spread = true
				elif current_age == 2 and is_diagonal: should_spread = true
					
				if should_spread:
					var next_pos = grid_pos + dir
					if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
						new_puddle_tiles.append({
							"pos": next_pos,
							"type": effect["type"], # Tự động copy loại của mẹ (Lava đẻ Lava, Swamp đẻ Swamp)
							"turns": effect["turns"], 
							"dirs": [] 
						})

	# --- DỌN DẸP & SINH Ô MỚI ---
	for pos in grids_to_remove:
		_remove_tile_effect(pos)
		
	for puddle in new_puddle_tiles:
		# Truyền false để các ô con không lan tiếp, khóa chặt ở 3x3
		add_tile_effect(puddle["pos"], puddle["type"], puddle["turns"], puddle["dirs"], false)
		
	for rain in new_rain_tiles:
		add_tile_effect(rain["pos"], "rain_tile", rain["turns"], rain["dirs"], true)
	for storm in new_firestorm_tiles:
		add_tile_effect(storm["pos"], "firestorm_tile", storm["turns"], storm["dirs"], true)
	for fog in new_fog_tiles:
		add_tile_effect(fog["pos"], "fog_tile", fog["turns"], fog["dirs"], true, fog.get("is_first_spawn", true))
	
func _remove_tile_effect(grid_pos: Vector2i):
	if active_tile_effects.has(grid_pos):
		var effect_data = active_tile_effects[grid_pos]
		if is_instance_valid(effect_data.get("visual_node")):
			effect_data["visual_node"].queue_free()
		active_tile_effects.erase(grid_pos)
func spawn_earth_block(grid_pos: Vector2i, hp: int, turns: int):
	# Load file tscn của bạn (chắc chắn đường dẫn đúng với project của bạn)
	var block_scene = preload("res://earth_wall.tscn")
	var block = block_scene.instantiate()
	
	# Set chỉ số (Trong script earth_wall.gd hoặc pawn.gd bạn phải có các biến này)
	block.name = "EarthBlock_" + str(randi() % 1000)
	block.set("hp", hp)
	block.set("max_hp", hp)
	block.set("duration", turns) 
	block.set("team", 1) # Set team 1 để quái địch (team 2) nhận diện đây là kẻ thù
	
	# Set animation
	var visual = block.get_node_or_null("giodat")
	if is_instance_valid(visual):
		visual.play("giodat")
		
	# Đưa vào bàn cờ
	add_child(block)
	block.global_position = grid_to_pixel(grid_pos)
	
	if block.has_method("set_grid_position"):
		block.set_grid_position(grid_pos)
	else:
		block.set("grid_pos", grid_pos)
		
	# Ép vào mảng quản lý lính để nó có thể bị đánh
	all_pieces.append(block)
func is_tile_foggy(grid_pos: Vector2i) -> bool:
	if active_tile_effects.has(grid_pos):
		return active_tile_effects[grid_pos]["type"] == "fog_tile"
	return false
func cast_random_flight(unit):
	var empty_cells = []
	
	# Quét toàn bộ bàn cờ để tìm các ô trống (Không có lính đứng)
	# LƯU Ý: Đổi 8, 8 thành biến chiều dài/rộng bàn cờ thực tế của bạn
	for x in range(0, 8): 
		for y in range(0, 8):
			var test_pos = Vector2i(x, y)
			if get_unit_at(test_pos) == null and is_within_board(test_pos): 
				empty_cells.append(test_pos)
				
	# Nếu bàn cờ vẫn còn chỗ trống
	if empty_cells.size() > 0:
		# 1. Chọn Ô ngẫu nhiên
		var random_pos = empty_cells[randi() % empty_cells.size()]
		
		# 2. Chọn Hướng ngẫu nhiên
		var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		var random_dir = dirs[randi() % dirs.size()]
		
		# 3. Dịch chuyển Player
		unit.grid_pos = random_pos
		unit.global_position = grid_to_pixel(random_pos) # (Bạn có thể thay bằng Tween nếu muốn bay mượt)
		
		# 4. Cập nhật hướng cho Player (Nếu script của Player có biến "direction")
		if unit.get("direction") != null:
			unit.direction = random_dir
# Hàm này dùng để bắt các ô bị Gió thổi qua phải nhả sát thương/hồi máu lập tức
# Hàm này dùng để bắt các ô bị Gió thổi qua phải Bùng Lên và nhả hiệu ứng lập tức
func _trigger_immediate_tile_effect(grid_pos: Vector2i, type: String, unit):
	print("-> [Phép Gió] Vừa quạt trúng ô hiệu ứng: ", type)
	
	# 1. ÉP Ô CŨ PHẢI BÙNG SÁNG LÊN
	if active_tile_effects.has(grid_pos):
		var visual = active_tile_effects[grid_pos].get("visual_node")
		if is_instance_valid(visual):
			visual.modulate = Color(2.0, 2.0, 2.0, 1) 
			var tw = get_tree().create_tween()
			tw.tween_property(visual, "scale", Vector2(1.4, 1.4), 0.1)
			tw.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.2)
			tw.tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.2)
			
	# 2. XỬ LÝ SÁT THƯƠNG / HỒI MÁU
	if not is_instance_valid(unit): return
		
	match type:
		"water_tile", "swamp_tile":
			if unit.has_method("heal"): unit.heal(20)
			if type == "water_tile" and unit.get("team") == 1: Global.add_ink(50)
			if type == "swamp_tile" and unit.has_method("add_buff"): unit.add_buff("root", 0, 2)
			
		"fire_tile", "lava_tile", "firestorm_tile":
			# Sửa lại sát thương cho chuẩn với unit của bạn
			if unit.has_method("take_damage"):
				unit.take_damage(15.0) 
			elif has_method("deal_damage"):
				deal_damage(unit, 15.0)
				
		"rain_tile":
			if unit.has_method("heal"): unit.heal(30)
			if unit.get("team") == 1: Global.add_ink(50)
func play_wind_visual(grid_pos: Vector2i, anim_name: String):
	var spawned_visual = SPELL_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(spawned_visual)
	
	spawned_visual.global_position = grid_to_pixel(grid_pos)
	spawned_visual.z_index = 150 
	spawned_visual.play(anim_name)
	
	spawned_visual.animation_finished.connect(func(): spawned_visual.queue_free(), CONNECT_ONE_SHOT)
# TRONG LOGICGAME.GD
func check_trap_at(unit, grid_pos):
	# Kiểm tra xem ô quái vừa bước vào có nằm trong vùng bão không
	for effect_pos in active_tile_effects:
		var effect = active_tile_effects[effect_pos]
		
		if effect.name == "firestorm_tile":
			# Tính khoảng cách từ quái đến TÂM BÃO
			var distance = grid_pos - effect_pos
			
			# Nếu quái nằm trong vùng 3x3 (Khoảng cách dx, dy từ -1 đến 1)
			if abs(distance.x) <= 1 and abs(distance.y) <= 1:
				
				# Bưng nguyên logic sát thương và knockback của bạn xuống đây!
				var push_dir = distance
				# ... (thực hiện đẩy lùi quái và deal damage ngay lập tức) ...
# TRONG LOGICGAME.GD

func apply_firestorm_impact(center_pos_i: Vector2i, base_dmg: float):
	# Quét vùng 3x3 xung quanh tâm được chỉ định
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_pos = center_pos_i + Vector2i(dx, dy)
			var unit = get_unit_at(check_pos)
			
			if is_instance_valid(unit):
				if dx == 0 and dy == 0:
					deal_damage(unit, base_dmg)
				else:
					var push_dir = Vector2i(dx, dy)
					var target_push_pos = check_pos + push_dir
					
					var is_blocked = not is_within_board(target_push_pos) or is_instance_valid(get_unit_at(target_push_pos))
					
					if is_blocked:
						deal_damage(unit, base_dmg * 2.0)
					else:
						if unit.has_method("move_to_grid"):
							# Dùng đúng 2 tham số như hàm move_to_grid yêu cầu
							var target_pixel_pos = grid_to_pixel(target_push_pos)
							unit.move_to_grid(target_push_pos, target_pixel_pos)
						deal_damage(unit, base_dmg)

func backup_player_pieces():
	player_pieces_backup.clear()
	for p in all_pieces:
		if is_instance_valid(p) and p.team == 1:
			var data = {
				# Dùng scene_file_path thay vì filename cho Godot 4
				"scene_path": p.scene_file_path, 
				"grid_pos": p.grid_pos,
				"hp": p.current_health,
				"name": p.name
			}
			player_pieces_backup.append(data)
	print("Đã lưu trạng thái lính! Số lượng: ", player_pieces_backup.size())
func _on_chơi_lại_pressed():
	
	Global.current_wave = 1
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_chơi_lại_2_pressed() :
	restart_current_wave()
func restart_current_wave():
	force_release_all_grabs()
	
	# 1. RESET TURN VỀ 1
	current_turn = 1
	if turn_label: 
		turn_label.text = "Turn: 1"
	
	# 2. DỌN SẠCH BÀN CỜ
	for p in all_pieces:
		if is_instance_valid(p):
			p.queue_free()
	all_pieces.clear()
	
	# 3. HỒI SINH QUÂN TA
	for data in player_pieces_backup:
		# Đảm bảo đường dẫn tồn tại thì mới load
		if data["scene_path"] != null and data["scene_path"] != "":
			var p_scene = load(data["scene_path"])
			var p = p_scene.instantiate()
			
			p.team = 1
			# Phải add vào piece_layer thì lính mới hiện lên đúng vị trí
			if has_node("PieceLayer"):
				get_node("PieceLayer").add_child(p)
			else:
				add_child(p) 
				
			all_pieces.append(p)
			
			# Phục hồi chỉ số
			p.grid_pos = data["grid_pos"]
			p.position = grid_to_pixel(p.grid_pos) # Đặt đúng tọa độ
			p.current_health = data["hp"]
			p.name = data["name"]
			
			if p.has_node("HealthBar"):
				p.get_node("HealthBar").value = p.current_health
			if p.has_method("update_visuals"):
				p.update_visuals()

	# 4. TẠO LẠI ĐỊCH & SỬA HƯỚNG MẶT
	spawn_enemy_wave()

		
	# 5. TẮT MÀN HÌNH THUA
	if lose_screen: lose_screen.hide()
	set("can_interact", true) # Mở khóa click chuột
	get_tree().paused = false
func show_lose_screen():
	print("Vua đã băng hà! GAME OVER!")
	
	# Khóa tương tác chuột (nếu bạn có dùng biến này)
	if "can_interact" in self:
		set("can_interact", false)
	
	# Hiện màn hình Thua
	if "lose_screen" in self and lose_screen:
		lose_screen.show()
	elif has_node("CanvasLayer/LosePanel"):
		get_node("CanvasLayer/LosePanel").show()
		
	# Tạm dừng game
	get_tree().paused = true
