extends Node2D

signal turn_resolved(result: Dictionary)
signal combat_event(result: Dictionary)
var combat_resolver: CombatResolver
var turn_resolver: TurnResolver
var presentation: BattlePresentation

@onready var win_screen = get_node("/root/board/WinPanel")
@onready var lose_screen = get_node("/root/board/LosePanel")
@export var move_indicator_scene: PackedScene
@export var endgame_menu: Control
@export var endgame_title: Label
const SPELL_EFFECT_SCENE = preload("res://spell_effect.tscn")
var active_indicators = []
var player_pawn_scene = preload("res://Pawn.tscn")
var player_king_scene = preload("res://PlayerKing.tscn")
var enemy_pawn_scene = preload("res://enemy_pawn.tscn")
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
var boss: Node2D
var current_turn = 1
enum Command { ATTACK, DEFEND, IDLE }
var current_command = Command.IDLE
var current_attack_index = 0
var has_moved_main_piece = false
var piece_layer: Node2D
var all_pieces = []
var selected_piece = null
var is_player_turn = true
var is_resolving_turn: bool = false
var game_finished: bool = false
var wave_resources_backup: Dictionary = {}
var board_origin = Vector2(450, 250)
var cell_size = 80
var player_unit
var player_pieces_backup = []
const FIRE_TILE_SCENE = preload("res://fire_tile.tscn")
@export var wave_definitions: Array[WaveDefinition] = [
	preload("res://data/waves/wave_1.tres"),
	preload("res://data/waves/wave_2.tres"),
	preload("res://data/waves/wave_3.tres"),
	preload("res://data/waves/wave_4.tres"),
	preload("res://data/waves/wave_5.tres")
]
var max_waves: int:
	get: return wave_definitions.size()

func _ready():
	combat_resolver = CombatResolver.new(self)
	presentation = BattlePresentation.new(self)
	combat_resolver.attack_animation_requested.connect(presentation.attack)
	combat_resolver.projectile_requested.connect(presentation.projectile)
	combat_resolver.damage_resolved.connect(combat_event.emit)
	turn_resolver = TurnResolver.new()
	turn_resolver.board = self
	add_child(turn_resolver)
	turn_resolver.turn_resolved.connect(turn_resolved.emit)
	win_screen.hide()
	lose_screen.hide()
	add_to_group("logic_board")
	player_unit = get_tree().get_first_node_in_group("player")
	if wave_label:
		wave_label.text = "Wave: " + str(Global.current_wave)
	piece_layer = Node2D.new()
	piece_layer.name = "PieceLayer"
	add_child(piece_layer)
	if Global.current_wave == 1:
		SoundManager.play_bgm(SoundManager.bgm_wave1)
	if Global.is_continuing == true:
		Global.is_continuing = false 
		restore_from_save() 
	else:
		spawn_initial_army()
		backup_player_pieces()
func _add_to_impact_map(map: Dictionary, pos: Vector2i):
	if map.has(pos):
		map[pos] += 1
	else:
		map[pos] = 1
func is_within_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8
func count_enemies_alive() -> int:
	var enemy_count = 0
	for p in all_pieces:
		if is_instance_valid(p) and p.team == 2:
			enemy_count += 1
	return enemy_count
