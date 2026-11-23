class_name CombatResolver
extends RefCounted
## Owns unit AI, attack allowances, damage, grabs and knockback.
## Board supplies positions and campaign state; presentation subscribes to events.

signal attack_started(attacker: Piece)
signal damage_resolved(result: Dictionary)
signal attack_animation_requested(attacker: Piece, target_pos: Vector2i)
signal projectile_requested(start_pos: Vector2, end_pos: Vector2)

var board: Node

func _init(context: Node) -> void:
	board = context

func deal_damage(unit, amount: float) -> void:
	if not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return
	var health_key: String = "current_health" if unit is Piece else "hp"
	var before: float = float(unit.get(health_key))
	if unit.has_method("take_damage"):
		unit.take_damage(amount)
		var after: float = float(unit.get(health_key))
		damage_resolved.emit({"target": unit, "amount": before - after, "remaining_health": after})

func queen_grab_counter(queen):
	var grabber = queen.grabbed_by
	if not _is_living_target(grabber):
		return
	var aim_dir = grabber.grid_pos - queen.grid_pos
	var sprite = queen.get_node_or_null("Sprite2D")
	if sprite:
		if abs(aim_dir.x) > abs(aim_dir.y):
			sprite.frame = 1 if aim_dir.x > 0 else 2
		else:
			sprite.frame = 0 if aim_dir.y > 0 else 3
	while _is_living_target(queen.grabbed_by) and _begin_piece_attack(queen):
		var target_to_hit = queen.grabbed_by
		var dir_to_grabber = target_to_hit.grid_pos - queen.grid_pos
		var side_dirs = [Vector2i(-dir_to_grabber.y, dir_to_grabber.x), Vector2i(dir_to_grabber.y, -dir_to_grabber.x)]
		var target_pos: Vector2i = target_to_hit.grid_pos
		deal_damage(target_to_hit, queen.definition.melee_damage)
		for side in side_dirs:
			var side_unit = board.get_piece_at(target_pos + side)
			if _is_living_target(side_unit) and side_unit.team != queen.team:
				deal_damage(side_unit, queen.definition.melee_damage)

func find_queen_ranged_target(queen):
	var directions = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)
	]
	var closest_target = null
	var min_dist = 999
	for dir in directions:
		for i in range(1, queen.definition.attack_range + 1):
			var scan_pos = queen.grid_pos + dir * i
			if not board.is_within_board(scan_pos): break
			var unit = board.get_piece_at(scan_pos)
			if unit:
				if unit.team != queen.team:
					if i < min_dist:
						min_dist = i
						closest_target = unit
				break
	return closest_target

func execute_all_combat_logic():
	for p in board.all_pieces.duplicate():
		if board.game_finished: return
		if not is_instance_valid(p) or p.is_queued_for_deletion(): continue
		if board.is_tile_foggy(p.grid_pos) or ("stun_turns" in p and p.stun_turns > 0): continue
		if p.is_grabbed:
			if UnitDefinition.is_kind(p, UnitDefinition.Kind.QUEEN):
				queen_grab_counter(p)
			elif UnitDefinition.is_kind(p, UnitDefinition.Kind.KNIGHT):
				execute_knight_logic(p)
			elif UnitDefinition.is_kind(p, UnitDefinition.Kind.BISHOP):
				execute_bishop_logic(p)
			else:
				while _is_living_target(p.grabbed_by) and _begin_piece_attack(p):
					if p.has_method("play_attack_animation"):
						attack_animation_requested.emit(p, p.grabbed_by.grid_pos)
					deal_damage(p.grabbed_by, p.definition.melee_damage)
		else:
			if UnitDefinition.is_kind(p, UnitDefinition.Kind.ROOK):
				execute_rook_logic(p)
			elif UnitDefinition.is_kind(p, UnitDefinition.Kind.BISHOP):
				execute_bishop_logic(p, false)


func _is_living_target(target) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion()


func _begin_piece_attack(piece: Piece) -> bool:
	if board.game_finished or not _is_living_target(piece) or board.is_tile_foggy(piece.grid_pos):
		return false
	if not piece.try_begin_attack():
		return false
	attack_started.emit(piece)
	return true

