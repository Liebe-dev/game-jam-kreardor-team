class_name SpellResolver
extends RefCounted
## The authoritative command interface: validate, pay, resolve, return a result.

var board: Node
var catalog: SpellCatalog = preload("res://data/spells/catalog.tres")

func _init(context: Node) -> void:
	board = context

func _definition(id: StringName) -> SpellDefinition:
	return catalog.get_by_id(id)

func can_prepare() -> bool:
	return not Global.has_casted_spell and not board.is_resolving_turn and not board.game_finished

func pay_for_edit(_previous: String, _proposed: String) -> bool:
	return can_prepare()

func quote_cost(definition: SpellDefinition, coordinates: Array, directions: Array) -> int:
	return definition.ink_cost + (20 if coordinates.size() == 4 else 0) + 20 * directions.size()

func request_cast(elements: Array, coordinates: Array, directions: Array) -> Dictionary:
	if not can_prepare():
		return {"ok": false, "reason": "busy_or_used"}
	if elements.is_empty() or elements.size() > 2:
		return {"ok": false, "reason": "elements"}
	for element in elements:
		if not element is int or element < 0 or element > 3:
			return {"ok": false, "reason": "elements"}
	var definition: SpellDefinition = catalog.get_by_elements(elements)
	if definition == null:
		return {"ok": false, "reason": "elements"}
	if coordinates.size() not in [2, 4] or directions.size() > 8:
		return {"ok": false, "reason": "coordinates"}
	for i in range(0, coordinates.size(), 2):
		if not coordinates[i] is String or not coordinates[i + 1] is String:
			return {"ok": false, "reason": "coordinates"}
		if not board.is_within_board(Global.convert_to_grid([coordinates[i], coordinates[i + 1]])):
			return {"ok": false, "reason": "coordinates"}
	for direction in directions:
		if not (direction is Vector2 or direction is Vector2i):
			return {"ok": false, "reason": "direction"}
		var vector := Vector2(direction)
		if vector == Vector2.ZERO or absf(vector.x) > 1.0 or absf(vector.y) > 1.0 or vector != vector.round():
			return {"ok": false, "reason": "direction"}
	if coordinates.size() == 4 and Global.convert_to_grid(coordinates.slice(0, 2)) == Global.convert_to_grid(coordinates.slice(2, 4)):
		return {"ok": false, "reason": "duplicate_target"}
	if coordinates.size() == 4 and definition.id in [&"fire_water", &"wind_earth"]:
		return {"ok": false, "reason": "unsupported_target"}
	var seen_directions: Array[Vector2i] = []
	for direction in directions:
		var vector := Vector2i(direction)
		if vector in seen_directions:
			return {"ok": false, "reason": "duplicate_direction"}
		seen_directions.append(vector)
	if definition.id == &"wind_earth" and not board.is_cell_vacant(Global.convert_to_grid(coordinates.slice(0, 2))):
		return {"ok": false, "reason": "occupied"}
	var ink_cost := quote_cost(definition, coordinates, directions)
	if Global.current_ink < ink_cost:
		return {"ok": false, "reason": "ink"}
	if definition.paper_cost < 0 or Global.paper_count < definition.paper_cost:
		return {"ok": false, "reason": "paper"}
	Global.add_ink(-ink_cost)
	Global.add_paper(-definition.paper_cost)
	Global.has_casted_spell = true
	cast_complex_spell(elements, coordinates, directions)
	return {"ok": true, "spell_id": definition.id, "paper_cost": definition.paper_cost, "ink_cost": ink_cost, "elements": elements.duplicate(), "coordinates": coordinates.duplicate(), "directions": directions.duplicate()}

func _add_to_impact_map(map: Dictionary, pos: Vector2i):
	if map.has(pos):
		map[pos] += 1
	else:
		map[pos] = 1