func transition_to_next_wave():
	_clear_wave_effects()
	force_release_all_grabs()
	Global.has_casted_spell = false
	has_moved_main_piece = false
	selected_piece = null
	clear_highlights()
	%ClosedScrollButton.show()
	Global.current_wave += 1
	current_turn = 1
	if wave_label: wave_label.text = "Wave: " + str(Global.current_wave)
	if turn_label: turn_label.text = "Turn: 1"
	if Global.current_wave == 2:
		SoundManager.play_bgm(SoundManager.bgm_wave2)
	elif Global.current_wave == 3:
		SoundManager.play_bgm(SoundManager.bgm_wave3)
	elif Global.current_wave == 4:
		SoundManager.play_bgm(SoundManager.bgm_wave4)
	elif Global.current_wave == 5:
		SoundManager.play_bgm(SoundManager.bgm_wave5)
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
		if is_instance_valid(p) and p.team == 1 and p is Piece:
			p.active_buffs.clear()
			p.stun_turns = 0
			p.root_turns = 0
			p.damage_reduction_rate = 0.0
			if is_instance_valid(p.current_wind_visual):
				p.current_wind_visual.queue_free()
				p.current_wind_visual = null
			p.is_charging = false
			p.has_moved = false
			p.attacks_used_this_turn = 0
			if p.has_node("ShieldAnim"):
				p.get_node("ShieldAnim").hide()
			if UnitDefinition.is_kind(p, UnitDefinition.Kind.KING):
				king_piece = p
			else:
				current_pawns.append(p)
	for i in range(8):
		if i < current_pawns.size():
			var p = current_pawns[i]
			p.grid_pos = Vector2i(i, 6)
			p.position = grid_to_pixel(p.grid_pos)
			p.heal(wave_definitions[Global.current_wave - 1].survivor_heal)
		else:
			var new_pawn = player_pawn_scene.instantiate()
			new_pawn.team = 1
			piece_layer.add_child(new_pawn)
			all_pieces.append(new_pawn)
			new_pawn.current_health = wave_definitions[Global.current_wave - 1].replacement_health
			new_pawn.grid_pos = Vector2i(i, 6)
			new_pawn.position = grid_to_pixel(new_pawn.grid_pos)
			if new_pawn.has_node("HealthBar"):
				new_pawn.get_node("HealthBar").max_value = new_pawn.max_health
				new_pawn.get_node("HealthBar").value = new_pawn.current_health
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
						if child.sprite_frames.has_animation("idle_up"):
							child.play("idle_up")
					else:
						if child.sprite_frames.has_animation("idle_down"):
							child.play("idle_down")
	backup_player_pieces()
func check_and_trigger_next_wave() -> void:
	if game_finished or count_enemies_alive() > 0:
		return
	if Global.current_wave >= max_waves:
		game_finished = true
		SoundManager.stop_bgm()
		SoundManager.play_sound(SoundManager.sfx_victory)
		win_screen.show()
		get_tree().paused = true
	else:
		await transition_to_next_wave()
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
func spawn_enemy_wave() -> void:
	if Global.current_wave < 1 or Global.current_wave > wave_definitions.size():
		return
	for spawn: WaveSpawn in wave_definitions[Global.current_wave - 1].spawns:
		if spawn.scene == null:
			continue
		var enemy = spawn.scene.instantiate()
		enemy.name = "%s_%d" % [spawn.scene.resource_path.get_file().get_basename(), all_pieces.size()]
		enemy.team = 2
		piece_layer.add_child(enemy)
		all_pieces.append(enemy)
		enemy.grid_pos = spawn.grid_pos
		enemy.global_position = grid_to_pixel(enemy.grid_pos)
func spawn_final_boss():
	boss = dragon_res.instantiate()
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
func deal_damage(unit, amount: float) -> void:
	combat_resolver.deal_damage(unit, amount)
func _input(event):
	if is_resolving_turn or game_finished or has_moved_main_piece: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var clicked_grid = calculate_grid_position(click_pos)
		if not is_within_board(clicked_grid): return
		var piece_at_click = get_piece_at(clicked_grid)
		if piece_at_click and piece_at_click.team == 1 and not UnitDefinition.is_kind(piece_at_click, UnitDefinition.Kind.EARTH_WALL):
			selected_piece = piece_at_click
			SoundManager.play_sound(SoundManager.sfx_select_pawn, -10)
			show_highlights(selected_piece)
		elif selected_piece != null:
			var p = selected_piece 
			var valid_moves = get_valid_moves(p)
			if clicked_grid in valid_moves:
				if p.get("is_grabbed"):
					force_release_all_grabs(p)
				move_piece(p, clicked_grid)
				p.has_moved = true
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
	if not is_instance_valid(piece):
		return
	if piece.get("is_grabbed"):
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
		if is_instance_valid(p) and p.team == my_team and UnitDefinition.is_kind(p, UnitDefinition.Kind.KING):
			return p
	return null
func queen_grab_counter(queen):
	return combat_resolver.queen_grab_counter(queen)
func find_queen_ranged_target(queen):
	return combat_resolver.find_queen_ranged_target(queen)
