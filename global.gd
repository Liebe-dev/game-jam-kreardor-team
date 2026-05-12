extends Node
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
var current_wave = 1
var paper_count: int = 10
var has_casted_spell: bool = false
var magic_system: Node = null
var current_ink : float = 1000.0

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
func add_paper(amount: int):
	paper_count += amount
	print("[Global] Đã nhận thêm ", amount, " giấy. Tổng cộng: ", paper_count)
	if magic_system and magic_system.has_method("update_paper_ui"):
		magic_system.update_paper_ui(paper_count)
var max_ink: float = 1000.0
func add_ink(amount: float):
	current_ink = clamp(current_ink + amount, 0.0, max_ink)
	print("[Global] Đã nhận mực. Mực hiện tại: ", current_ink)
	if magic_system != null and magic_system.has_method("update_ui"):
		magic_system.update_ui()
func calculate_world_position(grid_pos: Vector2i) -> Vector2:
	var tile_size = 120 
	var board_offset_x = 450 
	var board_offset_y = 150 
	var pixel_x = (grid_pos.x * tile_size) + board_offset_x + (tile_size / 2.0)
	var pixel_y = (grid_pos.y * tile_size) + board_offset_y + (tile_size / 2.0)
	return Vector2(pixel_x, pixel_y)


var is_continuing = false
var saved_pieces = []

func save_game(pieces_backup: Array):
	var file = FileAccess.open("user://soujourn_save.dat", FileAccess.WRITE)
	file.store_var(current_wave) 
	file.store_var(pieces_backup) 

func load_game() -> bool:
	if FileAccess.file_exists("user://soujourn_save.dat"):
		var file = FileAccess.open("user://soujourn_save.dat", FileAccess.READ)
		current_wave = file.get_var()
		saved_pieces = file.get_var()
		is_continuing = true
		return true
	return false