func move_team_logic(team_num: int):
	for p in board.all_pieces.duplicate():
		if board.game_finished: return
		if not is_instance_valid(p) or p.is_queued_for_deletion() or p.team != team_num: continue
		if ("stun_turns" in p and p.stun_turns > 0) or ("root_turns" in p and p.root_turns > 0): continue
		if p.get("is_grabbed") == true:
			if team_num == 1 and board.current_command == board.Command.DEFEND:
				force_release_all_grabs(p)
			else:
				continue
		if UnitDefinition.is_kind(p, UnitDefinition.Kind.KING) or UnitDefinition.is_kind(p, UnitDefinition.Kind.DRAGON):
			continue
		if UnitDefinition.is_kind(p, UnitDefinition.Kind.EARTH_WALL):
			continue
		if p.has_moved: continue
		if UnitDefinition.is_kind(p, UnitDefinition.Kind.ROOK):
			if not p.is_charging:
				p.is_charging = true
				p.has_moved = true
				p.set_meta("just_charged", true)
				if p.has_method("update_visuals"): p.update_visuals()
				continue
		if team_num == 1:
			if board.current_command == board.Command.IDLE: continue
			elif board.current_command == board.Command.DEFEND:
				var king_target = board.find_my_king(1)
				if king_target:
					var next = get_next_step_towards(p.grid_pos, king_target.grid_pos)
					if board.is_cell_vacant(next): board.move_piece(p, next)
				continue
		if (team_num == 1 and board.current_command == board.Command.ATTACK) or team_num == 2:
			var acted = false
			if UnitDefinition.is_kind(p, UnitDefinition.Kind.QUEEN):
				execute_queen_logic(p)
				acted = true
			elif UnitDefinition.is_kind(p, UnitDefinition.Kind.KNIGHT):
				execute_knight_logic(p)
				acted = true
			elif UnitDefinition.is_kind(p, UnitDefinition.Kind.BISHOP):
				execute_bishop_logic(p)
				acted = true
			elif UnitDefinition.is_kind(p, UnitDefinition.Kind.ROOK):
				acted = true
			if acted: continue
			var target = find_best_target(p)
			if target:
				var next = get_next_step_towards(p.grid_pos, target.grid_pos)
				if board.is_cell_vacant(next): board.move_piece(p, next)

func find_best_target(for_piece):
	var enemy_king = null
	var enemy_soldiers = []
	for p in board.all_pieces:
		if is_instance_valid(p) and p.team != for_piece.team:
			if UnitDefinition.is_kind(p, UnitDefinition.Kind.KING):
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
	var dirs = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var valid_moves = []
	for d in dirs:
		var test_pos = start + d
		if board.is_within_board(test_pos) and board.is_cell_vacant(test_pos):
			var dist = Vector2(test_pos).distance_to(Vector2(target))
			if abs(d.x) + abs(d.y) == 1:
				dist -= 0.1
			valid_moves.append({"pos": test_pos, "dist": dist})
	valid_moves.sort_custom(func(a, b): return a["dist"] < b["dist"])
	if valid_moves.size() > 0:
		var current_dist = Vector2(start).distance_to(Vector2(target))
		if valid_moves[0]["dist"] <= current_dist:
			return valid_moves[0]["pos"]
		return valid_moves[0]["pos"]
	return start

func execute_queen_logic(queen):
	if queen.is_reloading:
		return
	var target = find_queen_ranged_target(queen)
	while _is_living_target(target) and queen.current_ammo > 0 and not queen.is_reloading and _begin_piece_attack(queen):
		projectile_requested.emit(queen.global_position, target.global_position)
		deal_damage(target, queen.definition.ranged_damage)
		queen.current_ammo -= 1
		if queen.has_node("AmmoBar"):
			queen.get_node("AmmoBar").value = queen.current_ammo
		if queen.current_ammo <= 0:
			queen.is_reloading = true
			queen.reload_turns_left = queen.definition.reload_turns
		# Each shot requires a live target and spends a real round of ammunition.
		target = find_queen_ranged_target(queen)

