class_name TileEffectSystem
extends RefCounted
## Owns terrain lifetime, propagation and occupancy effects independently of UI.

var board: Node
var catalog: SpellCatalog
var active_effects: Dictionary = {}
const TILE_SPELLS = {"fire_tile": "fire_fire", "water_tile": "water_water", "lava_tile": "fire_earth", "swamp_tile": "water_earth", "rain_tile": "water_wind", "firestorm_tile": "fire_wind", "fog_tile": "fire_water"}

func _init(context: Node, definitions: SpellCatalog) -> void:
	board = context
	catalog = definitions

func _rule(type: String, key: StringName, fallback = 0):
	var definition: SpellDefinition = catalog.get_by_id(TILE_SPELLS.get(type, "fire_fire"))
	return definition.param(key, fallback)

func add_tile_effect(grid_pos: Vector2i, effect_type: String, duration: int, spread_dirs: Array = [], is_center: bool = true, is_first_spawn: bool = true):
	if duration <= 0 or not board.is_within_board(grid_pos):
		return
	var piece = board.get_piece_at(grid_pos)
	if is_instance_valid(piece):
		if UnitDefinition.is_kind(piece, UnitDefinition.Kind.EARTH_WALL):
			print("Vướng cục đá/tường đất tại ", grid_pos, " -> Hủy phép!")
			return
	if active_effects.has(grid_pos):
		return
	var spawned_visual = board.presentation.create_tile_visual(grid_pos, effect_type, is_first_spawn)
	active_effects[grid_pos] = {
		"type": effect_type,
		"turns": duration,
		"visual_node": spawned_visual,
		"is_new": true,
		"spread_dirs": spread_dirs,
		"is_center": is_center,
		"age": 0
	}
	if is_first_spawn and is_instance_valid(piece):
		match effect_type:
			"swamp_tile":
				if piece.has_method("add_buff"): piece.add_buff("root", 0, _rule(effect_type, "placement_root", 3))
				print("-> Đầm lầy vừa trúng đích, trói chân ngay lập tức: ", piece.name)
			"fire_tile", "lava_tile", "firestorm_tile":
				if piece.has_method("take_damage"): piece.take_damage(_rule(effect_type, "placement_damage", 10.0))
				print("-> Lửa vừa rơi trúng đầu, đốt ngay lập tức: ", piece.name)
			"water_tile", "rain_tile":
				if piece.has_method("heal"): piece.heal(_rule(effect_type, "placement_heal", 20.0))

