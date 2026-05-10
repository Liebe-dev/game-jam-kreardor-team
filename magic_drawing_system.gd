extends CanvasLayer

signal scroll_closed
signal spell_casted(elements, coordinates, directions_list)

@onready var ink_bar = %InkBar
@onready var paper_label = %PaperLabel
@onready var spell_scroll = %SpellScroll

# KẾT NỐI UI LỚP 1 (Nguyên Tố)
@onready var elem_edits = [%ElemEdit1, %ElemEdit2]
@onready var elem_icons = [%ElemIcon1, %ElemIcon2]

# KẾT NỐI UI LỚP 2 (Tọa độ) - [Trên, Trái, Dưới, Phải]
@onready var coord_edits = [%CoordTop, %CoordLeft, %CoordBottom, %CoordRight]
@onready var coord_icons = [%IconTop, %IconLeft, %IconBot, %IconRight]

# KẾT NỐI UI LỚP 3 (Hướng)
@onready var dir_edits = [%Dir1, %Dir2, %Dir3, %Dir4, %Dir5, %Dir6, %Dir7, %Dir8]
@onready var dir_icons = [%IconDir1, %IconDir2, %IconDir3, %IconDir4, %IconDir5, %IconDir6, %IconDir7, %IconDir8]

# KHU VỰC KÉO THẢ HÌNH ẢNH
@export_group("Hình ảnh Ấn Chú")
@export var icon_fire: Texture2D
@export var icon_water: Texture2D
@export var icon_earth: Texture2D
@export var icon_wind: Texture2D
@export var icon_success_text: Texture2D 
@export var icon_direction: Texture2D
@export var icon_fire_fire: Texture2D
@export var icon_water_water: Texture2D
@export var icon_earth_earth: Texture2D
@export var icon_wind_wind: Texture2D
@export var icon_fire_water: Texture2D
@export var icon_fire_earth: Texture2D
@export var icon_fire_wind: Texture2D
@export var icon_water_earth: Texture2D
@export var icon_water_wind: Texture2D
@export var icon_earth_wind: Texture2D
# Tài nguyên
var max_ink : float = 1000.0
var current_ink : float = 1000.0
var ink_cost_per_char : float = 5.0
var max_scroll_width: float = 0.0

# Dữ liệu thi triển
var cast_elements = []
var cast_directions = []
var cast_elements_str = []
# Từ điển Nguyên tố
var dict_elements = {
	"ignis": "fire", "fire": "fire",
	"aqua": "water", "water": "water",
	"terra": "earth", "earth": "earth",
	"ventus": "wind", "wind": "wind"
}

# Bản đồ liên kết Vị trí ô Hướng với Vector Thực tế
var index_to_direction = {
	0: Vector2(0, -1),   # Lên
	1: Vector2(1, -1),   # Lên Phải
	2: Vector2(1, 0),    # Phải
	3: Vector2(1, 1),    # Xuống Phải
	4: Vector2(0, 1),    # Xuống
	5: Vector2(-1, 1),   # Xuống Trái
	6: Vector2(-1, 0),   # Trái
	7: Vector2(-1, -1)   # Lên Trái
}

func _ready(): # Đã sửa lỗi khoảng trắng ở đây
	Global.magic_system = self
	max_scroll_width = %UI_Container.size.x
	
	# Đảm bảo cuộn bắt đầu trắng tinh
	clear_all_inputs() 
	update_ui()
	
	# 1. Cài đặt theo dõi phím gõ cho TẤT CẢ các ô (Để trừ mực)
	var all_edits = elem_edits + coord_edits + dir_edits
	for edit_node in all_edits:
		edit_node.set_meta("prev_len", 0)
		edit_node.text_changed.connect(_on_any_text_changed.bind(edit_node))
		
	# 2. Cài đặt nhấn phím Enter (Gửi dữ liệu)
	for i in range(elem_edits.size()):
		elem_edits[i].text_submitted.connect(_on_element_submitted.bind(i))
	for i in range(coord_edits.size()):
		coord_edits[i].text_submitted.connect(_on_coord_submitted.bind(i))
	for i in range(dir_edits.size()):
		dir_edits[i].text_submitted.connect(_on_dir_submitted.bind(i))