func get_surrounding_cells(pos: Vector2i, dist: int) -> Array:
	var cells = []
	for x in range(-dist, dist + 1):
		for y in range(-dist, dist + 1):
			if x == 0 and y == 0: continue
			var c = pos + Vector2i(x, y)
			if board.is_within_board(c): cells.append(c)
	return cells

func execute_rook_attack(rook, target_unit) -> bool:
	if not _is_living_target(target_unit) or not _begin_piece_attack(rook):
		return false
	var dir = (target_unit.grid_pos - rook.grid_pos)
	var forward = Vector2i(sign(dir.x), sign(dir.y))
	var side = Vector2i(-forward.y, forward.x)
	var sprite = rook.get_node_or_null("Sprite2D")
	if sprite:
		if forward.x > 0: sprite.frame = 1
		elif forward.x < 0: sprite.frame = 2
		elif forward.y > 0: sprite.frame = 0
		elif forward.y < 0: sprite.frame = 3
	for i in range(1, rook.definition.attack_range + 1):
		var pos = rook.grid_pos + forward * i
		var unit = board.get_piece_at(pos)
		if unit and unit.team != rook.team:
			deal_damage(unit, rook.definition.ranged_damage)
			apply_knockback(unit, forward, rook.definition.push_distance, rook.definition.impact_damage)
	var sides = [rook.grid_pos + side, rook.grid_pos - side]
	for s_pos in sides:
		var unit = board.get_piece_at(s_pos)
		if unit and unit.team != rook.team:
			deal_damage(unit, rook.definition.secondary_damage)
	return true


func _apply_rook_recoil(rook, forward: Vector2i) -> void:
	if board.game_finished or not _is_living_target(rook):
		return
	var back_pos = rook.grid_pos - forward

	if not board.is_within_board(back_pos):
		deal_damage(rook, rook.definition.self_impact_damage)
	elif not board.is_cell_vacant(back_pos):
		var back_unit = board.get_piece_at(back_pos)
		deal_damage(rook, rook.definition.self_impact_damage)
		deal_damage(back_unit, rook.definition.self_impact_damage)
	else:
		board.move_piece(rook, back_pos)

func execute_rook_logic(rook):
	if not rook.is_charging:
		return
	if rook.has_meta("just_charged") and rook.get_meta("just_charged") == true:
		rook.set_meta("just_charged", false)
		return
	var target = _find_rook_target(rook)
	if target != null:
		var recoil_dir: Vector2i = (target.grid_pos - rook.grid_pos).sign()
		var attacked: bool = false
		while _is_living_target(target) and execute_rook_attack(rook, target):
			attacked = true
			target = _find_rook_target(rook)
		if attacked:
			rook.is_charging = false
			if rook.has_method("update_visuals"):
				rook.update_visuals()
			# Volley count changes; the normal recoil movement happens only once.
			_apply_rook_recoil(rook, recoil_dir)
		return
	var best_target = find_best_target(rook)
	if best_target:
		var next_step = get_next_step_towards(rook.grid_pos, best_target.grid_pos)
		if board.is_cell_vacant(next_step):
			board.move_piece(rook, next_step)


func _find_rook_target(rook):
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for i in range(1, rook.definition.attack_range + 1):
			var pos: Vector2i = rook.grid_pos + dir * i
			if not board.is_within_board(pos):
				break
			var target = board.get_piece_at(pos)
			if target != null:
				if _is_living_target(target) and target.team != rook.team:
					return target
				break
	return null