func process_all_tile_effects():
	var grids_to_remove = []
	var new_puddle_tiles = []
	var new_rain_tiles = []
	var new_firestorm_tiles = []
	var new_fog_tiles = []
	for grid_pos in active_effects.keys():
		var effect = active_effects[grid_pos]
		effect["turns"] -= 1
		effect["is_new"] = false
		effect["age"] = effect.get("age", 0) + 1
		var current_age = effect["age"]
		match effect["type"]:
			"water_tile":
				var unit = board.get_unit_at(grid_pos)
				if unit:
					if unit.has_method("heal"): unit.heal(_rule(effect["type"], "tick_heal", 20.0))
					if unit.get("team") == 1: Global.add_ink(_rule(effect["type"], "tick_ink", 50.0))
			"fire_tile", "lava_tile":
				var unit = board.get_unit_at(grid_pos)
				if unit:
					board.deal_damage(unit, _rule(effect["type"], "tick_damage", 10.0))
					if effect["type"] == "lava_tile" and unit.get("team") == 1:
						Global.add_paper(-int(_rule(effect["type"], "paper_penalty", 1)))
			"swamp_tile":
				var unit = board.get_unit_at(grid_pos)
				if is_instance_valid(unit):
					if unit.has_method("heal"):
						unit.heal(_rule(effect["type"], "tick_heal", 20.0))
					if unit.has_method("add_buff"):
						unit.add_buff("root", 0, _rule(effect["type"], "tick_root", 2))
					if unit.get("team") == 1:
						Global.add_ink(_rule(effect["type"], "tick_ink", 50.0))
			"rain_tile":
				var unit = board.get_unit_at(grid_pos)
				if is_instance_valid(unit):
					if unit.has_method("heal"): unit.heal(_rule(effect["type"], "tick_heal", 50.0))
					if unit.get("team") == 1:
						Global.add_ink(_rule(effect["type"], "tick_ink", 50.0))
						if UnitDefinition.is_kind(unit, UnitDefinition.Kind.KING) or UnitDefinition.is_kind(unit, UnitDefinition.Kind.KING):
							Global.add_paper(-int(_rule(effect["type"], "king_paper_penalty", 1)))
				if effect.get("is_center", false):
					for dir in effect.get("spread_dirs", []):
						var next_pos = grid_pos + dir
						if board.is_within_board(next_pos) and not active_effects.has(next_pos):
							new_rain_tiles.append({
								"pos": next_pos,
								"turns": effect["turns"],
								"dirs": [dir],
								"is_center": true,
								"is_first_spawn": false
							})
							effect["is_center"] = false
							effect["tail_life"] = 1
				else:
					if effect.has("tail_life"):
						effect["tail_life"] -= 1
						if effect["tail_life"] <= 0:
							if not grids_to_remove.has(grid_pos):
								grids_to_remove.append(grid_pos)
			"fog_tile":
				if effect.get("is_center", false):
					for dir in effect.get("spread_dirs", []):
						var next_pos = grid_pos + dir
						if board.is_within_board(next_pos) and not active_effects.has(next_pos):
							new_fog_tiles.append({
								"pos": next_pos,
								"turns": effect["turns"],
								"dirs": [dir],
								"is_center": true,
								"is_first_spawn": false
							})
							effect["is_center"] = false
							effect["tail_life"] = 1
				else:
					if effect.has("tail_life"):
						effect["tail_life"] -= 1
						if effect["tail_life"] <= 0:
							if not grids_to_remove.has(grid_pos):
								grids_to_remove.append(grid_pos)
			"firestorm_tile":
				var base_dmg = _rule(effect["type"], "tick_damage", 15.0)
				var center_pos_i = Vector2i(grid_pos)
				apply_firestorm_impact(center_pos_i, base_dmg)
				if effect.get("is_center", false):
					for dir in effect.get("spread_dirs", []):
						var next_pos = center_pos_i + dir
						if board.is_within_board(next_pos) and not active_effects.has(next_pos):
							new_firestorm_tiles.append({
								"pos": next_pos,
								"turns": effect["turns"],
								"dirs": [dir]
							})
							if not grids_to_remove.has(center_pos_i):
								grids_to_remove.append(center_pos_i)

		if effect["type"] in ["lava_tile", "swamp_tile"] and effect.get("is_center", false):
			for dir in effect.get("spread_dirs", []):
				var is_orthogonal = (abs(dir.x) + abs(dir.y) == 1)
				var is_diagonal = (abs(dir.x) + abs(dir.y) == 2)
				var should_spread = false
				if current_age == 1 and is_orthogonal: should_spread = true
				elif current_age == 2 and is_diagonal: should_spread = true
				if should_spread:
					var next_pos = grid_pos + dir
					if board.is_within_board(next_pos) and not active_effects.has(next_pos):
						new_puddle_tiles.append({
							"pos": next_pos,
							"type": effect["type"],
							"turns": effect["turns"],
							"dirs": []
						})
		if effect["turns"] <= 0 and not grids_to_remove.has(grid_pos):
			grids_to_remove.append(grid_pos)
	for pos in grids_to_remove:
		_remove_tile_effect(pos)

	for puddle in new_puddle_tiles:
		add_tile_effect(puddle["pos"], puddle["type"], puddle["turns"], puddle["dirs"], false, false)

	for rain in new_rain_tiles:
		add_tile_effect(rain["pos"], "rain_tile", rain["turns"], rain["dirs"], true, false)
	for storm in new_firestorm_tiles:
		add_tile_effect(storm["pos"], "firestorm_tile", storm["turns"], storm["dirs"], true, false)
	for fog in new_fog_tiles:
		add_tile_effect(fog["pos"], "fog_tile", fog["turns"], fog["dirs"], true, fog.get("is_first_spawn", true))