func _on_attack_pressed():
	if is_resolving_turn or game_finished:
		return
	SoundManager.play_sound(SoundManager.sfx_attack)
	if current_command == Command.ATTACK:
		current_command = Command.IDLE
		btn_attack.modulate = Color(1, 1, 1)
	else:
		current_command = Command.ATTACK
		btn_attack.modulate = Color(1, 0.5, 0.5)
		btn_defend.modulate = Color(1, 1, 1)
		Global.tutorial_attack_performed.emit()
func _on_defend_pressed():
	if is_resolving_turn or game_finished:
		return
	SoundManager.play_sound(SoundManager.sfx_defend)
	if current_command == Command.DEFEND:
		current_command = Command.IDLE
		btn_defend.modulate = Color(1, 1, 1)
	else:
		current_command = Command.DEFEND
		btn_defend.modulate = Color(0.5, 0.5, 1)
		btn_attack.modulate = Color(1, 1, 1)
func _on_end_turn_pressed() -> void:
	await turn_resolver.resolve_turn()
func execute_all_combat_logic():
	return combat_resolver.execute_all_combat_logic()
func _is_living_target(target) -> bool:
	return combat_resolver._is_living_target(target)
func _begin_piece_attack(piece: Piece) -> bool:
	return combat_resolver._begin_piece_attack(piece)
func move_team_logic(team_num: int):
	return combat_resolver.move_team_logic(team_num)
func find_best_target(for_piece):
	return combat_resolver.find_best_target(for_piece)
func get_closest(for_piece, list):
	return combat_resolver.get_closest(for_piece, list)
func get_next_step_towards(start: Vector2i, target: Vector2i) -> Vector2i:
	return combat_resolver.get_next_step_towards(start, target)
func execute_queen_logic(queen):
	return combat_resolver.execute_queen_logic(queen)
func get_surrounding_cells(pos: Vector2i, dist: int) -> Array:
	return combat_resolver.get_surrounding_cells(pos, dist)
func execute_rook_attack(rook, target_unit) -> bool:
	return combat_resolver.execute_rook_attack(rook, target_unit)
func _apply_rook_recoil(rook, forward: Vector2i) -> void:
	combat_resolver._apply_rook_recoil(rook, forward)
func execute_rook_logic(rook):
	return combat_resolver.execute_rook_logic(rook)
func _find_rook_target(rook):
	return combat_resolver._find_rook_target(rook)
func execute_knight_logic(knight):
	return combat_resolver.execute_knight_logic(knight)
func find_safest_pos(piece):
	return combat_resolver.find_safest_pos(piece)
func execute_bishop_logic(bishop, allow_movement: bool = true):
	return combat_resolver.execute_bishop_logic(bishop, allow_movement)
func execute_boss_turn():
	return combat_resolver.execute_boss_turn()
func scream_pushback():
	return combat_resolver.scream_pushback()
func fire_breath_single():
	return combat_resolver.fire_breath_single()
func claw_swipe():
	return combat_resolver.claw_swipe()
func triple_fireball():
	return combat_resolver.triple_fireball()
func check_and_execute_grab(pawn):
	return combat_resolver.check_and_execute_grab(pawn)
func force_release_all_grabs(piece = null):
	return combat_resolver.force_release_all_grabs(piece)
func kill_piece(piece) -> void:
	combat_resolver.kill_piece(piece)
func apply_knockback(unit, push_dir: Vector2i, max_dist: int, impact_damage: int = 0) -> bool:
	return combat_resolver.apply_knockback(unit, push_dir, max_dist, impact_damage)
func create_projectile_effect(start_pos: Vector2, end_pos: Vector2) -> void:
	presentation.projectile(start_pos, end_pos)
