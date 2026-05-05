extends Node
var current_wave = 0
var paper_count: int = 10
var has_casted_spell: bool = false
var magic_system: Node = null

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

func add_ink(amount: float):
	# Kiểm tra xem magic_system (Scene Drawing của bạn) đã được đăng ký chưa
	if magic_system:
		# Gọi trực tiếp hàm xử lý mực bên trong Scene đó
		if magic_system.has_method("add_ink_to_system"):
			magic_system.add_ink_to_system(amount)
		else:
			# Nếu bên Scene Drawing chưa có hàm, ta cộng trực tiếp vào biến bên đó
			magic_system.current_ink += amount
			print("[Global] Đã cộng mực trực tiếp vào Scene Drawing: ", magic_system.current_ink)
	else:
		print("[LỖI] Magic Drawing System chưa được đăng ký vào Global!")
