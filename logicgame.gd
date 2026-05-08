extends Node2D

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
const FIRE_TILE_SCENE = preload("res://fire_tile.tscn")
func _ready():
	add_to_group("logic_board")
	player_unit = get_tree().get_first_node_in_group("player")
	if wave_label:
		wave_label.text = "Wave: " + str(Global.current_wave)
	piece_layer = Node2D.new()
	piece_layer.name = "PieceLayer"
	add_child(piece_layer)
	
	spawn_initial_army()
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
func check_and_trigger_next_wave():
	if Global.current_wave >= 5:
		trigger_victory()
		return
	transition_to_next_wave()
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
	if event is InputEventKey and event.pressed:
		
		# Trả lại tên cũ là coords cho các phím dưới khỏi báo lỗi
		var coords = ["B", "2", "E", "4"] 
		var dirs = [] 
		#dirs.append(Vector2i(1, 0))   # Phải (Right)
		#dirs.append(Vector2i(-1, 0))  # Trái (Left)
		#dirs.append(Vector2i(0, -1))  # Lên (Up)
		#dirs.append(Vector2i(0, 1))   # Xuống (Down)
		#dirs.append(Vector2i(1, 1))   # Chéo Xuống Phải
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
			print("[DEBUG] HỢP ẤN 6: Gió + Đất -> Bão cát (Giảm tầm đánh)")
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
		if is_instance_valid(p) and "stun_turns" in p and p.stun_turns > 0:
			p.stun_turns -= 1
			
			# Hết choáng thì mới xóa hình ảnh vòng xoáy
			if p.stun_turns <= 0:
				p.stun_turns = 0
				var wind_visual = p.get("current_wind_visual")
				if is_instance_valid(wind_visual):
					wind_visual.queue_free()
	
	# 1. BÁO CHO TRẠM QUẢN LÝ Ô HIỆU ỨNG CHẠY
	# Lửa sẽ đốt máu và tự đếm ngược lượt tắt
	process_all_tile_effects()
	

	# Vì bàn cờ của bạn là 8x8, ta sẽ dùng 2 vòng lặp quét qua tất cả các ô
	for x in range(8):
		for y in range(8):
			var pos = Vector2i(x, y)
			var unit = get_unit_at(pos)
			
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
	process_all_tile_effects()
func execute_all_combat_logic():
	for p in all_pieces:
		if not is_instance_valid(p): continue
		
		# 1. CHỈ CHẶN, TUYỆT ĐỐI KHÔNG TRỪ LƯỢT Ở ĐÂY
		if "stun_turns" in p and p.stun_turns > 0:
			print("Lính ", p.name, " đang choáng, bỏ qua tấn công!")
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
		if p.get("is_grabbed") == true or "King" in p.name or "boss" in p.name.to_lower() or "dragon" in p.name.to_lower():
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
			#SpellDictionary.Element.WIND:
				#execute_new_wind_spell(target_grids, directions) # Cứ viết sẵn tên hàm, sau này tạo hàm sau

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
			if has_fire and has_water: return
				#xecute_new_fire_water_spell(target_grids, directions)
				
			# Lửa + Đất
			elif has_fire and has_earth:return
				#xecute_new_fire_earth_spell(target_grids, directions)
				
			# Lửa + Gió
			elif has_fire and has_wind:return
				#xecute_new_fire_wind_spell(target_grids, directions)
				
			# Nước + Đất
			elif has_water and has_earth:return
				#execute_new_water_earth_spell(target_grids, directions)
				
			# Nước + Gió
			elif has_water and has_wind:return
				#execute_new_water_wind_spell(target_grids, directions)
				
			# Đất + Gió
			elif has_earth and has_wind:return
				#execute_new_earth_wind_spell(target_grids, directions)
func execute_new_fire_spell(target_grids: Array, directions: Array):
	print("[Phép Lửa] Bắt đầu gọi thiên thạch...")
	
	# Gọi hàm lõi: Base 35, loại "damage", hiệu ứng "lua"
	execute_aoe_effect(target_grids, directions, 35.0, "damage", "lua")
# --- PHÉP LỬA CƯỜNG HÓA ---
# --- PHÉP LỬA - LỬA ---
# --- PHÉP LỬA - LỬA ---
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
func execute_new_wind_wind_spell(target_grids: Array, directions: Array):
	var dir_count = directions.size()
	
	if dir_count == 0:
		# TRƯỜNG HỢP 1: Không có hướng -> Vô hiệu hóa 2 lượt
		for grid_pos in target_grids:
			var target_unit = get_piece_at(grid_pos)
			if is_instance_valid(target_unit) and target_unit.has_method("add_buff"):
				target_unit.add_buff("stun", 0, 2)
				
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
					target_unit.add_buff("stun", 0, 1)
					
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
				target_unit.add_buff("stun", 0, 1)
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
func add_tile_effect(grid_pos: Vector2i, effect_type: String, duration: int):
	# KIỂM TRA NGHIÊM NGẶT: Nếu ô đã có hiệu ứng (bất kể loại nào), thoát ngay.
	if active_tile_effects.has(grid_pos):
		return 

	# Nếu ô trống, tiến hành tạo mới
	var spawned_visual = SPELL_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(spawned_visual)
	var base_pos = grid_to_pixel(grid_pos)
	var final_offset = Vector2(0, 0)
	# Chọn Animation dựa trên loại hiệu ứng
	match effect_type:
		"water_tile":
			spawned_visual.play("nuocnuoc")
			final_offset = Vector2(0, 10)
			spawned_visual.z_index = 40
		"fire_tile":
			final_offset = Vector2(0, -30)
			spawned_visual.play("lualua")
			spawned_visual.z_index = 100
	spawned_visual.global_position = base_pos + final_offset
	active_tile_effects[grid_pos] = {
		"type": effect_type,
		"turns": duration,
		"visual_node": spawned_visual,
		"is_new": true # Cờ miễn trừ trừ lượt đầu tiên
	}
func process_all_tile_effects():
	var grids_to_remove = []
	for grid_pos in active_tile_effects.keys():
		var effect = active_tile_effects[grid_pos]
		
		if effect.get("is_new", false):
			effect["is_new"] = false
			continue
			
		# Chuyển logic từ ảnh của bạn vào đây
		match effect["type"]:
			"water_tile":
				var unit = get_unit_at(grid_pos)
				if unit:
					if unit.has_method("heal"): unit.heal(20)
					if unit.get("team") == 1: Global.add_ink(50)
			"fire_tile":
				var unit = get_unit_at(grid_pos)
				if unit: deal_damage(unit, 10.0)

		effect["turns"] -= 1
		if effect["turns"] <= 0: grids_to_remove.append(grid_pos)

	for pos in grids_to_remove:
		_remove_tile_effect(pos)
func _remove_tile_effect(grid_pos: Vector2i):
	if active_tile_effects.has(grid_pos):
		var effect_data = active_tile_effects[grid_pos]
		if is_instance_valid(effect_data.get("visual_node")):
			effect_data["visual_node"].queue_free()
		active_tile_effects.erase(grid_pos)