# --- XỬ LÝ LỚP 1 (NGUYÊN TỐ) ---
func _on_element_submitted(new_text: String, index: int):
	var text_lower = new_text.to_lower().strip_edges()
	
	if dict_elements.has(text_lower):
		var elem_str = dict_elements[text_lower] # Trả về "fire", "water"...
		
		# 1. Lưu vào logic game
		match elem_str:
			"fire": cast_elements.append(SpellDictionary.Element.FIRE)
			"water": cast_elements.append(SpellDictionary.Element.WATER)
			"earth": cast_elements.append(SpellDictionary.Element.EARTH)
			"wind": cast_elements.append(SpellDictionary.Element.WIND)
			
		# 2. Lưu vào mảng phục vụ UI
		cast_elements_str.append(elem_str)
		
		# 3. Ẩn ô nhập chữ đi
		elem_edits[index].hide()
		
		# 4. XỬ LÝ HÌNH ẢNH
		if cast_elements_str.size() == 1:
			# Lần 1: Hiện ảnh nguyên tố đơn lẻ ở vị trí Icon 1 (Chính giữa)
			elem_icons[0].texture = get_single_icon(elem_str)
			elem_icons[0].show()
			
		elif cast_elements_str.size() == 2:
			# Lần 2: Đổi ảnh ở Icon 1 thành ảnh KẾT HỢP
			elem_icons[0].texture = get_combined_icon(cast_elements_str[0], cast_elements_str[1])
			elem_icons[1].hide() # Đảm bảo Icon 2 không hiện ra vì đã gộp vào Icon 1 rồi
			
	else:
		elem_edits[index].text = "" # Gõ sai thì xóa chữ
# --- XỬ LÝ LỚP 2 (TỌA ĐỘ) ---
# --- XỬ LÝ LỚP 2 (TỌA ĐỘ) ---
func _on_coord_submitted(new_text: String, index: int):
	var text_upper = new_text.to_upper().strip_edges()
	var is_valid = false
	
	if (index == 0 or index == 2) and text_upper.length() == 1 and "ABCDEFGH".contains(text_upper):
		is_valid = true # Tọa độ Top/Bot nhận Chữ
	elif (index == 1 or index == 3) and text_upper.length() == 1 and "12345678".contains(text_upper):
		is_valid = true # Tọa độ Left/Right nhận Số
		
	if is_valid:
		# Tọa độ ĐÚNG: Để nguyên chữ, KHÔNG ẩn ô nhập, KHÔNG hiện ảnh
		coord_edits[index].text = text_upper # Ép thành chữ in hoa cho đẹp
		coord_edits[index].release_focus()   # Nhả con trỏ chuột ra khỏi ô để người chơi không lỡ gõ thêm
	else:
		# Tọa độ SAI: Xóa chữ bắt gõ lại
		coord_edits[index].text = ""
# --- XỬ LÝ LỚP 3 (HƯỚNG) ---
func _on_dir_submitted(new_text: String, index: int):
	var text_lower = new_text.to_lower().strip_edges()
	if text_lower == "sagta":
		var final_dir = index_to_direction[index]
		cast_directions.append(final_dir)
		
		# 1. TỰ ĐẶT KÍCH THƯỚC CHO MŨI TÊN (Đổi số 80 thành độ to bạn muốn)
		var custom_size = Vector2(70, 70) # <--- BẠN CHỈNH SỐ NÀY ĐỂ PHÓNG TO THU NHỎ
		dir_icons[index].size = custom_size
		
		# 2. TỰ ĐỘNG CĂN VÀO CHÍNH GIỮA Ô CHỮ
		var center_of_edit = dir_edits[index].global_position + (dir_edits[index].size / 2.0)
		dir_icons[index].global_position = center_of_edit - (custom_size / 2.0)
		
		# 3. Cài lại tâm xoay vào chính giữa
		dir_icons[index].pivot_offset = custom_size / 2.0
		
		# 4. Gán ảnh và xoay
		dir_icons[index].texture = icon_direction
		dir_icons[index].rotation_degrees = index * 45.0
		
		# 5. Ẩn chữ, Hiện hình
		dir_edits[index].hide()
		dir_icons[index].show()
		
		print("Đã giải phóng ấn Sagitta tại ô số ", index, ", hướng bay: ", final_dir)
# --- THỰC THI PHÉP ---
func _on_end_turn_button_pressed():
	if cast_elements.is_empty(): 
		print("Cần ít nhất 1 nguyên tố!")
		return 
		
	var final_coords_text = [] # Chỉ sử dụng 1 biến này để lưu tọa độ
	
	# Thu thập Cặp 1 (Trên & Trái)
	if coord_edits[0].text != "" and coord_edits[1].text != "":
		final_coords_text.append(coord_edits[0].text.to_upper()) 
		final_coords_text.append(coord_edits[1].text)
		
	# Thu thập Cặp 2 (Dưới & Phải)
	if coord_edits[2].text != "" and coord_edits[3].text != "":
		final_coords_text.append(coord_edits[2].text.to_upper())
		final_coords_text.append(coord_edits[3].text)
		
	Global.paper_count -= 1 
	update_ui() 
	
	# Sửa lỗi in sai: In trực tiếp mảng final_coords_text
	print("Niệm: ", cast_elements, " | Tọa độ: ", final_coords_text, " | Hướng: ", cast_directions)
	
	Global.has_casted_spell = true
	spell_casted.emit(cast_elements, final_coords_text, cast_directions)
	
	# Gửi dữ liệu sạch sang Logic Bàn Cờ
	get_tree().call_group("logic_board", "cast_complex_spell", cast_elements.duplicate(), final_coords_text.duplicate(), cast_directions.duplicate())
	
	clear_all_inputs()
	close_scroll()
