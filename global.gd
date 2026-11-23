extends Node
signal resources_changed
@warning_ignore("unused_signal")
signal tutorial_pawn_moved
@warning_ignore("unused_signal")
signal tutorial_attack_performed
@warning_ignore("unused_signal")
signal tutorial_scroll_opened
@warning_ignore("unused_signal")
signal tutorial_rune_ignis_drawn
@warning_ignore("unused_signal")
signal tutorial_rune_B_drawn
@warning_ignore("unused_signal")
signal tutorial_rune_2_drawn
@warning_ignore("unused_signal")
signal tutorial_rune_2_right_drawn
@warning_ignore("unused_signal")
signal tutorial_rune_D_drawn
@warning_ignore("unused_signal")
signal tutorial_spell_cast
@warning_ignore("unused_signal")
signal tutorial_end_turn_pressed
var is_tutorial_done: bool = false
const STARTING_PAPER: int = 10
const MAX_INK: float = 1000.0
var current_wave = 1
var paper_count: int = STARTING_PAPER
var has_casted_spell: bool = false
var current_ink: float = MAX_INK

func convert_to_grid(pair: Array) -> Vector2i:
	if pair.size() < 2:
		return Vector2i(-1, -1)
	var val1 = str(pair[0]).to_upper()
	var val2 = str(pair[1]).to_upper()

	var grid_x = -1
	var grid_y = -1
	var col_map = {"A": 0, "B": 1, "C": 2, "D": 3, "E": 4, "F": 5, "G": 6, "H": 7}
	var row_map = {"1": 0, "2": 1, "3": 2, "4": 3, "5": 4, "6": 5, "7": 6, "8": 7}
	if col_map.has(val1) and row_map.has(val2):
		grid_x = col_map[val1]
		grid_y = row_map[val2]
	elif row_map.has(val1) and col_map.has(val2):
		grid_y = row_map[val1]
		grid_x = col_map[val2]
	else:
		print("[LỖI] Tọa độ không hợp lệ: ", pair)

	return Vector2i(grid_x, grid_y)
func add_paper(amount: int) -> void:
	paper_count = maxi(0, paper_count + amount)
	_notify_resources_changed()

var max_ink: float = MAX_INK
func add_ink(amount: float) -> void:
	current_ink = clampf(current_ink + amount, 0.0, max_ink)
	_notify_resources_changed()

func _notify_resources_changed() -> void:
	resources_changed.emit()
func get_resources() -> Dictionary:
	return {"paper": paper_count, "ink": current_ink}

func restore_resources(resources: Dictionary) -> void:
	paper_count = maxi(0, int(resources.get("paper", STARTING_PAPER)))
	current_ink = clampf(float(resources.get("ink", MAX_INK)), 0.0, max_ink)
	has_casted_spell = false
	_notify_resources_changed()

func reset_run() -> void:
	current_wave = 1
	is_continuing = false
	saved_pieces.clear()
	saved_resources.clear()
	restore_resources({})
func calculate_world_position(grid_pos: Vector2i) -> Vector2:
	var tile_size = 120
	var board_offset_x = 450
	var board_offset_y = 150
	var pixel_x = (grid_pos.x * tile_size) + board_offset_x + (tile_size / 2.0)
	var pixel_y = (grid_pos.y * tile_size) + board_offset_y + (tile_size / 2.0)
	return Vector2(pixel_x, pixel_y)


var is_continuing = false
var saved_pieces = []
var saved_resources: Dictionary = {}
# Tests override only the destination; the normal player save path is unchanged.
var save_path: String = "user://soujourn_save.dat"

func save_game(pieces_backup: Array) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write checkpoint: %s" % FileAccess.get_open_error())
		return
	file.store_var(current_wave)
	file.store_var(pieces_backup)
	file.store_var(get_resources())
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var wave = file.get_var()
	var pieces = file.get_var()
	if not wave is int or wave < 1 or wave > 5 or not pieces is Array or pieces.is_empty():
		return false
	var resources: Dictionary = {}
	# Old checkpoints contain only the first two values.
	if file.get_position() < file.get_length():
		var stored_resources = file.get_var()
		if stored_resources is Dictionary:
			resources = stored_resources
	current_wave = wave
	saved_pieces = pieces
	saved_resources = resources
	is_continuing = true
	return true
