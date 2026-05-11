extends Node
var current_wave = 1
var paper_count: int = 10
var has_casted_spell: bool = false
var magic_system: Node = null
var current_ink : float = 1000.0

func convert_to_grid(pair: Array) -> Vector2i:
	if pair.size() < 2:
		return Vector2i(-1, -1) # Trả về tọa độ lỗi nếu mảng không đủ 2 phần tử

	# Ép kiểu về chuỗi in hoa để so sánh cho chắc chắn
	var val1 = str(pair[0]).to_upper()
	var val2 = str(pair[1]).to_upper()

	var grid_x = -1
	var grid_y = -1

	# Bản đồ quy đổi Cột (Ngang - X)
	var col_map = {"A": 0, "B": 1, "C": 2, "D": 3, "E": 4, "F": 5, "G": 6, "H": 7}
	
	# Bản đồ quy đổi Hàng (Dọc - Y)
	var row_map = {"1": 0, "2": 1, "3": 2, "4": 3, "5": 4, "6": 5, "7": 6, "8": 7}

	# Kiểm tra xem val1 là Cột hay Hàng để sắp xếp lại cho đúng
	if col_map.has(val1) and row_map.has(val2):
		grid_x = col_map[val1]
		grid_y = row_map[val2]
	elif row_map.has(val1) and col_map.has(val2):
		grid_y = row_map[val1]
		grid_x = col_map[val2]
	else:
		print("[LỖI] Tọa độ không hợp lệ: ", pair)

	return Vector2i(grid_x, grid_y)
# (Trong global.gd)
# Giả sử bạn đã có: var paper_count: int = 10

func add_paper(amount: int):
	paper_count += amount
	print("[Global] Đã nhận thêm ", amount, " giấy. Tổng cộng: ", paper_count)
	
	# Gọi lệnh cập nhật lên màn hình thông qua cái móc magic_system
	if magic_system and magic_system.has_method("update_paper_ui"):
		magic_system.update_paper_ui(paper_count)
# (Trong global.gd)

# Khai báo sẵn giới hạn (nếu bạn chưa có)
var max_ink: float = 1000.0

func add_ink(amount: float):
	# Dùng hàm clamp để nhốt current_ink trong khoảng từ 0 đến max_ink (2000)
	current_ink = clamp(current_ink + amount, 0.0, max_ink)
	
	print("[Global] Đã nhận mực. Mực hiện tại: ", current_ink)
	
	# CHÚ Ý QUAN TRỌNG: Cập nhật lại thanh UI để nó không bị lố
	# Giả sử bạn đã lưu tham chiếu magic_drawing_system vào biến magic_system
	if magic_system != null and magic_system.has_method("update_ui"):
		magic_system.update_ui()
func calculate_world_position(grid_pos: Vector2i) -> Vector2:
	# 1. TĂNG KÍCH THƯỚC Ô LÊN: 
	# Hãy thử số 115, 120 hoặc 128. (Bạn cứ sửa số này đến khi nào click Cột C nó nổ đúng cột C).
	var tile_size = 120 
	
	# 2. CHỈNH GÓC GỐC (Tâm của ô A1):
	# Nếu nổ bị lệch trái/phải toàn bàn cờ -> Chỉnh board_offset_x
	# Nếu nổ bị lệch lên/xuống toàn bàn cờ -> Chỉnh board_offset_y
	var board_offset_x = 450 
	var board_offset_y = 150 
	
	# Công thức giữ nguyên
	var pixel_x = (grid_pos.x * tile_size) + board_offset_x + (tile_size / 2.0)
	var pixel_y = (grid_pos.y * tile_size) + board_offset_y + (tile_size / 2.0)
	
	return Vector2(pixel_x, pixel_y)