func _remove_tile_effect(grid_pos: Vector2i):
	if active_effects.has(grid_pos):
		var effect_data = active_effects[grid_pos]
		if is_instance_valid(effect_data.get("visual_node")):
			effect_data["visual_node"].queue_free()
		active_effects.erase(grid_pos)

func spawn_earth_block(grid_pos: Vector2i, hp: int, turns: int):
	var block_scene = preload("res://earth_wall.tscn")
	var block = block_scene.instantiate()

	block.name = "EarthBlock_" + str(randi() % 1000)
	block.set("hp", hp)
	block.set("max_hp", hp)
	block.set("duration", turns)
	block.set("team", 1)

	var visual = block.get_node_or_null("giodat")
	if is_instance_valid(visual):
		visual.play("giodat")

	board.add_child(block)
	block.global_position = board.grid_to_pixel(grid_pos)

	if block.has_method("set_grid_position"):
		block.set_grid_position(grid_pos)
	else:
		block.set("grid_pos", grid_pos)

	board.all_pieces.append(block)

func is_tile_foggy(grid_pos: Vector2i) -> bool:
	if active_effects.has(grid_pos):
		return active_effects[grid_pos]["type"] == "fog_tile"
	return false

func _trigger_immediate_tile_effect(grid_pos: Vector2i, type: String, unit):
	print("-> [Phép Gió] Vừa quạt trúng ô hiệu ứng: ", type)

	if active_effects.has(grid_pos):
		var visual = active_effects[grid_pos].get("visual_node")
		if is_instance_valid(visual):
			visual.modulate = Color(2.0, 2.0, 2.0, 1)
			var tw = board.get_tree().create_tween()
			tw.tween_property(visual, "scale", Vector2(1.4, 1.4), 0.1)
			tw.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.2)
			tw.tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.2)
	if not is_instance_valid(unit): return
	match type:
		"water_tile", "swamp_tile":
			if unit.has_method("heal"): unit.heal(_rule(type, "wind_heal", 20.0))
			if type == "water_tile" and unit.get("team") == 1: Global.add_ink(_rule(type, "tick_ink", 50.0))
			if type == "swamp_tile" and unit.has_method("add_buff"): unit.add_buff("root", 0, _rule(type, "tick_root", 2))
		"fire_tile", "lava_tile", "firestorm_tile":
			if unit.has_method("take_damage"):
				unit.take_damage(_rule(type, "wind_damage", 15.0))
			elif board.has_method("deal_damage"):
				board.deal_damage(unit, _rule(type, "wind_damage", 15.0))
		"rain_tile":
			if unit.has_method("heal"): unit.heal(_rule(type, "wind_heal", 30.0))
			if unit.get("team") == 1: Global.add_ink(_rule(type, "tick_ink", 50.0))

func apply_firestorm_impact(center_pos_i: Vector2i, base_dmg: float):
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_pos = center_pos_i + Vector2i(dx, dy)
			var unit = board.get_unit_at(check_pos)
			if is_instance_valid(unit):
				if dx == 0 and dy == 0:
					board.deal_damage(unit, base_dmg)
				else:
					var push_dir = Vector2i(dx, dy)
					var target_push_pos = check_pos + push_dir

					var is_blocked = not board.is_within_board(target_push_pos) or is_instance_valid(board.get_unit_at(target_push_pos))

					if is_blocked:
						board.deal_damage(unit, base_dmg * 2.0)
					else:
						if unit.has_method("move_to_grid"):
							var target_pixel_pos = board.grid_to_pixel(target_push_pos)
							unit.move_to_grid(target_push_pos, target_pixel_pos)
						board.deal_damage(unit, base_dmg)
