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
	for test_name in ["test_spell_catalog", "test_spell_ui_commands", "test_terrain_definition", "test_resolver_events", "test_definition_data", "test_resources", "test_input_costs", "test_cast_validation", "test_damage", "test_status_turn", "test_tile_lifetime", "test_turn_lock", "test_wave_health", "test_checkpoint", "test_enemy_scenes", "test_wind_double_attack", "test_wind_special_attacks", "test_wind_restrictions", "test_wind_safety", "test_five_waves", "test_balance_rules", "test_fog_rules", "test_queen_reload", "test_finite_resources"]:
		var filter: String = OS.get_environment("AUTOCHESSTO_TEST_FILTER")
		if not filter.is_empty() and filter != test_name:
			continue
		await fresh_board()
		if test_name.begins_with("test_wind_"):
			copy_spell_catalog().get_by_id(&"wind").duration = 1
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

func copy_spell_catalog() -> SpellCatalog:
	var catalog: SpellCatalog = logic.spell_resolver.catalog.duplicate(true)
	for i in range(catalog.definitions.size()):
		catalog.definitions[i] = catalog.definitions[i].duplicate(true)
	logic.spell_resolver.catalog = catalog
	logic.tile_effects.catalog = catalog
	board.get_node("UI_Layer").spell_catalog = catalog
	return catalog

func test_spell_catalog() -> bool:
	var catalog: SpellCatalog = logic.spell_resolver.catalog
	check(catalog.definitions.size(), 14, "catalog contains all fourteen spell combinations")
	check(catalog.get_by_elements([3, 0]).id, &"fire_wind", "combination lookup is independent of input order")
	for definition: SpellDefinition in catalog.definitions:
		global.restore_resources({})
		logic._clear_wave_effects()
		var result: Dictionary = logic.spell_resolver.request_cast(Array(definition.elements), ["D", "4"], [])
		check(result.ok, true, "spell command resolves %s through real gameplay" % definition.id)
		await process_frame
	logic._clear_wave_effects()
	global.restore_resources({})
	catalog = copy_spell_catalog()
	var fire: SpellDefinition = catalog.get_by_id(&"fire")
	fire.power = 47.0
	fire.paper_cost = 2
	catalog.ink_cost_per_character = 3.0
	var enemy = logic.get_piece_at(Vector2i(1, 1))
	var health: int = enemy.current_health
	var result: Dictionary = logic.spell_resolver.request_cast([0], ["B", "2"], [])
	check(enemy.current_health, health - 47, "spell definition power drives actual damage")
	check(global.paper_count, 8, "spell definition controls payment in resolver")
	check(result.coordinates, ["B", "2"], "cast result retains exact coordinate payload")
	var book = board.get_node("UI_Layer")
	book.current_page = 2
	book.update_page_ui()
	check(book.info_label.text, fire.describe(), "spellbook uses the same edited spell definition")
	global.has_casted_spell = false
	global.current_ink = 100.0
	check(logic.spell_resolver.pay_for_edit("", "ignis"), true, "resolver accepts paid text edit")
	check(global.current_ink, 100.0, "editing does not spend ink")
	global.has_casted_spell = false
	var invalid: Dictionary = logic.spell_resolver.request_cast([99], ["A", "8"], [])
	check(invalid.ok, false, "resolver rejects invalid elements directly")
	check(global.paper_count, 8, "invalid model request spends no paper")
	return true

func test_spell_ui_commands() -> bool:
	var requests: Array = []
	magic.cast_requested.disconnect(logic.request_cast)
	magic.cast_requested.connect(func(elements: Array, coordinates: Array, directions: Array): requests.append([elements.duplicate(), coordinates.duplicate(), directions.duplicate()]))
	prepare_spell()
	magic._on_end_turn_button_pressed()
	check(requests.size(), 1, "spell UI emits a command")
	check(requests[0][1], ["A", "8"], "spell UI preserves coordinates in command")
	check(global.paper_count, 10, "disconnected UI cannot debit gameplay resources")
	check(global.has_casted_spell, false, "UI alone cannot consume turn casting allowance")
	magic.cast_requested.connect(logic.request_cast)
	magic._on_end_turn_button_pressed()
	check(global.paper_count, 9, "connected resolver commits exactly one cast")
	check(magic.cast_elements.is_empty(), true, "accepted cast result clears UI draft")
	return true