func get_valid_moves(piece) -> Array:
	var moves = []
	var directions = []
	var max_dist = piece.definition.move_range
	if UnitDefinition.is_kind(piece, UnitDefinition.Kind.KNIGHT):
		var l_moves = [Vector2i(1,2), Vector2i(2,1), Vector2i(-1,2), Vector2i(-2,1),
			Vector2i(1,-2), Vector2i(2,-1), Vector2i(-1,-2), Vector2i(-2,-1)]
		for m in l_moves:
			var target = piece.grid_pos + m
			if is_within_board(target) and is_cell_vacant(target): moves.append(target)
		return moves
	if UnitDefinition.is_kind(piece, UnitDefinition.Kind.ROOK):
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		max_dist = piece.definition.move_range
	elif UnitDefinition.is_kind(piece, UnitDefinition.Kind.BISHOP):
		directions = [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = piece.definition.move_range
	elif UnitDefinition.is_kind(piece, UnitDefinition.Kind.QUEEN):
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = piece.definition.move_range
	else:
		directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
		max_dist = piece.definition.move_range
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
	return combat_resolver.process_ammo_reloads()
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
	execute_aoe_effect(target_grids, directions, 35.0, "damage", "lua")
func execute_new_fire_fire_spell(target_grids: Array, directions: Array):
	var base_damage = 52.5 
	var impact_map = execute_aoe_effect(target_grids, directions, base_damage, "damage", "lua")
	for grid_pos in impact_map.keys():
		add_tile_effect(grid_pos, "fire_tile", 2)
func execute_new_water_spell(target_grids: Array, directions: Array):
	print("[Phép Nước] Bắt đầu dội mưa...")
	execute_aoe_effect(target_grids, directions, 50.0, "heal", "nuoc")
	Global.add_ink(250)
func execute_new_water_water_spell(target_grids: Array, directions: Array):
	var impact_map = execute_aoe_effect(target_grids, directions, 0, "heal", "nuoc")
	for grid_pos in impact_map.keys():
		add_tile_effect(grid_pos, "water_tile", 3)
func execute_new_wind_spell(target_grids: Array, directions: Array):
	print("[Phép Gió] Kích hoạt!")
	if target_grids.is_empty(): return
	var has_direction = not directions.is_empty()
	for i in range(target_grids.size()):
		var grid_pos = target_grids[i]
		var dir = Vector2i.ZERO
		if has_direction:
			dir = directions[i] if i < directions.size() else directions[0]
		var unit = get_piece_at(grid_pos) 
		if active_tile_effects.has(grid_pos):
			var old_effect = active_tile_effects[grid_pos]["type"]
			_trigger_immediate_tile_effect(grid_pos, old_effect, unit)
		if not has_direction:
			play_wind_visual(grid_pos, "gio")
			if is_instance_valid(unit) and unit.has_method("add_buff"):
				unit.add_buff("double_attack", 0, 1)
		else:
			play_wind_visual(grid_pos, "giogio")
			if is_instance_valid(unit):
				var target_push_pos = grid_pos + dir
				var is_blocked = not is_within_board(target_push_pos) or is_instance_valid(get_piece_at(target_push_pos))
				
				if not is_blocked:
					apply_knockback(unit, dir, 1, 0)
					if unit.has_method("add_buff"):
						unit.add_buff("stun", 0, 1)
				else:
					if unit.has_method("add_buff"):
						unit.add_buff("stun", 0, 1)
func execute_new_wind_wind_spell(target_grids: Array, directions: Array):
	SoundManager.play_sound(SoundManager.sfx_wind)
	var dir_count = directions.size()
	if dir_count == 0:
		for grid_pos in target_grids:
			var target_unit = get_piece_at(grid_pos)
			if is_instance_valid(target_unit) and target_unit.has_method("add_buff"):
				target_unit.add_buff("stun", 0, 3)
	elif dir_count == 1:
		var push_dir = directions[0]
		
		execute_aoe_effect(target_grids, directions, 0, "none", "giogio") 

		for grid_pos in target_grids:
			var target_unit = get_piece_at(grid_pos)
			if is_instance_valid(target_unit):
				apply_knockback(target_unit, push_dir, 2, 15) 
				if target_unit.has_method("add_buff"):
					target_unit.add_buff("stun", 0, 2)
					
	else:
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
func execute_new_earth_spell(target_grids: Array, directions: Array):
	execute_aoe_effect(target_grids, directions, 1.0, "earth_buff", "")
	Global.add_paper(3)
func execute_new_earth_earth_spell(target_grids: Array, directions: Array):
	Global.add_paper(5)
	execute_aoe_effect(target_grids, directions, 0.5, "earth_earth_buff", "")
func execute_new_fire_water_spell(target_grids: Array, directions: Array):
	print("[Sương Mù] Kích hoạt sương mù bảo vệ!")
	if target_grids.is_empty(): return
	Global.add_ink(50)
	var duration = 5
	if target_grids.size() >= 2:
		duration -= 2
	duration = max(1, duration)
	var spread_dirs = []
	if directions.size() == 1:
		spread_dirs = directions
	else:
		spread_dirs = [] 
	var center_pos = target_grids[0]
	add_tile_effect(center_pos, "fog_tile", duration, spread_dirs, true)
func execute_new_fire_wind_spell(target_grids: Array, directions: Array):
	SoundManager.play_sound(SoundManager.sfx_fire)
	print("[Bão Lửa] Kích hoạt bão lửa 3x3!")
	if target_grids.is_empty(): return
	var duration = 5
	if target_grids.size() >= 2:
		duration -= 2
	duration = max(1, duration)
	var spread_dirs = []
	if directions.size() == 1:
		spread_dirs = directions
	else:
		print("[Bão Lửa] Hướng gió hỗn loạn, bão sẽ đứng im!")
		spread_dirs = [] 
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	for grid_pos in target_grids:
		add_tile_effect(grid_pos, "firestorm_tile", duration, spread_dirs, true)
func execute_new_water_earth_spell(target_grids: Array, directions: Array):
	print("[Đầm Lầy] Kích hoạt vũng lầy!")
	Global.add_paper(1)
	var duration = 10
	var dir_count = directions.size()
	if dir_count > 1: duration -= (dir_count - 1)
	if target_grids.size() >= 2: duration -= 4
	duration = max(1, duration)
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	for grid_pos in target_grids:
		add_tile_effect(grid_pos, "swamp_tile", duration, directions, true)
func execute_new_fire_earth_spell(target_grids: Array, directions: Array):
	print("[Dung Nham] Kích hoạt dòng chảy!")
	Global.add_paper(1)
	var duration = 10
	var dir_count = directions.size()
	if dir_count > 1: duration -= (dir_count - 1)
	if target_grids.size() >= 2: duration -= 4
	duration = max(1, duration)
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	for grid_pos in target_grids:
		add_tile_effect(grid_pos, "lava_tile", duration, directions)
func execute_new_water_wind_spell(target_grids: Array, directions: Array):
	SoundManager.play_sound(SoundManager.sfx_water)
	print("[Cơn Mưa] Kích hoạt đám mây di chuyển!")
	if target_grids.is_empty(): return
	var duration = 6
	if target_grids.size() >= 2:
		duration -= 2
	duration = max(1, duration)
	var spread_dirs = []
	if directions.size() == 1:
		spread_dirs = directions
	else:
		print("[Cơn Mưa] Gió nhiễu loạn! Đám mây sẽ đứng im.")
		spread_dirs = [] 
	execute_aoe_effect(target_grids, directions, 0, "none", "")
	for grid_pos in target_grids:
		add_tile_effect(grid_pos, "rain_tile", duration, spread_dirs)
func execute_new_wind_earth_spell(target_grids: Array, directions: Array, aoe_value_modifier: float = 1.0):
	SoundManager.play_sound(SoundManager.sfx_earthwind)
	if target_grids.is_empty(): return
	var origin = target_grids[0]
	var dir_count = directions.size()
	var duration = max(1, 9 - dir_count) 
	var base_hp = 500.0
	var final_hp = int(base_hp * aoe_value_modifier)
	var block_grids = [origin]
	for dir in directions:
		var next_grid = origin + dir
		if not block_grids.has(next_grid):
			block_grids.append(next_grid)
	execute_aoe_effect(block_grids, directions, 0, "none", "")
	var adj_dirs = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	for grid in block_grids:
		if not is_within_board(grid): continue
		if not is_cell_vacant(grid):
			Global.add_paper(1)
			print("Ô có người! Hoàn 1 giấy.")
			continue
		spawn_earth_block(grid, final_hp, duration)
		for adj in adj_dirs:
			var adj_grid = grid + adj
			var unit = get_piece_at(adj_grid)
			if is_instance_valid(unit) and unit.get("team") == 1:
				Global.add_paper(1)
				print("Buff đồng minh tại ", adj_grid, ". Nhận 1 giấy.")
				if unit.has_method("add_buff"):
					unit.add_buff("damage_reduction", 0.5, duration) 
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
func get_king_piece():
	for piece in all_pieces:
		if UnitDefinition.is_kind(piece, UnitDefinition.Kind.KING):
			return piece
	return null
func play_spell_animation(grid_pos: Vector2i, anim_name: String, target_unit = null):
	var effect = SPELL_EFFECT_SCENE.instantiate()
	effect.visible = false 
	get_tree().current_scene.add_child(effect)
	var base_pos = Vector2.ZERO
	if target_unit != null:
		base_pos = target_unit.global_position
	else:
		base_pos = grid_to_pixel(grid_pos)
	effect.global_position = base_pos + Vector2(0, -30) 
	effect.play(anim_name)
	effect.visible = true 
	effect.animation_finished.connect(effect.queue_free)
func execute_aoe_effect(target_grids: Array, directions: Array, base_value: float, effect_type: String, ground_anim: String) -> Dictionary:
	var is_multi_target = target_grids.size() > 1
	var multi_factor = 0.4 if is_multi_target else 1.0
	var direction_factor = 1.0 / (directions.size() + 1)
	var value_per_hit = base_value * multi_factor * direction_factor
	var impact_map = {} 
	for center_pos in target_grids:
		_add_to_impact_map(impact_map, center_pos)
		for dir in directions:
			var offset_pos = center_pos + Vector2i(dir.x, dir.y)
			if is_within_board(offset_pos):
				_add_to_impact_map(impact_map, offset_pos)
	for grid_pos in impact_map.keys():
		var hit_count = impact_map[grid_pos]
		var total_value = value_per_hit * hit_count
		var target_unit = get_unit_at(grid_pos)
		if ground_anim != "":
			play_spell_animation(grid_pos, ground_anim, target_unit)
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
			deal_damage(unit, value)
			print(" -> Ô ", grid_pos, " Nổ ", value, " sát thương lên [", unit_name, "]")
			
		"earth_buff":
			if unit.has_method("add_buff"):
				unit.add_buff("damage_reduction", value, 1) 
				
		"earth_earth_buff":
			if unit.has_method("add_buff"):
				unit.add_buff("damage_reduction", value, 2)
				
		"stun_1":
			if unit.has_method("add_buff"):
				unit.add_buff("stun", 1.0, 1)
		"stun_2":
			if unit.has_method("add_buff"):
				unit.add_buff("stun", 1.0, 2)
		"knockback_2":
			if is_instance_valid(unit):
				apply_knockback(unit, dir, 2, 5)
		_:
			print(" -> Ô ", grid_pos, " có hiệu ứng không xác định!")
var active_tile_effects = {} 

func add_tile_effect(grid_pos: Vector2i, effect_type: String, duration: int, spread_dirs: Array = [], is_center: bool = true, is_first_spawn: bool = true):
	if duration <= 0 or not is_within_board(grid_pos):
		return
	var piece = get_piece_at(grid_pos)
	if is_instance_valid(piece):
		if UnitDefinition.is_kind(piece, UnitDefinition.Kind.EARTH_WALL):
			print("Vướng cục đá/tường đất tại ", grid_pos, " -> Hủy phép!")
			return 
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
		"swamp_tile":
			spawned_visual.play("nuocdat")
			final_offset = Vector2(0, -10)
			spawned_visual.z_index = 40
		"firestorm_tile":
			spawned_visual.play("luagio")
			final_offset = Vector2(0, -30)
			spawned_visual.z_index = 100
		"fog_tile": 
			final_offset = Vector2(0, -20)
			spawned_visual.z_index = 150 
			spawned_visual.play("luanuoc1")
			if is_first_spawn:
				spawned_visual.frame = 0
			else:
				spawned_visual.frame = 2 
			var custom_loop = func():
				if is_instance_valid(spawned_visual) and spawned_visual.animation == "luanuoc1":
					spawned_visual.frame = 2
			if not spawned_visual.animation_looped.is_connected(custom_loop):
				spawned_visual.animation_looped.connect(custom_loop)
	spawned_visual.global_position = base_pos + final_offset
	active_tile_effects[grid_pos] = {
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
				if piece.has_method("add_buff"): piece.add_buff("root", 0, 3)
				print("-> Đầm lầy vừa trúng đích, trói chân ngay lập tức: ", piece.name)
			"fire_tile", "lava_tile", "firestorm_tile":
				if piece.has_method("take_damage"): piece.take_damage(10.0) 
				print("-> Lửa vừa rơi trúng đầu, đốt ngay lập tức: ", piece.name)
			"water_tile", "rain_tile":
				if piece.has_method("heal"): piece.heal(20)
func process_all_tile_effects():
	var grids_to_remove = []
	var new_puddle_tiles = []
	var new_rain_tiles = [] 
	var new_firestorm_tiles = []
	var new_fog_tiles = []
	for grid_pos in active_tile_effects.keys():
		var effect = active_tile_effects[grid_pos]
		effect["turns"] -= 1
		effect["is_new"] = false
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
						Global.add_paper(-1)
			"swamp_tile":
				var unit = get_unit_at(grid_pos)
				if is_instance_valid(unit):
					if unit.has_method("heal"): 
						unit.heal(20) 
					if unit.has_method("add_buff"):
						unit.add_buff("root", 0, 2)
					if unit.get("team") == 1: 
						Global.add_ink(50)
			"rain_tile":
				var unit = get_unit_at(grid_pos)
				if is_instance_valid(unit):
					if unit.has_method("heal"): unit.heal(50)
					if unit.get("team") == 1:
						Global.add_ink(50)
						if UnitDefinition.is_kind(unit, UnitDefinition.Kind.KING) or UnitDefinition.is_kind(unit, UnitDefinition.Kind.KING):
							Global.add_paper(-1)
				if effect.get("is_center", false):
					for dir in effect.get("spread_dirs", []):
						var next_pos = grid_pos + dir
						if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
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
						if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
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
				var base_dmg = 15.0
				var center_pos_i = Vector2i(grid_pos)
				apply_firestorm_impact(center_pos_i, base_dmg)
				if effect.get("is_center", false):
					for dir in effect.get("spread_dirs", []):
						var next_pos = center_pos_i + dir
						if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
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
					if is_within_board(next_pos) and not active_tile_effects.has(next_pos):
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
	if active_tile_effects.has(grid_pos):
		var effect_data = active_tile_effects[grid_pos]
		if is_instance_valid(effect_data.get("visual_node")):
			effect_data["visual_node"].queue_free()
		active_tile_effects.erase(grid_pos)
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
		
	add_child(block)
	block.global_position = grid_to_pixel(grid_pos)
	
	if block.has_method("set_grid_position"):
		block.set_grid_position(grid_pos)
	else:
		block.set("grid_pos", grid_pos)
		
	all_pieces.append(block)
func is_tile_foggy(grid_pos: Vector2i) -> bool:
	if active_tile_effects.has(grid_pos):
		return active_tile_effects[grid_pos]["type"] == "fog_tile"
	return false
func cast_random_flight(unit):
	var empty_cells = []
	
	for x in range(0, 8): 
		for y in range(0, 8):
			var test_pos = Vector2i(x, y)
			if get_unit_at(test_pos) == null and is_within_board(test_pos): 
				empty_cells.append(test_pos)
				
	if empty_cells.size() > 0:
		var random_pos = empty_cells[randi() % empty_cells.size()]
		
		var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		var random_dir = dirs[randi() % dirs.size()]
		unit.grid_pos = random_pos
		unit.global_position = grid_to_pixel(random_pos)
		if unit.get("direction") != null:
			unit.direction = random_dir
func _trigger_immediate_tile_effect(grid_pos: Vector2i, type: String, unit):
	print("-> [Phép Gió] Vừa quạt trúng ô hiệu ứng: ", type)
	
	if active_tile_effects.has(grid_pos):
		var visual = active_tile_effects[grid_pos].get("visual_node")
		if is_instance_valid(visual):
			visual.modulate = Color(2.0, 2.0, 2.0, 1) 
			var tw = get_tree().create_tween()
			tw.tween_property(visual, "scale", Vector2(1.4, 1.4), 0.1)
			tw.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.2)
			tw.tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.2)
	if not is_instance_valid(unit): return
	match type:
		"water_tile", "swamp_tile":
			if unit.has_method("heal"): unit.heal(20)
			if type == "water_tile" and unit.get("team") == 1: Global.add_ink(50)
			if type == "swamp_tile" and unit.has_method("add_buff"): unit.add_buff("root", 0, 2)
		"fire_tile", "lava_tile", "firestorm_tile":
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
func check_trap_at(unit, grid_pos):
	for effect_pos in active_tile_effects:
		var effect = active_tile_effects[effect_pos]
		if effect.name == "firestorm_tile":
			var distance = grid_pos - effect_pos
			if abs(distance.x) <= 1 and abs(distance.y) <= 1:
				var push_dir = distance