func cast_complex_spell(elements, coordinates, directions):
	if elements.is_empty() or coordinates.size() < 2:
		print("[LogicGame] Bỏ qua vì thiếu nguyên tố hoặc tọa độ!")
		return

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
	if elements.size() == 1:
		match elements[0]:
			SpellDictionary.Element.FIRE:
				execute_new_fire_spell(target_grids, directions)
			SpellDictionary.Element.WATER:
				execute_new_water_spell(target_grids, directions)
			SpellDictionary.Element.EARTH:
				execute_new_earth_spell(target_grids, directions)
			SpellDictionary.Element.WIND:
				execute_new_wind_spell(target_grids, directions)
	elif elements.size() == 2:

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

		else:
			var has_fire = SpellDictionary.Element.FIRE in elements
			var has_water = SpellDictionary.Element.WATER in elements
			var has_earth = SpellDictionary.Element.EARTH in elements
			var has_wind = SpellDictionary.Element.WIND in elements

			if has_fire and has_water:
				execute_new_fire_water_spell(target_grids, directions)
			elif has_fire and has_earth:
				execute_new_fire_earth_spell(target_grids, directions)
			elif has_fire and has_wind:
				execute_new_fire_wind_spell(target_grids, directions)
			elif has_water and has_earth:
				execute_new_water_earth_spell(target_grids, directions)
			elif has_water and has_wind:
				execute_new_water_wind_spell(target_grids, directions)
			elif has_earth and has_wind:
				execute_new_wind_earth_spell(target_grids, directions)

func execute_new_fire_spell(target_grids: Array, directions: Array):
	print("[Phép Lửa] Bắt đầu gọi thiên thạch...")
	execute_aoe_effect(target_grids, directions, _definition("fire").power, "damage", "lua")

func execute_new_fire_fire_spell(target_grids: Array, directions: Array):
	var base_damage = _definition("fire_fire").power
	var impact_map = execute_aoe_effect(target_grids, directions, base_damage, "damage", "lua")
	for grid_pos in impact_map.keys():
		board.add_tile_effect(grid_pos, "fire_tile", _definition("fire_fire").duration)

func execute_new_water_spell(target_grids: Array, directions: Array):
	print("[Phép Nước] Bắt đầu dội mưa...")
	execute_aoe_effect(target_grids, directions, _definition("water").power, "heal", "nuoc")
	Global.add_ink(_definition("water").ink_reward)

func execute_new_water_water_spell(target_grids: Array, directions: Array):
	var impact_map = execute_aoe_effect(target_grids, directions, 0, "heal", "nuoc")
	for grid_pos in impact_map.keys():
		board.add_tile_effect(grid_pos, "water_tile", _definition("water_water").duration)

func execute_new_wind_spell(target_grids: Array, directions: Array):
	print("[Phép Gió] Kích hoạt!")
	if target_grids.is_empty(): return
	var has_direction = not directions.is_empty()
	for i in range(target_grids.size()):
		var grid_pos = target_grids[i]
		var dir = Vector2i.ZERO
		if has_direction:
			dir = directions[i] if i < directions.size() else directions[0]
		var unit = board.get_piece_at(grid_pos)
		if board.active_tile_effects.has(grid_pos):
			var old_effect = board.active_tile_effects[grid_pos]["type"]
			board._trigger_immediate_tile_effect(grid_pos, old_effect, unit)
		if not has_direction:
			board.play_wind_visual(grid_pos, "gio")
			if is_instance_valid(unit) and unit.has_method("add_buff"):
				unit.add_buff("double_attack", 0, _definition("wind").duration)
		else:
			board.play_wind_visual(grid_pos, "giogio")
			if is_instance_valid(unit):
				var target_push_pos = grid_pos + dir
				var is_blocked = not board.is_within_board(target_push_pos) or is_instance_valid(board.get_piece_at(target_push_pos))

				if not is_blocked:
					board.apply_knockback(unit, dir, _definition("wind").param("push_distance", 1), 0)
					if unit.has_method("add_buff"):
						unit.add_buff("stun", 0, _definition("wind").param("direction_stun", 1))
				else:
					if unit.has_method("add_buff"):
						unit.add_buff("stun", 0, _definition("wind").param("direction_stun", 1))

func execute_new_wind_wind_spell(target_grids: Array, directions: Array):
	SoundManager.play_sound(SoundManager.sfx_wind)
	var dir_count = directions.size()
	if dir_count == 0:
		for grid_pos in target_grids:
			var target_unit = board.get_piece_at(grid_pos)
			if is_instance_valid(target_unit) and target_unit.has_method("add_buff"):
				target_unit.add_buff("stun", 0, _definition("wind_wind").duration)
	elif dir_count == 1:
		var push_dir = directions[0]

		execute_aoe_effect(target_grids, directions, 0, "none", "giogio")

		for grid_pos in target_grids:
			var target_unit = board.get_piece_at(grid_pos)
			if is_instance_valid(target_unit):
				board.apply_knockback(target_unit, push_dir, _definition("wind_wind").param("push_distance", 2), _definition("wind_wind").param("impact_damage", 15))
				if target_unit.has_method("add_buff"):
					target_unit.add_buff("stun", 0, _definition("wind_wind").param("directed_stun", 2))

	else:
		var aoe_grids = target_grids.duplicate()
		for origin in target_grids:
			for dir in directions:
				var affected_grid = origin + dir
				if not aoe_grids.has(affected_grid):
					aoe_grids.append(affected_grid)
		for grid_pos in aoe_grids:
			var target_unit = board.get_piece_at(grid_pos)
			if is_instance_valid(target_unit) and target_unit.has_method("add_buff"):
				target_unit.add_buff("stun", 0, _definition("wind_wind").param("directed_stun", 2))