func test_terrain_definition() -> bool:
	var catalog: SpellCatalog = copy_spell_catalog()
	var water: SpellDefinition = catalog.get_by_id(&"water_water")
	water.duration = 4
	water.settings.tick_heal = 7.0
	water.settings.tick_ink = 13.0
	var unit = logic.all_pieces[0]
	unit.current_health = 100
	global.current_ink = 200.0
	logic.execute_new_water_water_spell([unit.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(unit.current_health, 127, "terrain definition drives periodic healing")
	check(global.current_ink, 213.0, "terrain definition drives periodic ink reward")
	check(logic.active_tile_effects[unit.grid_pos].turns, 3, "spell definition controls terrain lifetime")
	check(logic.tile_effects.active_effects.size(), 1, "terrain module owns effect state")
	return true

func test_resolver_events() -> bool:
	var damage_results: Array = []
	var turns: Array = []
	logic.combat_event.connect(func(result: Dictionary): damage_results.append(result))
	logic.turn_resolved.connect(func(result: Dictionary): turns.append(result))
	var unit = logic.all_pieces[0]
	unit.current_health = 200
	unit.add_buff("damage_reduction", 0.5, 1)
	logic.combat_resolver.deal_damage(unit, 40)
	check(damage_results.size(), 1, "combat module emits one damage result")
	check(damage_results[0].amount, 20.0, "damage result reports actual shielded damage")
	check(damage_results[0].remaining_health, 180.0, "damage result reports resulting health")
	# Presentation can be disconnected without changing resolution.
	logic.combat_resolver.attack_animation_requested.disconnect(logic.presentation.attack)
	logic.combat_resolver.projectile_requested.disconnect(logic.presentation.projectile)
	var result: Dictionary = await logic.turn_resolver.resolve_turn()
	check(result.accepted, true, "turn module accepts a normal turn")
	check(turns.size(), 1, "turn module publishes one completed result")
	check(result.turn, logic.current_turn, "turn result matches board state without presentation")
	return true

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
	check(other.definition.melee_damage, 18.0, "runtime copy does not mutate shared balance data")
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
	check(global.current_ink, 1000.0, "typing does not spend ink")
	global.add_ink(-50.0)
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
	check(global.current_ink, 1000.0, "submitting runes does not spend ink")
	check(magic.cast_elements.size(), 2, "two runes are registered once")
	magic._on_element_submitted("ignis", 1)
	check(magic.cast_elements.size(), 2, "hidden rune cannot be submitted twice")
	magic.clear_all_inputs()
	input_text(magic.coord_edits[0], "A")
	input_text(magic.coord_edits[0], "B")
	check(global.current_ink, 1000.0, "replacing text is free")
	input_text(magic.coord_edits[0], "")
	check(global.current_ink, 1000.0, "deleting neither costs nor refunds ink")
	global.current_ink = 10.0
	input_text(magic.coord_edits[0], "A")
	check(magic.coord_edits[0].text, "A", "editing is allowed even with low ink")
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
	global.current_ink = 100.0 # Payment occurs on successful cast.
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
	check(pawn.current_health, start_hp - 6, "shield stays active through enemy combat")
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
	check(global.current_ink, 400.0, "healing tile does not generate ink")
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
	check(pawn.current_health, 160, "survivor heals 60 between waves")
	check(pawn.damage_reduction_rate, 0.0, "temporary shield resets between waves")
	var replacement = logic.get_piece_at(Vector2i(7, 6))
	check(replacement.current_health, 120, "replacement uses configured 120 HP")
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
	check(enemy.current_health, 164, "wind gives two actual melee hits next turn")
	check(ally.active_buffs.has("double_attack"), false, "double attack expires after its one turn")
	await logic._on_end_turn_pressed()
	check(enemy.current_health, 146, "following turn returns to one hit")
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
	check(king.current_health, 352, "wind grants Queen two separate ranged shots")
	check(queen.current_ammo, 1, "both Queen shots spend ammunition")
	check(queen.grid_pos, Vector2i(3, 3), "extra Queen shot does not add movement")
	check(queen.active_buffs.has("double_attack"), false, "enemy wind buff expires")
	var knight = isolate_enemy("Knight", Vector2i(5, 6))
	logic.execute_new_wind_spell([knight.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 344, "wind grants Knight two strikes")
	check(knight.grid_pos, Vector2i(7, 4), "Knight retreats once after its strikes")
	var bishop = isolate_enemy("Bishop", Vector2i(1, 5))
	logic.execute_new_wind_spell([bishop.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 344, "Bishop gets exactly two shots across both action phases")
	check(bishop.grid_pos, Vector2i(1, 5), "Bishop does not move after firing")
	var rook = isolate_enemy("Rook", Vector2i(3, 4))
	rook.is_charging = true
	logic.execute_new_wind_spell([rook.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 332, "wind grants Rook two volleys including blocked push damage")
	check(rook.grid_pos, Vector2i(3, 3), "Rook recoils once after both volleys")
	check(rook.is_charging, false, "Rook spends its charged attack normally")
	# Baseline control: no duplicate Bishop attack from movement and combat phases.
	bishop = isolate_enemy("Bishop", Vector2i(1, 5))
	await logic._on_end_turn_pressed()
	check(king.current_health, 372, "unbuffed Bishop gets one shot per turn")
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
	check(king.current_health, 340, "wind grants Queen two melee cleaves")
	check(side_unit.current_health, 120, "each Queen cleave also hits its side target")
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
	check(king.current_health, 376, "wind cannot fire a second shot without ammunition")
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
	check(king.current_health, 366, "Rook later fires only its normal one volley")
	enemy = isolate_enemy("enemy_pawn", Vector2i(3, 6))
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	logic.execute_new_wind_spell([enemy.grid_pos], [])
	await logic._on_end_turn_pressed()
	check(king.current_health, 376, "reapplying wind refreshes instead of stacking extra attacks")
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
	check(king.current_health, 376, "root blocks movement but still permits two melee attacks")
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
	check(king.current_health, 376, "double End Turn click cannot duplicate the wind attack burst")
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
	king.current_health = 24
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

func test_balance_rules() -> bool:
	check(logic.count_enemies_alive(), 4, "wave one retains four enemies")
	check(logic.all_pieces[0].max_health, 180, "allied soldier maximum is balanced")
	check(logic.all_pieces[9].max_health, 150, "wave one soldier has wave-specific HP")
	await logic.transition_to_next_wave()
	check(logic.count_enemies_alive(), 8, "wave two retains eight enemies")
	check(logic.all_pieces[9].max_health, 105, "wave two soldier has its own HP")
	logic.restart_current_wave()
	check(logic.all_pieces[9].max_health, 105, "retry retains wave-specific stats")
	global.restore_resources({})
	var before: float = global.current_ink
	var cast: Dictionary = logic.spell_resolver.request_cast([0], ["A", "4"], [])
	check(cast.ok, true, "fire cast succeeds")
	check(before - global.current_ink, 70.0, "fire pays fixed price on cast")
	check(global.paper_count, 9, "fire pays one paper")
	global.has_casted_spell = false
	global.current_ink = 69
	var rejected: Dictionary = logic.spell_resolver.request_cast([0], ["A", "4"], [])
	check(rejected.ok, false, "cast rejects insufficient ink")
	check(global.paper_count, 9, "failed cast does not spend paper")
	global.current_ink = 1000
	rejected = logic.spell_resolver.request_cast([0], ["A", "4", "A", "4"], [])
	check(rejected.ok, false, "duplicate target rejected before payment")
	check(global.current_ink, 1000.0, "duplicate target spends no ink")
	var wind: SpellDefinition = logic.spell_resolver.catalog.get_by_id(&"wind")
	check(wind.duration, 2, "wind double attack lasts two turns")
	return true

func test_fog_rules() -> bool:
	var ally = logic.all_pieces[0]
	var enemy = logic.all_pieces[9]
	ally.grid_pos = Vector2i(0, 5)
	enemy.grid_pos = Vector2i(0, 4)
	ally.is_grabbed = true
	ally.grabbed_by = enemy
	enemy.is_grabbed = true
	enemy.grabbed_by = ally
	logic.add_tile_effect(ally.grid_pos, "fog_tile", 2)
	var ally_hp: int = ally.current_health
	var enemy_hp: int = enemy.current_health
	await logic._on_end_turn_pressed()
	check(ally.current_health, ally_hp, "fog prevents melee targeting")
	check(enemy.current_health, enemy_hp, "fog occupant cannot attack")
	logic.deal_damage(ally, 5)
	check(ally.current_health, ally_hp - 5, "fog permits spell and terrain damage")
	return true

func test_queen_reload() -> bool:
	var queen = isolate_enemy("Queen", Vector2i(3, 3))
	var king = logic.find_my_king(1)
	var damage: Array[int] = []
	for turn in range(6):
		var before: int = king.current_health
		await logic._on_end_turn_pressed()
		damage.append(before - king.current_health)
	check(damage, [24, 24, 24, 0, 0, 24], "Queen waits two full turns before firing again")
	return true

func test_finite_resources() -> bool:
	for id in [&"water", &"earth", &"earth_earth", &"fire_water", &"fire_earth", &"water_earth"]:
		var definition: SpellDefinition = logic.spell_resolver.catalog.get_by_id(id)
		check(definition.paper_reward, 0, "%s does not create paper" % id)
		check(definition.ink_reward, 0.0, "%s does not create ink" % id)
	for id in [&"water_water", &"water_earth", &"water_wind"]:
		check(logic.spell_resolver.catalog.get_by_id(id).param("tick_ink", 0), 0.0, "%s terrain does not create ink" % id)
	var wall: SpellDefinition = logic.spell_resolver.catalog.get_by_id(&"wind_earth")
	check(wall.param("paper_per_adjacent", -1), 0, "walls do not generate paper")
	global.current_ink = 500
	global.paper_count = 4
	for unit in logic.all_pieces.duplicate():
		if unit.team == 2: logic.kill_piece(unit)
	await logic._on_end_turn_pressed()
	check(global.current_wave, 2, "clearing wave advances")
	check(global.paper_count, 7, "wave clear awards three paper once")
	check(global.current_ink, 750.0, "wave clear awards 250 ink once")
	logic.restart_current_wave()
	check(global.paper_count, 7, "retry cannot duplicate wave reward")
	check(global.current_ink, 750.0, "retry restores awarded ink checkpoint")
	return true