func apply_firestorm_impact(center_pos_i: Vector2i, base_dmg: float):
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
							var target_pixel_pos = grid_to_pixel(target_push_pos)
							unit.move_to_grid(target_push_pos, target_pixel_pos)
						deal_damage(unit, base_dmg)
						
func backup_player_pieces():
	player_pieces_backup.clear()
	for p in all_pieces:
		if is_instance_valid(p) and p.team == 1 and p is Piece:
			var data = {
				"scene_path": p.scene_file_path, 
				"grid_pos": p.grid_pos,
				"hp": p.current_health,
				"name": p.name
			}
			player_pieces_backup.append(data)
	print("Đã lưu trạng thái lính! Số lượng: ", player_pieces_backup.size())
	wave_resources_backup = Global.get_resources()
	Global.save_game(player_pieces_backup)
func _on_chơi_lại_pressed():
	Global.reset_run()
	get_tree().paused = false
	get_tree().reload_current_scene()
func _on_chơi_lại_2_pressed() :
	restart_current_wave()
func restart_current_wave():
	if is_resolving_turn:
		return
	_clear_wave_effects()
	force_release_all_grabs()
	game_finished = false
	is_player_turn = true
	has_moved_main_piece = false
	current_command = Command.IDLE
	btn_attack.modulate = Color.WHITE
	btn_defend.modulate = Color.WHITE
	Global.restore_resources(wave_resources_backup)
	var magic = get_parent().get_node("MagicDrawingSystem")
	# Continue runs from this node's _ready, before the sibling UI is ready.
	if magic.is_node_ready():
		magic.clear_all_inputs()
	magic.hide()
	%ClosedScrollButton.show()
	clear_highlights()
	
	current_turn = 1
	if turn_label: 
		turn_label.text = "Turn: 1"
	for p in all_pieces:
		if is_instance_valid(p):
			p.queue_free()
	all_pieces.clear()
	for data in player_pieces_backup:
		if data["scene_path"] != null and data["scene_path"] != "":
			var p_scene = load(data["scene_path"])
			var p = p_scene.instantiate()
			p.team = 1
			if has_node("PieceLayer"):
				get_node("PieceLayer").add_child(p)
			else:
				add_child(p) 
			all_pieces.append(p)
			
			p.grid_pos = data["grid_pos"]
			p.position = grid_to_pixel(p.grid_pos)
			p.current_health = data["hp"]
			p.name = data["name"]
			if p.has_node("HealthBar"):
				p.get_node("HealthBar").value = p.current_health
			if p.has_method("update_visuals"):
				p.update_visuals()
	spawn_enemy_wave()
	if lose_screen: lose_screen.hide()
	if win_screen: win_screen.hide()
	set("can_interact", true)
	get_tree().paused = false
func show_lose_screen():
	if game_finished:
		return
	game_finished = true
	print("Vua đã băng hà! GAME OVER!")
	SoundManager.stop_bgm()
	SoundManager.play_sound(SoundManager.sfx_defeat)
	if "can_interact" in self:
		set("can_interact", false)
	if "lose_screen" in self and lose_screen:
		lose_screen.show()
	elif has_node("CanvasLayer/LosePanel"):
		get_node("CanvasLayer/LosePanel").show()
	get_tree().paused = true

func restore_from_save():
	player_pieces_backup = Global.saved_pieces.duplicate(true)
	wave_resources_backup = Global.saved_resources.duplicate(true)
	restart_current_wave()

func _clear_wave_effects() -> void:
	for pos in active_tile_effects.keys():
		_remove_tile_effect(pos)
	for p in all_pieces.duplicate():
		if is_instance_valid(p) and UnitDefinition.is_kind(p, UnitDefinition.Kind.EARTH_WALL):
			kill_piece(p)
