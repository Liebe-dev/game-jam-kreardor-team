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

# ==========================================
# KHU VỰC KÉO THẢ HÌNH ẢNH (Kéo ảnh từ FileSystem vào Inspector bên phải)
# ==========================================
@export_group("Hình ảnh Ấn Chú")
@export var icon_fire: Texture2D
@export var icon_water: Texture2D
@export var icon_earth: Texture2D
@export var icon_wind: Texture2D
@export var icon_success_text: Texture2D # Hình ảnh chung khi gõ đúng Tọa độ/Hướng

# Tài nguyên
var max_ink : float = 1000.0
var current_ink : float = 1000.0
var ink_cost_per_char : float = 5.0
var max_scroll_width: float = 0.0

# Dữ liệu thi triển
var cast_elements = []
var cast_directions = []

# Từ điển
var dict_elements = {
	"ignis": "fire", "fire": "fire",
	"aqua": "water", "water": "water",
	"terra": "earth", "earth": "earth",
	"ventus": "wind", "wind": "wind"
}
# Bản đồ liên kết vị trí Ô chữ (từ 0 đến 7) với Hướng bắn
var index_to_direction = {
	0: Vector2(0, -1),   # %Dir1 (Ví dụ ô này nằm ở Hướng Lên)
	1: Vector2(1, -1),   # %Dir2 (Lên Phải)
	2: Vector2(1, 0),    # %Dir3 (Phải)
	3: Vector2(1, 1),    # %Dir4 (Xuống Phải)
	4: Vector2(0, 1),    # %Dir5 (Xuống)
	5: Vector2(-1, 1),   # %Dir6 (Xuống Trái)
	6: Vector2(-1, 0),   # %Dir7 (Trái)
	7: Vector2(-1, -1)   # %Dir8 (Lên Trái)
}
func _ready():
	Global.magic_system = self
	max_scroll_width = %UI_Container.size.x
	update_ui()
	
	# 1. Cài đặt theo dõi phím gõ cho TẤT CẢ các ô
	var all_edits = elem_edits + coord_edits + dir_edits
	for edit_node in all_edits:
		edit_node.set_meta("prev_len", 0)
		edit_node.text_changed.connect(_on_any_text_changed.bind(edit_node))
		
	# 2. Cài đặt nhấn phím Enter (Tách riêng ra để không bị lỗi đếm số)
	for i in range(elem_edits.size()):
		elem_edits[i].text_submitted.connect(_on_element_submitted.bind(i))
	for i in range(coord_edits.size()):
		coord_edits[i].text_submitted.connect(_on_coord_submitted.bind(i))
	for i in range(dir_edits.size()):
		dir_edits[i].text_submitted.connect(_on_dir_submitted.bind(i))
func _on_element_submitted(new_text: String, index: int):
	var text_lower = new_text.to_lower().strip_edges()
	
	if dict_elements.has(text_lower):
		var elem_type = dict_elements[text_lower]
		var final_icon = null
		
		# Lưu dữ liệu thật và gán hình ảnh tương ứng
		match elem_type:
			"fire": 
				cast_elements.append(SpellDictionary.Element.FIRE)
				final_icon = icon_fire
			"water": 
				cast_elements.append(SpellDictionary.Element.WATER)
				final_icon = icon_water
			"earth": 
				cast_elements.append(SpellDictionary.Element.EARTH)
				final_icon = icon_earth
			"wind": 
				cast_elements.append(SpellDictionary.Element.WIND)
				final_icon = icon_wind
		
		# Hô biến: Ẩn chữ, Hiện Hình
		elem_edits[index].hide()
		elem_icons[index].texture = final_icon
		elem_icons[index].show()
	else:
		elem_edits[index].text = "" # Sai thì xóa bắt gõ lại

# XỬ LÝ LỚP 2 (TỌA ĐỘ)
func _on_coord_submitted(new_text: String, index: int):
	var text_upper = new_text.to_upper().strip_edges()
	# Luật: Ô 0 (Trên) và 2 (Dưới) chỉ nhận Chữ (A-H). Ô 1 (Trái) và 3 (Phải) chỉ nhận Số (1-8)
	var is_valid = false
	if (index == 0 or index == 2) and text_upper.length() == 1 and "ABCDEFGH".contains(text_upper):
		is_valid = true
	elif (index == 1 or index == 3) and text_upper.length() == 1 and "12345678".contains(text_upper):
		is_valid = true
		
	if is_valid:
		coord_edits[index].hide()
		coord_icons[index].texture = icon_success_text # Hiện ảnh báo hiệu gõ thành công
		coord_icons[index].show()
	else:
		coord_edits[index].text = ""
# XỬ LÝ LỚP 3 (HƯỚNG)
# XỬ LÝ LỚP 3 (HƯỚNG)
func _on_dir_submitted(new_text: String, index: int):
	var text_lower = new_text.to_lower().strip_edges()
	if text_lower == "sagitta":
		var final_dir = index_to_direction[index]
		cast_directions.append(final_dir)
		dir_edits[index].hide()
		dir_icons[index].texture = icon_success_text
		dir_icons[index].show()
		
		print("Đã giải phóng ấn Sagitta tại ô số ", index, ", hướng bay: ", final_dir)
func _on_end_turn_button_pressed():
	if cast_elements.is_empty(): return # Phải có ít nhất 1 nguyên tố
	var final_coords = []
# Kiểm tra Cặp 1 (Trên & Trái)
	if not coord_edits[0].visible and not coord_edits[1].visible:
		final_coords.append(coord_edits[0].text.to_upper()) # Gửi "D"
		final_coords.append(coord_edits[1].text.to_upper()) # Gửi "2"
		
	# Kiểm tra Cặp 2 (Dưới & Phải)
	if not coord_edits[2].visible and not coord_edits[3].visible:
		final_coords.append(coord_edits[2].text.to_upper())
		final_coords.append(coord_edits[3].text.to_upper())
	Global.paper_count -= 1 
	update_ui() 
	print("Niệm: ", cast_elements, " | Tọa độ: ", final_coords, " | Hướng: ", cast_directions)
	Global.has_casted_spell = true
	spell_casted.emit(cast_elements, final_coords, cast_directions)
	get_tree().call_group("logic_board", "cast_complex_spell", cast_elements, final_coords, cast_directions)
	
	clear_all_inputs()
	close_scroll()
func update_ui():
	if paper_label: paper_label.text = "Giấy: " + str(Global.paper_count)
	if ink_bar: ink_bar.value = (current_ink / max_ink) * 100

func show_scroll():
	self.show()
	%UI_Container.size.x = max_scroll_width

func close_scroll():
	self.hide()
	scroll_closed.emit()
# ==========================================
# TRỪ MỰC REAL-TIME KHI GÕ CHỮ
# ==========================================
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

# ==========================================
# GHI ĐÈ HÀM CLEAR ĐỂ RESET LẠI MỰC (Sửa lại hàm cũ của bạn)
# ==========================================
func clear_all_inputs():
	cast_elements.clear()
	cast_directions.clear()
	
	var all_edits = elem_edits + coord_edits + dir_edits
	var all_icons = elem_icons + coord_icons + dir_icons
	
	for i in range(all_edits.size()):
		all_edits[i].text = ""
		all_edits[i].set_meta("prev_len", 0) # <--- Lệnh bắt buộc để reset logic trừ mực
		all_edits[i].show()
		all_icons[i].hide()
