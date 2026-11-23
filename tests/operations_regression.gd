extends SceneTree
## Run through tests/run_operations.ps1; all checkpoints go to a supplied scratch directory.

var passed: int = 0
var failed: int = 0
var board: Node
var logic: Node
var magic: Node
var global: Node
var test_data_dir: String

func _initialize() -> void:
	_run.call_deferred()

func check(actual, expected, label: String) -> void:
	if actual == expected:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label, " expected=", expected, " actual=", actual)

func _run() -> void:
	test_data_dir = OS.get_environment("AUTOCHESSTO_TEST_DATA_DIR")
	if test_data_dir.is_empty() or not test_data_dir.is_absolute_path():
		print("Set AUTOCHESSTO_TEST_DATA_DIR to an absolute scratch path; refusing to use player saves.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(test_data_dir)
	global = root.get_node("Global")
	global.save_path = test_data_dir.path_join("checkpoint.dat")
	global.is_tutorial_done = true
	create_timer(90.0, true).timeout.connect(func(): print("TEST TIMEOUT"); quit(2))
	seed(20261123)
	for test_name in ["test_definition_data", "test_resources", "test_input_costs", "test_cast_validation", "test_damage", "test_status_turn", "test_tile_lifetime", "test_turn_lock", "test_wave_health", "test_checkpoint", "test_enemy_scenes", "test_wind_double_attack", "test_wind_special_attacks", "test_wind_restrictions", "test_wind_safety", "test_five_waves"]:
		var filter: String = OS.get_environment("AUTOCHESSTO_TEST_FILTER")
		if not filter.is_empty() and filter != test_name:
			continue
		await fresh_board()
		if await call(test_name) != true:
			failed += 1
			print("FAIL ", test_name, " aborted before returning")
		await clear_board()
	# Stop playing audio before shutdown, including the final victory sound.
	var sound_manager = root.get_node("SoundManager")
	for child in sound_manager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	sound_manager.queue_free()
	await process_frame
	# Let the audio thread release its last playback before the engine exits.
	await create_timer(0.2).timeout
	print("RESULT %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func fresh_board() -> void:
	global.reset_run()
	board = load("res://board.tscn").instantiate()
	root.add_child(board)
	current_scene = board
	logic = board.get_node("logicgame")
	magic = board.get_node("MagicDrawingSystem")
	await process_frame

func clear_board() -> void:
	paused = false
	# Let animation continuations finish before releasing their owners.
	await create_timer(0.8).timeout
	if is_instance_valid(board):
		board.free()
	current_scene = null
	await process_frame

func input_text(edit: LineEdit, value: String) -> void:
	edit.text = value
	# LineEdit.text assignment intentionally does not emit text_changed.
	edit.text_changed.emit(value)

func prepare_spell(column: String = "A", row: String = "8", element: int = 0) -> void:
	magic.clear_all_inputs()
	magic.cast_elements.append(element)
	magic.coord_edits[0].text = column
	magic.coord_edits[1].text = row

func test_definition_data() -> bool:
	var unit = logic.all_pieces[0]
	var other = logic.all_pieces[1]
	unit.definition = unit.definition.duplicate(true)
	unit.definition.melee_damage = 17.0
	var enemy = logic.all_pieces[9]
	unit.is_grabbed = true
	unit.grabbed_by = enemy
	enemy.is_grabbed = true
	enemy.grabbed_by = unit
	enemy.current_health = 200
	unit.name = "arbitrary_soldier_name"
	await logic._on_end_turn_pressed()
	check(enemy.current_health, 183, "definition melee damage drives real combat")
	check(other.definition.melee_damage, 10.0, "runtime copy does not mutate shared balance data")
	var knight = isolate_enemy("Knight", Vector2i(5, 6))
	knight.name = "renamed_without_type_hint"
	knight.definition = knight.definition.duplicate(true)
	knight.definition.melee_damage = 41.0
	await logic._on_end_turn_pressed()
	check(logic.find_my_king(1).current_health, 359, "unit kind controls renamed Knight AI and data controls damage")
	var custom_wave: WaveDefinition = logic.wave_definitions[0].duplicate(true)
	custom_wave.spawns.resize(1)
	logic.wave_definitions[0] = custom_wave
	for p in logic.all_pieces.duplicate():
		if p.team == 2:
			logic.kill_piece(p)
	logic.spawn_enemy_wave()
	check(logic.count_enemies_alive(), 1, "wave resource controls roster without code changes")
	return true

func test_resources() -> bool:
	input_text(magic.elem_edits[0], "ignis")
	check(global.current_ink, 900.0, "typing uses shared ink")
	global.add_ink(50.0)
	check(magic.current_ink, 950.0, "water restores usable ink")
	check(magic.ink_bar.value, 95.0, "ink UI follows shared resource")
	global.add_ink(5000.0)
	check(magic.current_ink, 1000.0, "ink is capped")
	global.add_ink(-5000.0)
	check(magic.current_ink, 0.0, "ink is nonnegative")
	global.add_paper(-500)
	check(global.paper_count, 0, "paper penalties cannot go negative")
	global.add_paper(3)
	check(magic.paper_label.text, "Giấy: 3", "paper rewards refresh UI")
	global.current_ink = 300.0
	magic._on_undo_button_pressed()
	check(magic.current_ink, 300.0, "undo cannot refill ink")
	return true

func test_input_costs() -> bool:
	input_text(magic.elem_edits[0], "ignis")
	magic._on_element_submitted("ignis", 0)
	input_text(magic.elem_edits[1], "ignis")
	magic._on_element_submitted("ignis", 1)
	check(global.current_ink, 800.0, "both submitted runes pay their full cost")
	check(magic.cast_elements.size(), 2, "two runes are registered once")
	magic._on_element_submitted("ignis", 1)
	check(magic.cast_elements.size(), 2, "hidden rune cannot be submitted twice")
	magic.clear_all_inputs()
	input_text(magic.coord_edits[0], "A")
	input_text(magic.coord_edits[0], "B")
	check(global.current_ink, 760.0, "equal-length replacement costs ink")
	input_text(magic.coord_edits[0], "")
	check(global.current_ink, 760.0, "deleting neither costs nor refunds ink")
	global.current_ink = 10.0
	input_text(magic.coord_edits[0], "A")
	check(magic.coord_edits[0].text, "", "unaffordable character is rejected")
	check(global.current_ink, 10.0, "rejected input preserves remaining ink")
	return true

func test_cast_validation() -> bool:
	prepare_spell("", "")
	magic._on_end_turn_button_pressed()
	check(global.paper_count, 10, "missing coordinates cost no paper")
	check(global.has_casted_spell, false, "invalid spell does not consume turn")
	prepare_spell("Z", "9")
	magic._on_end_turn_button_pressed()
	check(global.paper_count, 10, "out-of-board coordinates cost no paper")
	prepare_spell()
	magic.coord_edits[2].text = "D"
	magic._on_end_turn_button_pressed()
	check(global.paper_count, 10, "incomplete second target is rejected")
	global.paper_count = 0
	prepare_spell()
	magic._on_end_turn_button_pressed()
	check(global.paper_count, 0, "cannot spend paper below zero")
	check(global.has_casted_spell, false, "no paper blocks spell")
	global.paper_count = 10
	global.current_ink = 0.0 # The spell input was already paid for.
	prepare_spell()
	magic._on_end_turn_button_pressed()
	check(global.paper_count, 9, "valid paid spell spends exactly one paper")
	check(global.has_casted_spell, true, "valid spell consumes this turn's cast")
	prepare_spell()
	magic._on_end_turn_button_pressed()
	check(global.paper_count, 9, "second spell in same turn is blocked")
	await logic._on_end_turn_pressed()
	check(global.has_casted_spell, false, "End Turn permits next spell")
	return true

func test_damage() -> bool:
	var pawn = logic.all_pieces[0]
	pawn.current_health = 200
	pawn.add_buff("damage_reduction", 0.5, 1)
	logic.deal_damage(pawn, 40)
	check(pawn.current_health, 180, "combat damage respects shield")
	pawn.take_damage(40)
	check(pawn.current_health, 160, "direct damage uses same shield")
	logic.deal_damage(pawn, 5)
	check(pawn.current_health, 157, "fractional damage rounds consistently")
	logic.deal_damage(pawn, -100)
	check(pawn.current_health, 157, "negative damage cannot heal")
	pawn.current_health = 100
	pawn.damage_reduction_rate = 0.0
	logic.add_tile_effect(pawn.grid_pos, "fire_tile", 2)
	check(pawn.current_health, 90, "tile impact reaches common damage path")
	logic._remove_tile_effect(pawn.grid_pos)
	logic.deal_damage(pawn, 1000)
	check(logic.all_pieces.has(pawn), false, "lethal damage removes soldier from board registry")
	logic.spawn_earth_block(Vector2i(0, 0), 50, 3)
	var wall = logic.get_piece_at(Vector2i(0, 0))
	logic.deal_damage(wall, 20)
	check(wall.hp, 30, "common damage supports earth walls")
	logic.deal_damage(wall, 100)
	check(logic.get_piece_at(Vector2i(0, 0)), null, "destroyed wall releases its cell")
	var king = logic.find_my_king(1)
	king.take_damage(10000)
	check(logic.game_finished, true, "direct lethal damage to king ends game")
	check(logic.lose_screen.visible, true, "king death displays defeat")
	return true

func test_status_turn() -> bool:
	var pawn = logic.all_pieces[0]
	var enemy = logic.all_pieces[9]
	pawn.grid_pos = Vector2i(0, 4)
	enemy.grid_pos = Vector2i(0, 3)
	pawn.is_grabbed = true
	pawn.grabbed_by = enemy
	enemy.is_grabbed = true
	enemy.grabbed_by = pawn
	enemy.stun_turns = 1
	pawn.add_buff("damage_reduction", 0.5, 1)
	var start_hp: int = pawn.current_health
	await logic._on_end_turn_pressed()
	check(pawn.current_health, start_hp, "one-turn stun blocks enemy combat before expiring")
	check(enemy.stun_turns, 0, "stun expires once after actions")
	check(pawn.damage_reduction_rate, 0.0, "one-turn shield expires after combat")
	pawn.add_buff("damage_reduction", 0.5, 1)
	await logic._on_end_turn_pressed()
	check(pawn.current_health, start_hp - 5, "shield stays active through enemy combat")
	logic.force_release_all_grabs()
	enemy.grid_pos = Vector2i(0, 1)
	enemy.root_turns = 1
	var enemy_pos: Vector2i = enemy.grid_pos
	await logic._on_end_turn_pressed()
	check(enemy.grid_pos, enemy_pos, "one-turn root blocks movement")
	check(enemy.root_turns, 0, "root expires once after actions")
	await logic._on_end_turn_pressed()
	check(enemy.grid_pos != enemy_pos, true, "movement resumes next turn")
	return true

func test_tile_lifetime() -> bool:
	var pawn = logic.all_pieces[0]
	pawn.current_health = 200
	var pos: Vector2i = pawn.grid_pos
	logic.add_tile_effect(pos, "fire_tile", 2)
	check(pawn.current_health, 190, "fire has one initial impact")
	await logic._on_end_turn_pressed()
	check(pawn.current_health, 180, "fire ticks once on first turn")
	check(logic.active_tile_effects[pos].turns, 1, "tile loses one turn of lifetime")
	await logic._on_end_turn_pressed()
	check(pawn.current_health, 170, "fire applies final tick before expiry")
	check(logic.active_tile_effects.has(pos), false, "two-turn tile expires after two End Turns")
	global.current_ink = 400.0
	logic.add_tile_effect(pos, "water_tile", 1)
	await logic._on_end_turn_pressed()
	check(global.current_ink, 450.0, "healing tile restores shared ink once")
	logic.add_tile_effect(Vector2i(2, 2), "firestorm_tile", 3, [Vector2i.RIGHT])
	logic.process_all_tile_effects()
	check(logic.active_tile_effects.has(Vector2i(3, 2)), true, "firestorm moves one cell per phase")
	check(logic.active_tile_effects.has(Vector2i(2, 2)), false, "firestorm removes old center")
	check(logic.active_tile_effects[Vector2i(3, 2)].turns, 2, "spread inherits remaining lifetime")
	logic._clear_wave_effects()
	return true

func test_turn_lock() -> bool:
	var turn: int = logic.current_turn
	logic._on_end_turn_pressed()
	check(logic.is_resolving_turn, true, "turn locks before first await")
	logic._on_end_turn_pressed()
	prepare_spell()
	magic._on_end_turn_button_pressed()
	check(global.paper_count, 10, "cannot cast during resolution")
	logic._on_attack_pressed()
	check(logic.current_command, logic.Command.IDLE, "cannot change command during resolution")
	await create_timer(0.7).timeout
	check(logic.current_turn, turn + 1, "double click resolves only one turn")
	check(logic.is_resolving_turn, false, "turn unlocks after completion")
	return true

func test_wave_health() -> bool:
	var pawn = logic.all_pieces[0]
	pawn.current_health = 100
	pawn.add_buff("damage_reduction", 0.5, 2)
	logic.kill_piece(logic.all_pieces[1])
	logic.add_tile_effect(Vector2i(0, 0), "fire_tile", 4)
	logic.spawn_earth_block(Vector2i(1, 0), 50, 4)
	await logic.transition_to_next_wave()
	check(pawn.current_health, 130, "survivor heals 30 between waves")
	check(pawn.damage_reduction_rate, 0.0, "temporary shield resets between waves")
	var replacement = logic.get_piece_at(Vector2i(7, 6))
	check(replacement.current_health, 20, "replacement uses configured 20 HP")
	check(replacement.get_node("HealthBar").max_value, float(replacement.max_health), "replacement health bar matches max HP")
	check(logic.active_tile_effects.is_empty(), true, "new wave clears old terrain")
	check(logic.all_pieces.filter(func(p): return p.team == 1).size(), 9, "earth walls are not treated as surviving soldiers")
	check(logic.count_enemies_alive(), 8, "wave two spawns all eight enemies")
	return true

func test_checkpoint() -> bool:
	global.paper_count = 7
	global.current_ink = 345.0
	logic.backup_player_pieces()
	logic.add_tile_effect(Vector2i(0, 0), "fire_tile", 4)
	logic.has_moved_main_piece = true
	global.paper_count = 1
	global.current_ink = 5.0
	global.has_casted_spell = true
	logic.restart_current_wave()
	check(global.paper_count, 7, "retry restores checkpoint paper")
	check(global.current_ink, 345.0, "retry restores checkpoint ink")
	check(global.has_casted_spell, false, "retry clears spell restriction")
	check(logic.has_moved_main_piece, false, "retry clears movement restriction")
	check(logic.active_tile_effects.is_empty(), true, "retry clears terrain")
	check(global.load_game(), true, "checkpoint can be read")
	var bytes_before = FileAccess.get_file_as_bytes(global.save_path)
	await clear_board()
	board = load("res://board.tscn").instantiate()
	root.add_child(board)
	current_scene = board
	logic = board.get_node("logicgame")
	magic = board.get_node("MagicDrawingSystem")
	await process_frame
	check(logic.all_pieces.filter(func(p): return p.team == 1).size(), 9, "continue restores nine player units")
	check(global.current_ink, 345.0, "continue restores ink")
	check(FileAccess.get_file_as_bytes(global.save_path), bytes_before, "continue does not overwrite checkpoint with empty army")
	# Preserve compatibility with the original two-value checkpoint format.
	var file := FileAccess.open(global.save_path, FileAccess.WRITE)
	file.store_var(2)
	file.store_var(logic.player_pieces_backup)
	file.close()
	check(global.load_game(), true, "legacy checkpoint loads")
	global.restore_resources(global.saved_resources)
	check(global.current_ink, 1000.0, "legacy checkpoint receives default ink")
	global.reset_run()
	check(global.paper_count, 10, "new run resets paper")
	check(global.current_ink, 1000.0, "new run resets ink")
	check(global.current_wave, 1, "new run resets wave")
	return true

func test_enemy_scenes() -> bool:
	for wave in range(2, 6):
		await logic.transition_to_next_wave()
	for enemy in logic.all_pieces:
		if enemy.team != 2:
			continue
		var kind: String = enemy.scene_file_path.get_file().get_basename()
		if kind not in ["Knight", "Bishop", "Rook", "Queen"]:
			continue
		check(kind in enemy.name, true, "%s spawns with its AI identity" % kind)
		check(enemy.has_node("Sprite2D"), true, "%s owns its intended sprite" % kind)
		if enemy.has_node("Sprite2D"):
			check(enemy.get_node("Sprite2D").hframes, 4, "%s has four facing frames" % kind)
		check(enemy.get_node("anim_sprite").visible, false, "%s hides inherited pawn art" % kind)
	return true

func test_wind_double_attack() -> bool:
	var ally = logic.all_pieces[0]
	var enemy = logic.all_pieces[9]
	ally.grid_pos = Vector2i(0, 5)
	enemy.grid_pos = Vector2i(0, 4)
	ally.is_grabbed = true
	ally.grabbed_by = enemy
	enemy.is_grabbed = true
	enemy.grabbed_by = ally
	enemy.current_health = 200
	logic.execute_new_wind_spell([ally.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(enemy.current_health, 180, "wind gives two actual melee hits next turn")
	check(ally.active_buffs.has("double_attack"), false, "double attack expires after its one turn")
	await logic._on_end_turn_pressed()
	check(enemy.current_health, 170, "following turn returns to one hit")
	return true

func isolate_enemy(kind: String, pos: Vector2i):
	logic.force_release_all_grabs()
	logic._clear_wave_effects()
	for p in logic.all_pieces.duplicate():
		if "King" not in p.name:
			logic.kill_piece(p)
	var king = logic.find_my_king(1)
	king.current_health = king.max_health
	king.grid_pos = Vector2i(3, 7)
	king.global_position = logic.grid_to_pixel(king.grid_pos)
	king.attacks_used_this_turn = 0
	var enemy = load("res://%s.tscn" % kind).instantiate()
	enemy.team = 2
	enemy.name = kind + "_test_" + str(logic.current_turn)
	logic.piece_layer.add_child(enemy)
	logic.all_pieces.append(enemy)
	enemy.grid_pos = pos
	enemy.global_position = logic.grid_to_pixel(pos)
	return enemy

func test_wind_special_attacks() -> bool:
	var king = logic.find_my_king(1)
	var queen = isolate_enemy("Queen", Vector2i(3, 3))
	logic.execute_new_wind_spell([queen.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 350, "wind grants Queen two separate ranged shots")
	check(queen.current_ammo, 1, "both Queen shots spend ammunition")
	check(queen.grid_pos, Vector2i(3, 3), "extra Queen shot does not add movement")
	check(queen.active_buffs.has("double_attack"), false, "enemy wind buff expires")
	var knight = isolate_enemy("Knight", Vector2i(5, 6))
	logic.execute_new_wind_spell([knight.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 340, "wind grants Knight two strikes")
	check(knight.grid_pos, Vector2i(7, 4), "Knight retreats once after its strikes")
	var bishop = isolate_enemy("Bishop", Vector2i(1, 5))
	logic.execute_new_wind_spell([bishop.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 330, "Bishop gets exactly two shots across both action phases")
	check(bishop.grid_pos, Vector2i(1, 5), "Bishop does not move after firing")
	var rook = isolate_enemy("Rook", Vector2i(3, 4))
	rook.is_charging = true
	logic.execute_new_wind_spell([rook.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 330, "wind grants Rook two volleys including blocked push damage")
	check(rook.grid_pos, Vector2i(3, 3), "Rook recoils once after both volleys")
	check(rook.is_charging, false, "Rook spends its charged attack normally")
	# Baseline control: no duplicate Bishop attack from movement and combat phases.
	bishop = isolate_enemy("Bishop", Vector2i(1, 5))
	await logic._on_end_turn_pressed()
	check(king.current_health, 365, "unbuffed Bishop gets one shot per turn")
	# A Queen melee attack includes its whole cleave on each strike.
	queen = isolate_enemy("Queen", Vector2i(3, 6))
	queen.is_grabbed = true
	queen.grabbed_by = king
	king.is_grabbed = true
	king.grabbed_by = queen
	var side_unit = load("res://Pawn.tscn").instantiate()
	side_unit.team = 1
	logic.piece_layer.add_child(side_unit)
	logic.all_pieces.append(side_unit)
	side_unit.grid_pos = Vector2i(4, 7)
	side_unit.global_position = logic.grid_to_pixel(side_unit.grid_pos)
	logic.execute_new_wind_spell([queen.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 330, "wind grants Queen two melee cleaves")
	check(side_unit.current_health, 430, "each Queen cleave also hits its side target")
	bishop = isolate_enemy("Bishop", Vector2i(0, 0))
	logic.execute_new_wind_spell([bishop.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(bishop.grid_pos, Vector2i(1, 1), "out-of-range Bishop moves once across both action phases")
	check(king.current_health, 400, "wind does not grant out-of-range Bishop damage")
	return true

func test_wind_restrictions() -> bool:
	var king = logic.find_my_king(1)
	var queen = isolate_enemy("Queen", Vector2i(3, 3))
	queen.current_ammo = 1
	logic.execute_new_wind_spell([queen.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 375, "wind cannot fire a second shot without ammunition")
	check(queen.current_ammo, 0, "wind never creates negative ammunition")
	check(queen.is_reloading, true, "empty Queen begins normal reload")
	var enemy = isolate_enemy("enemy_pawn", Vector2i(3, 6))
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	enemy.add_buff("stun", 0, 1)
	await logic._on_end_turn_pressed()
	check(king.current_health, 400, "stun blocks both wind attacks")
	check(enemy.active_buffs.has("double_attack"), false, "wind duration expires even when stunned")
	enemy = isolate_enemy("enemy_pawn", Vector2i(3, 6))
	logic.add_tile_effect(enemy.grid_pos, "fog_tile", 2)
	enemy.root_turns = 1 # Keep this target in its fog tile during the action phase.
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 400, "fog blocks wind attacks")
	var rook = isolate_enemy("Rook", Vector2i(3, 4))
	logic.execute_new_wind_spell([rook.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 400, "wind cannot bypass Rook charging turn")
	check(rook.active_buffs.has("double_attack"), false, "charging does not preserve a one-turn wind buff")
	await logic._on_end_turn_pressed()
	check(king.current_health, 365, "Rook later fires only its normal one volley")
	enemy = isolate_enemy("enemy_pawn", Vector2i(3, 6))
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 380, "reapplying wind refreshes instead of stacking extra attacks")
	# Each hit rounds independently: two 2.5-damage hits round to 3 + 3.
	enemy = isolate_enemy("enemy_pawn", Vector2i(3, 6))
	king.add_buff("damage_reduction", 0.75, 1)
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 394, "double attack makes two shielded hits instead of multiplying damage")
	enemy = isolate_enemy("enemy_pawn", Vector2i(3, 6))
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	enemy.root_turns = 1
	await logic._on_end_turn_pressed()
	check(king.current_health, 380, "root blocks movement but still permits two melee attacks")
	enemy = isolate_enemy("enemy_pawn", Vector2i(7, 0))
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(enemy.grid_pos, Vector2i(6, 1), "out-of-range wind target moves just once")
	check(enemy.active_buffs.has("double_attack"), false, "unused wind buff still expires that turn")
	enemy = isolate_enemy("enemy_pawn", Vector2i(3, 6))
	prepare_spell("D", "7", 3)
	magic._on_end_turn_button_pressed()
	check(global.has_casted_spell, true, "wind works through normal spell UI")
	logic._on_end_turn_pressed()
	logic._on_end_turn_pressed()
	await create_timer(0.7).timeout
	check(king.current_health, 380, "double End Turn click cannot duplicate the wind attack burst")
	check(enemy.active_buffs.has("double_attack"), false, "wind expires through normal UI turn flow")
	return true

func test_wind_safety() -> bool:
	var ally = logic.all_pieces[0]
	var enemy = logic.all_pieces[9]
	ally.grid_pos = Vector2i(0, 5)
	enemy.grid_pos = Vector2i(0, 4)
	ally.is_grabbed = true
	ally.grabbed_by = enemy
	enemy.is_grabbed = true
	enemy.grabbed_by = ally
	enemy.current_health = 5
	logic.execute_new_wind_spell([ally.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(logic.get_piece_at(Vector2i(0, 4)), null, "first-hit kill does not attack a freed target")
	check(ally.grabbed_by, null, "first-hit kill releases the melee link")
	check(ally.active_buffs.has("double_attack"), false, "first-hit kill still expires wind")
	logic.execute_new_wind_spell([ally.grid_pos], [Vector2i.RIGHT])
	check(ally.active_buffs.has("double_attack"), false, "directional wind retains push/stun instead of granting double attack")
	check(ally.stun_turns, 1, "directional wind still applies its existing stun")
	await logic._on_end_turn_pressed()
	var queen = isolate_enemy("Queen", Vector2i(3, 3))
	var king = logic.find_my_king(1)
	king.current_health = 25
	logic.execute_new_wind_spell([queen.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(logic.game_finished, true, "first-shot king death ends the turn")
	check(queen.current_ammo, 2, "no second wind shot after game over")
	return true

func test_five_waves() -> bool:
	var enemy_counts: Array[int] = [4, 8, 4, 6, 10]
	for wave in range(1, 6):
		check(global.current_wave, wave, "wave %d reached" % wave)
		check(logic.count_enemies_alive(), enemy_counts[wave - 1], "wave %d enemy roster" % wave)
		for turn in range(6):
			if logic.game_finished:
				break
			await logic._on_end_turn_pressed()
		check(logic.game_finished, false, "wave %d six-turn smoke survives" % wave)
		# Exercise the actual clear/advance path without claiming a balance playthrough.
		for p in logic.all_pieces.duplicate():
			if is_instance_valid(p) and p.team == 2:
				logic.deal_damage(p, 10000)
		await logic._on_end_turn_pressed()
		if wave < 5:
			check(logic.current_turn, 1, "wave %d starts on turn one" % (wave + 1))
	check(logic.game_finished, true, "clearing wave five ends campaign")
	check(logic.win_screen.visible, true, "final clear displays victory")
	check(paused, true, "victory keeps game paused")
	var final_turn: int = logic.current_turn
	logic._on_end_turn_pressed()
	check(logic.current_turn, final_turn, "no extra turn after victory")
	return true