func execute_new_earth_spell(target_grids: Array, directions: Array):
	execute_aoe_effect(target_grids, directions, _definition("earth").power, "earth_buff", "")
	Global.add_paper(_definition("earth").paper_reward)

func execute_new_earth_earth_spell(target_grids: Array, directions: Array):
	Global.add_paper(_definition("earth_earth").paper_reward)
	execute_aoe_effect(target_grids, directions, _definition("earth_earth").power, "earth_earth_buff", "")

func execute_new_fire_water_spell(target_grids: Array, directions: Array):
	print("[Sương Mù] Kích hoạt sương mù bảo vệ!")
	if target_grids.is_empty(): return
	Global.add_ink(_definition("fire_water").ink_reward)
	var duration = _definition("fire_water").duration
	if target_grids.size() >= 2:
		duration -= _definition("fire_water").param("multi_target_reduction", 2)
	duration = max(1, duration)
	var spread_dirs = []
	if directions.size() == 1:
		spread_dirs = directions
	else:
		spread_dirs = []
	var center_pos = target_grids[0]
	board.add_tile_effect(center_pos, "fog_tile", duration, spread_dirs, true)

func execute_new_fire_wind_spell(target_grids: Array, directions: Array):
	SoundManager.play_sound(SoundManager.sfx_fire)
	print("[Bão Lửa] Kích hoạt bão lửa 3x3!")
	if target_grids.is_empty(): return
	var duration = _definition("fire_wind").duration
	if target_grids.size() >= 2:
		duration -= _definition("fire_wind").param("multi_target_reduction", 2)
	duration = max(1, duration)
	var spread_dirs = []
	if directions.size() == 1:
		spread_dirs = directions
	else:
		print("[Bão Lửa] Hướng gió hỗn loạn, bão sẽ đứng im!")
		spread_dirs = []
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	for grid_pos in target_grids:
		board.add_tile_effect(grid_pos, "firestorm_tile", duration, spread_dirs, true)

func execute_new_water_earth_spell(target_grids: Array, directions: Array):
	print("[Đầm Lầy] Kích hoạt vũng lầy!")
	Global.add_paper(_definition("water_earth").paper_reward)
	var duration = _definition("water_earth").duration
	var dir_count = directions.size()
	if dir_count > 1: duration -= (dir_count - 1) * _definition("water_earth").param("extra_direction_reduction", 1)
	if target_grids.size() >= 2: duration -= _definition("water_earth").param("multi_target_reduction", 4)
	duration = max(1, duration)
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	for grid_pos in target_grids:
		board.add_tile_effect(grid_pos, "swamp_tile", duration, directions, true)

func execute_new_fire_earth_spell(target_grids: Array, directions: Array):
	print("[Dung Nham] Kích hoạt dòng chảy!")
	Global.add_paper(_definition("fire_earth").paper_reward)
	var duration = _definition("fire_earth").duration
	var dir_count = directions.size()
	if dir_count > 1: duration -= (dir_count - 1) * _definition("fire_earth").param("extra_direction_reduction", 1)
	if target_grids.size() >= 2: duration -= _definition("fire_earth").param("multi_target_reduction", 4)
	duration = max(1, duration)
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	for grid_pos in target_grids:
		board.add_tile_effect(grid_pos, "lava_tile", duration, directions)

func execute_new_water_wind_spell(target_grids: Array, directions: Array):
	SoundManager.play_sound(SoundManager.sfx_water)
	print("[Cơn Mưa] Kích hoạt đám mây di chuyển!")
	if target_grids.is_empty(): return
	var duration = _definition("water_wind").duration
	if target_grids.size() >= 2:
		duration -= _definition("water_wind").param("multi_target_reduction", 2)
	duration = max(1, duration)
	var spread_dirs = []
	if directions.size() == 1:
		spread_dirs = directions
	else:
		print("[Cơn Mưa] Gió nhiễu loạn! Đám mây sẽ đứng im.")
		spread_dirs = []
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	for grid_pos in target_grids:
		board.add_tile_effect(grid_pos, "rain_tile", duration, spread_dirs)