# --- TIỆN ÍCH ---
func update_ui():
	if paper_label: paper_label.text = "Giấy: " + str(Global.paper_count)
	if ink_bar: ink_bar.value = (current_ink / max_ink) * 100

func show_scroll():
	self.show()
	%UI_Container.size.x = max_scroll_width

func close_scroll():
	self.hide()
	scroll_closed.emit()

func _on_any_text_changed(new_text: String, edit_node: LineEdit):
	var current_len = new_text.length()
	var prev_len = edit_node.get_meta("prev_len")
	
	if current_len > prev_len:
		var chars_added = current_len - prev_len
		var ink_cost = (max_ink * 0.02) * chars_added 
		
		if current_ink >= ink_cost:
			current_ink -= ink_cost
		else:
			current_ink = 0
			edit_node.text = new_text.substr(0, prev_len) 
			edit_node.caret_column = prev_len 
			current_len = prev_len 
		update_ui()
		
	edit_node.set_meta("prev_len", current_len)

func clear_all_inputs():
	# Xóa dữ liệu ghi nhớ
	cast_elements.clear()
	cast_directions.clear()
	cast_elements_str.clear() # Rất quan trọng để ghép ấn không bị nhớ nhầm sang lượt sau
	
	var all_edits = elem_edits + coord_edits + dir_edits
	var all_icons = elem_icons + coord_icons + dir_icons
	
	# Xóa chữ và giấu ảnh trên giao diện
	for i in range(all_edits.size()):
		all_edits[i].text = ""
		all_edits[i].set_meta("prev_len", 0) # Reset lại biến đếm mực
		all_edits[i].show()
		all_icons[i].hide()
	for i in range(all_edits.size()):
		all_edits[i].text = ""
		all_edits[i].set_meta("prev_len", 0) 
		all_edits[i].show()
		all_icons[i].hide()
# --- HÀM TRẢ VỀ ẢNH ĐƠN ---
func get_single_icon(elem_str: String) -> Texture2D:
	match elem_str:
		"fire": return icon_fire
		"water": return icon_water
		"earth": return icon_earth
		"wind": return icon_wind
	return null

# --- HÀM TRẢ VỀ ẢNH KẾT HỢP ---
func get_combined_icon(e1: String, e2: String) -> Texture2D:
	var combo = [e1, e2]
	combo.sort() # Tự động xếp Alphabet (earth, fire, water, wind) để tra từ điển chuẩn xác
	var combo_str = combo[0] + "_" + combo[1]
	
	match combo_str:
		# Gõ 2 nguyên tố giống nhau
		"fire_fire": return icon_fire_fire
		"water_water": return icon_water_water
		"earth_earth": return icon_earth_earth
		"wind_wind": return icon_wind_wind
		
		# Gõ 2 nguyên tố khác nhau (do đã sort A-Z nên chỉ có các trường hợp sau)
		"earth_fire": return icon_fire_earth 
		"fire_water": return icon_fire_water 
		"fire_wind": return icon_fire_wind   
		"earth_water": return icon_water_earth 
		"earth_wind": return icon_earth_wind 
		"water_wind": return icon_water_wind 
		
	return null
func _on_undo_button_pressed():
	# 1. Xóa toàn bộ chữ, ẩn ảnh và reset các mảng dữ liệu (Hàm này bạn đã có sẵn)
	clear_all_inputs()
	
	# 2. Hoàn trả lại mực cho người chơi
	current_ink = max_ink # (Hoặc bạn có thể gán về mức mực ở đầu lượt nếu game có cơ chế lưu trữ mực qua nhiều lượt)
	update_ui()
	
	print("Đã xóa toàn bộ ấn chú trên giấy và hoàn trả mực!")
	
func _on_close_area_button_pressed():
	self.hide()
	scroll_closed.emit()
# Hàm dịch chữ cái và số thành tọa độ Vector2 cho Board dễ hiểu
