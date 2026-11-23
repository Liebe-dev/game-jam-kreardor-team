extends Node2D

signal turn_resolved(result: Dictionary)
signal combat_event(result: Dictionary)
var combat_resolver: CombatResolver
var turn_resolver: TurnResolver
var presentation: BattlePresentation
var spell_resolver: SpellResolver
var tile_effects: TileEffectSystem
signal spell_resolved(result: Dictionary)

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
	spell_resolver = SpellResolver.new(self)
	tile_effects = TileEffectSystem.new(self, spell_resolver.catalog)
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
	return spell_resolver._add_to_impact_map(map, pos)
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
	return spell_resolver.cast_complex_spell(elements, coordinates, directions)
func execute_new_fire_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_fire_spell(target_grids, directions)
func execute_new_fire_fire_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_fire_fire_spell(target_grids, directions)
func execute_new_water_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_water_spell(target_grids, directions)
func execute_new_water_water_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_water_water_spell(target_grids, directions)
func execute_new_wind_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_wind_spell(target_grids, directions)
func execute_new_wind_wind_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_wind_wind_spell(target_grids, directions)
func execute_new_earth_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_earth_spell(target_grids, directions)
func execute_new_earth_earth_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_earth_earth_spell(target_grids, directions)
func execute_new_fire_water_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_fire_water_spell(target_grids, directions)
func execute_new_fire_wind_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_fire_wind_spell(target_grids, directions)
func execute_new_water_earth_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_water_earth_spell(target_grids, directions)
func execute_new_fire_earth_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_fire_earth_spell(target_grids, directions)
func execute_new_water_wind_spell(target_grids: Array, directions: Array):
	return spell_resolver.execute_new_water_wind_spell(target_grids, directions)
func execute_new_wind_earth_spell(target_grids: Array, directions: Array, aoe_value_modifier: float = 1.0):
	return spell_resolver.execute_new_wind_earth_spell(target_grids, directions, aoe_value_modifier)
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
	return presentation.play_spell_animation(grid_pos, anim_name, target_unit)
func execute_aoe_effect(target_grids: Array, directions: Array, base_value: float, effect_type: String, ground_anim: String) -> Dictionary:
	return spell_resolver.execute_aoe_effect(target_grids, directions, base_value, effect_type, ground_anim)
func apply_unit_effect(unit, effect_type: String, value: float, grid_pos: Vector2i, dir: Vector2i = Vector2i.ZERO):
	return spell_resolver.apply_unit_effect(unit, effect_type, value, grid_pos, dir)
var active_tile_effects: Dictionary:
	get: return tile_effects.active_effects

func add_tile_effect(grid_pos: Vector2i, effect_type: String, duration: int, spread_dirs: Array = [], is_center: bool = true, is_first_spawn: bool = true):
	return tile_effects.add_tile_effect(grid_pos, effect_type, duration, spread_dirs, is_center, is_first_spawn)
func process_all_tile_effects():
	return tile_effects.process_all_tile_effects()
func _remove_tile_effect(grid_pos: Vector2i):
	return tile_effects._remove_tile_effect(grid_pos)
func spawn_earth_block(grid_pos: Vector2i, hp: int, turns: int):
	return tile_effects.spawn_earth_block(grid_pos, hp, turns)
func is_tile_foggy(grid_pos: Vector2i) -> bool:
	return tile_effects.is_tile_foggy(grid_pos)
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
	return tile_effects._trigger_immediate_tile_effect(grid_pos, type, unit)
func play_wind_visual(grid_pos: Vector2i, anim_name: String):
	return presentation.play_wind_visual(grid_pos, anim_name)
func check_trap_at(unit, grid_pos):
	for effect_pos in active_tile_effects:
		var effect = active_tile_effects[effect_pos]
		if effect.name == "firestorm_tile":
			var distance = grid_pos - effect_pos
			if abs(distance.x) <= 1 and abs(distance.y) <= 1:
				var push_dir = distance
func apply_firestorm_impact(center_pos_i: Vector2i, base_dmg: float):
	return tile_effects.apply_firestorm_impact(center_pos_i, base_dmg)
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

func request_cast(elements: Array, coordinates: Array, directions: Array) -> void:
	spell_resolved.emit(spell_resolver.request_cast(elements, coordinates, directions))