func execute_new_wind_earth_spell(target_grids: Array, directions: Array, aoe_value_modifier: float = 1.0):
	SoundManager.play_sound(SoundManager.sfx_earthwind)
	if target_grids.is_empty(): return
	var origin = target_grids[0]
	var dir_count = directions.size()
	var duration = max(1, _definition("wind_earth").duration - dir_count * _definition("wind_earth").param("direction_reduction", 1))
	var base_hp = _definition("wind_earth").power
	var final_hp = int(base_hp * aoe_value_modifier)
	var block_grids = [origin]
	for dir in directions:
		var next_grid = origin + dir
		if not block_grids.has(next_grid):
			block_grids.append(next_grid)
	execute_aoe_effect(block_grids, directions, 0, "none", "")
	var adj_dirs = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	for grid in block_grids:
		if not board.is_within_board(grid): continue
		if not board.is_cell_vacant(grid):
			print("Ô có người! Không tạo tường.")
			continue
		board.spawn_earth_block(grid, final_hp, duration)
		for adj in adj_dirs:
			var adj_grid = grid + adj
			var unit = board.get_piece_at(adj_grid)
			if is_instance_valid(unit) and unit.get("team") == 1:
				print("Buff đồng minh tại ", adj_grid)
				if unit.has_method("add_buff"):
					unit.add_buff("damage_reduction", _definition("wind_earth").param("shield_rate", 0.5), duration)

func execute_aoe_effect(target_grids: Array, directions: Array, base_value: float, effect_type: String, ground_anim: String) -> Dictionary:
	var is_multi_target = target_grids.size() > 1
	var multi_factor = catalog.multi_target_factor if is_multi_target else 1.0
	var direction_factor = 1.0 / (directions.size() + 1)
	var value_per_hit = base_value * multi_factor * direction_factor
	var impact_map = {}
	for center_pos in target_grids:
		_add_to_impact_map(impact_map, center_pos)
		for dir in directions:
			var offset_pos = center_pos + Vector2i(dir.x, dir.y)
			if board.is_within_board(offset_pos):
				_add_to_impact_map(impact_map, offset_pos)
	for grid_pos in impact_map.keys():
		var hit_count = impact_map[grid_pos]
		var total_value = value_per_hit * hit_count
		var target_unit = board.get_unit_at(grid_pos)
		if ground_anim != "":
			board.play_spell_animation(grid_pos, ground_anim, target_unit)
		if target_unit != null:
			var push_dir = directions[0] if directions.size() > 0 else Vector2i.ZERO
			apply_unit_effect(target_unit, effect_type, total_value, grid_pos, push_dir)
		else:
			if ground_anim == "":
				print(" -> Ô ", grid_pos, " trống. Phép bay xuyên qua, không có tác dụng.")
	return impact_map

func apply_unit_effect(unit, effect_type: String, value: float, grid_pos: Vector2i, dir: Vector2i = Vector2i.ZERO):
	var unit_name = unit.name
	match effect_type:
		"heal":
			if unit.has_method("heal"):
				unit.heal(value)
				print(" -> Ô ", grid_pos, " Hồi ", value, " máu cho [", unit_name, "]")

		"damage":
			board.deal_damage(unit, value)
			print(" -> Ô ", grid_pos, " Nổ ", value, " sát thương lên [", unit_name, "]")

		"earth_buff":
			if unit.has_method("add_buff"):
				unit.add_buff("damage_reduction", value, _definition("earth").duration)

		"earth_earth_buff":
			if unit.has_method("add_buff"):
				unit.add_buff("damage_reduction", value, _definition("earth_earth").duration)

		"stun_1":
			if unit.has_method("add_buff"):
				unit.add_buff("stun", 1.0, 1)
		"stun_2":
			if unit.has_method("add_buff"):
				unit.add_buff("stun", 1.0, 2)
		"knockback_2":
			if is_instance_valid(unit):
				board.apply_knockback(unit, dir, 2, 5)
		_:
			print(" -> Ô ", grid_pos, " có hiệu ứng không xác định!")