func execute_knight_logic(knight):
	if knight.attacks_used_this_turn >= knight.get_attack_limit():
		return
	if knight.is_grabbed:
		var grabber = knight.grabbed_by
		if is_instance_valid(grabber):
			while _is_living_target(grabber) and _begin_piece_attack(knight):
				deal_damage(grabber, knight.definition.counter_damage)
			if not _is_living_target(grabber):
				return

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

			var hit = apply_knockback(grabber, push_dir, knight.definition.push_distance, knight.definition.impact_damage)

			if hit:
				deal_damage(knight, knight.definition.self_impact_damage)
		return

	var target = find_best_target(knight)
	if target:
		var diff = target.grid_pos - knight.grid_pos
		if (abs(diff.x) == 2 and abs(diff.y) == 1) or (abs(diff.x) == 1 and abs(diff.y) == 2):
			var attacked: bool = false
			while _is_living_target(target) and _begin_piece_attack(knight):
				deal_damage(target, knight.definition.melee_damage)
				attacked = true
			if not attacked or board.game_finished:
				return

			var retreat_dir = (knight.grid_pos - target.grid_pos).sign()
			var safe_pos = knight.grid_pos + (retreat_dir * knight.definition.retreat_distance)

			if board.is_within_board(safe_pos) and board.is_cell_vacant(safe_pos):
				board.move_piece(knight, safe_pos)
			return

	var l_moves = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
		Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)
	]

	var best_pos = knight.grid_pos
	var min_dist = 9999

	for move in l_moves:
		var test_pos = knight.grid_pos + move

		if board.is_within_board(test_pos) and board.is_cell_vacant(test_pos):
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
		board.move_piece(knight, best_pos)


func find_safest_pos(piece):
	var best_pos = piece.grid_pos
	var max_score = -1.0

	var threat = find_best_target(piece)
	if not threat: return piece.grid_pos

	for x in range(-2, 3):
		for y in range(-2, 3):
			var test_pos = piece.grid_pos + Vector2i(x, y)

			if board.is_within_board(test_pos) and board.is_cell_vacant(test_pos):
				var score = test_pos.distance_to(threat.grid_pos)
				if score > max_score:
					max_score = score
					best_pos = test_pos

	return best_pos


