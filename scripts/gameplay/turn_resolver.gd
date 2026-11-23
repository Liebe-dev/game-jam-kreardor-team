class_name TurnResolver
extends Node
## A single entry point owns the order and lock of one resolved turn.

signal turn_resolved(result: Dictionary)
var board: Node

func resolve_turn() -> Dictionary:
	if board.is_resolving_turn or board.game_finished or board.get_tree().paused:
		return {"accepted": false, "reason": "busy_or_finished"}
	board.is_resolving_turn = true
	board.is_player_turn = false
	SoundManager.play_sound(SoundManager.sfx_end_turn)
	var turn_pieces: Array = board.all_pieces.duplicate()
	if not board.game_finished:
		board.move_team_logic(1)
		await board.get_tree().create_timer(0.3).timeout
	if not board.game_finished:
		board.move_team_logic(2)
		await board.get_tree().create_timer(0.2).timeout
	if not board.game_finished:
		for p in board.all_pieces.duplicate():
			if is_instance_valid(p) and not p.is_queued_for_deletion():
				board.check_and_execute_grab(p)
		board.execute_all_combat_logic()
	# One tile phase after actions; fog/shields remain active through combat.
	if not board.game_finished:
		board.process_all_tile_effects()
	for p in turn_pieces:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			if p.has_method("on_turn_end"):
				p.on_turn_end()
			if "has_moved" in p:
				p.has_moved = false
	board.has_moved_main_piece = false
	board.selected_piece = null
	board.clear_highlights()
	if not board.game_finished:
		board.current_turn += 1
		if board.turn_label:
			board.turn_label.text = "Turn: " + str(board.current_turn)
		Global.has_casted_spell = false
		board.get_node("%ClosedScrollButton").show()
		board.process_ammo_reloads()
		for p in board.all_pieces.duplicate():
			if is_instance_valid(p) and UnitDefinition.is_kind(p, UnitDefinition.Kind.EARTH_WALL):
				p.duration -= 1
				if p.duration <= 0:
					board.kill_piece(p)
		if board.count_enemies_alive() == 0:
			await board.check_and_trigger_next_wave()
	board.is_resolving_turn = false
	board.is_player_turn = not board.game_finished
	Global.tutorial_end_turn_pressed.emit()
	var result: Dictionary = {"accepted": true, "turn": board.current_turn, "wave": Global.current_wave, "finished": board.game_finished}
	turn_resolved.emit(result)
	return result