func execute_bishop_logic(bishop, allow_movement: bool = true):
	if bishop.attacks_used_this_turn >= bishop.get_attack_limit():
		return
	if bishop.is_grabbed:
		var grabber = bishop.grabbed_by
		if is_instance_valid(grabber):
			while _is_living_target(grabber) and _begin_piece_attack(bishop):
				deal_damage(grabber, bishop.definition.counter_damage)
			if not _is_living_target(grabber):
				return

			var push_dir = (grabber.grid_pos - bishop.grid_pos).sign()

			bishop.is_grabbed = false
			grabber.is_grabbed = false
			bishop.grabbed_by = null
			grabber.grabbed_by = null

			apply_knockback(grabber, push_dir, bishop.definition.push_distance, bishop.definition.impact_damage)
		return

	var diag_dirs = [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	var attacked = false

	for dir in diag_dirs:
		for i in range(1, bishop.definition.attack_range + 1):
			var check_pos = bishop.grid_pos + (dir * i)

			if not board.is_within_board(check_pos):
				break

			var unit = board.get_piece_at(check_pos)
			if unit:
				if unit.team != bishop.team:
					while _is_living_target(unit) and _begin_piece_attack(bishop):
						projectile_requested.emit(bishop.global_position, unit.global_position)
						deal_damage(unit, bishop.definition.ranged_damage)
					attacked = true

					var csprite = bishop.get_node_or_null("Sprite2D")
					if csprite:
						if dir.x > 0: csprite.frame = 1
						elif dir.x < 0: csprite.frame = 2
						elif dir.y > 0: csprite.frame = 0
						elif dir.y < 0: csprite.frame = 3
				break

		if attacked: return

	if not allow_movement:
		return
	var target = find_best_target(bishop)
	if not target: return

	var possible_moves = []
	for step in diag_dirs:
		var test_pos = bishop.grid_pos + step
		if board.is_within_board(test_pos) and board.is_cell_vacant(test_pos):
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
		board.move_piece(bishop, best_move)

func execute_boss_turn():
	match board.current_attack_index:
		0: scream_pushback()
		1: fire_breath_single()
		2: claw_swipe()
		3: triple_fireball()

	board.current_attack_index = (board.current_attack_index + 1) % 4


func scream_pushback():
	for p in board.all_pieces:
		if is_instance_valid(p) and p.team == 1:
			p.grid_pos.y += 2
			p.grid_pos.y = clamp(p.grid_pos.y, 0, 7)
			p.position = board.grid_to_pixel(p.grid_pos)


func fire_breath_single():
	var players = board.get_all_team_units(1)
	if players.size() > 0:
		var target = players.pick_random()
		deal_damage(target, 20)
		target.set("burn_ticks", 2)


func claw_swipe():
	for x in range(3, 3 + 3):
		var target_pos = Vector2i(x, 0 + 3)
		var unit = board.find_unit_at(target_pos)
		if unit: deal_damage(unit, 25)

func triple_fireball():
	for i in range(3):
		var center = Vector2i(randi()%8, randi()%8)
		for x in range(-1, 2):
			for y in range(-1, 2):
				var unit = board.find_unit_at(center + Vector2i(x, y))
				if unit: deal_damage(unit, 15)

func check_and_execute_grab(pawn):
	if pawn.is_queued_for_deletion() or ("stun_turns" in pawn and pawn.stun_turns > 0) or board.is_tile_foggy(pawn.grid_pos): return
	if UnitDefinition.is_kind(pawn, UnitDefinition.Kind.KING) or UnitDefinition.is_kind(pawn, UnitDefinition.Kind.EARTH_WALL): return
	if pawn.is_grabbed: return

	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var possible_targets = []

	for dir in directions:
		var target_pos = pawn.grid_pos + dir
		var target_unit = board.get_piece_at(target_pos)

		if target_unit and target_unit.team != pawn.team:
			possible_targets.append(target_unit)

	if possible_targets.size() == 0: return

	var soldier_targets = []
	for t in possible_targets:
		if not UnitDefinition.is_kind(t, UnitDefinition.Kind.KING):
			soldier_targets.append(t)

	var chosen_target = null
	if soldier_targets.size() > 0:
		chosen_target = soldier_targets.pick_random()
	else:
		chosen_target = possible_targets.pick_random()

	if UnitDefinition.is_kind(pawn, UnitDefinition.Kind.EARTH_WALL) or UnitDefinition.is_kind(chosen_target, UnitDefinition.Kind.EARTH_WALL):
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
	board.selected_piece = null
	for p in board.all_pieces:
		if is_instance_valid(p):
			p.set("is_grabbed", false)
			p.set("grabbed_by", null)
			if "grid_pos" in p and board.has_method("grid_to_pixel"):
				p.position = board.grid_to_pixel(p.grid_pos)
			if p.has_method("update_visuals"):
				p.update_visuals()

func kill_piece(piece) -> void:
	if not is_instance_valid(piece) or piece.is_queued_for_deletion():
		return
	if UnitDefinition.is_kind(piece, UnitDefinition.Kind.KING):
		board.show_lose_screen()
		return
	for p in board.all_pieces:
		if is_instance_valid(p) and p.get("grabbed_by") == piece:
			p.set("is_grabbed", false)
			p.set("grabbed_by", null)
			if p.has_method("update_visuals"):
				p.update_visuals()
	board.all_pieces.erase(piece)
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

		if not board.is_within_board(next_grid):
			print("2. Chạm biên bàn cờ tại: ", next_grid)
			hit_obstacle = true
			break

		if not board.is_cell_vacant(next_grid):
			print("2. Bị chặn bởi vật cản tại: ", next_grid)
			hit_obstacle = true
			var obstacle = board.get_piece_at(next_grid)
			if is_instance_valid(obstacle) and impact_damage > 0:
				deal_damage(obstacle, impact_damage)
			break

		current_grid = next_grid
		print("2. Ô ", next_grid, " an toàn.")

	if current_grid != start_grid:
		print("3. Cập nhật lính tới đích: ", current_grid)

		board.move_piece(unit, current_grid)
		var tween = board.create_tween()
		tween.tween_property(unit, "global_position", board.grid_to_pixel(current_grid), 0.2).set_trans(Tween.TRANS_SINE)

	else:
		print("3. Lính không nhúc nhích được bước nào!")

	if hit_obstacle and impact_damage > 0:
		deal_damage(unit, impact_damage)

	return hit_obstacle

func process_ammo_reloads():
	for p in board.all_pieces:
		if is_instance_valid(p) and UnitDefinition.is_kind(p, UnitDefinition.Kind.QUEEN):
			if p.is_reloading:
				p.reload_turns_left -= 1

				if p.reload_turns_left <= 0:
					p.is_reloading = false
					p.current_ammo = p.max_ammo

					if p.has_node("AmmoBar"):
						p.get_node("AmmoBar").value = p.current_ammo
