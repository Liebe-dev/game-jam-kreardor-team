extends CanvasLayer

# Sửa lại thành như thế này cho an toàn
@onready var lines_container = find_child("LinesContainer")
@onready var current_line = find_child("CurrentLine")
@onready var ink_bar = find_child("InkBar")
@onready var paper_label = find_child("PaperLabel")
# Tài nguyên

var paper_count : int = 5
var max_ink : float = 2000.0
var current_ink : float = 2000.0
var ink_cost_per_pixel : float = 1.5

# Dữ liệu vẽ
var is_drawing : bool = false
var strokes : Array = [] # Mảng chứa các nét vẽ (mỗi nét là 1 mảng Vector2)
var current_stroke : Array = []

func _ready():
	update_ui()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drawing(event.position)
			else:
				stop_drawing()
				
	elif event is InputEventMouseMotion and is_drawing:
		add_point(event.position)

func start_drawing(pos: Vector2):
	# Chỉ cho phép vẽ nếu còn mực
	if current_ink <= 0: return
	
	is_drawing = true
	current_stroke = [pos]
	current_line.clear_points()
	current_line.add_point(pos)

func add_point(pos: Vector2):
	if current_ink <= 0:
		stop_drawing()
		return
		
	var last_pos = current_stroke[current_stroke.size() - 1]
	var distance = last_pos.distance_to(pos)
	
	# Chỉ thêm điểm nếu rê chuột đủ xa (tránh lưu quá nhiều điểm thừa)
	if distance > 5.0: 
		current_stroke.append(pos)
		current_line.add_point(pos)
		
		# Trừ mực
		current_ink -= distance * ink_cost_per_pixel
		ink_bar.value = (current_ink / max_ink) * 100

func stop_drawing():
	if not is_drawing: return
	is_drawing = false
	
	if current_stroke.size() > 1:
		# Lưu nét vẽ lại
		strokes.append(current_stroke.duplicate())
		
		# Tạo một Line2D mới để hiển thị nét vừa vẽ và cho vào LinesContainer
		var new_line = Line2D.new()
		new_line.points = current_line.points
		new_line.width = current_line.width
		new_line.default_color = current_line.default_color
		lines_container.add_child(new_line)
		
	current_line.clear_points()

func _on_undo_button_pressed():
	if strokes.size() > 0:
		# Xóa dữ liệu nét cuối cùng
		strokes.pop_back()
		
		# Xóa Line2D hiển thị cuối cùng
		var child_count = lines_container.get_child_count()
		if child_count > 0:
			var last_line = lines_container.get_child(child_count - 1)
			last_line.queue_free()
		
		# LƯU Ý: Không cộng lại biến current_ink (luật không hoàn mực)

# Trong magic_drawing_system.gd

func _on_end_turn_button_pressed():
# Trừ 1 tờ giấy ngay khi nhấn kết thúc
	Global.paper_count -= 1 
	# Mực đã bị trừ trong lúc vẽ rồi nên không cần trừ thêm ở đây
	
	update_ui() # Cập nhật lại nhãn hiển thị số giấy còn lại
	# 2. Lấy kết quả nhận diện từ plugin
	var gesture_result = $GestureRecognizer.get_recognized_gesture()
	
	# 3. Kiểm tra xem có nhận diện được Ấn nào không
	var element = SpellDictionary.Element.NONE
	match gesture_result:
		"Fire": element = SpellDictionary.Element.FIRE
		"Water": element = SpellDictionary.Element.WATER
		"Earth": element = SpellDictionary.Element.EARTH
		"Wind": element = SpellDictionary.Element.WIND

	# 4. Xử lý kết quả
	if element == SpellDictionary.Element.NONE:
		# TRƯỜNG HỢP VẼ SAI:
		play_fizzle_effect() # Hiện hiệu ứng khói xịt hoặc rung màn hình
	else:
		# TRƯỜNG HỢP VẼ ĐÚNG:
		# Gọi sang board để bắn phép như bình thường
		get_parent().cast_spell(element) 
	
	# Đóng bảng vẽ sau khi kết thúc lượt
	self.hide()
func update_ui():
	# Kiểm tra xem các node UI đã được gán đúng chưa trước khi cập nhật
	if paper_label:
		paper_label.text = "Giấy: " + str(paper_count)
	
	if ink_bar:
		ink_bar.value = (current_ink / max_ink) * 100

# Hàm xử lý thuật toán nhận diện (hiện tại để trống/in ra console làm placeholder)
func evaluate_magic():
	print("Đang đánh giá nét vẽ... (Cần tích hợp thuật toán nhận diện $1 Unistroke)")
	
	# Đoạn code dưới đây để tạm thời reset lại giấy mực sau khi vẽ xong để bạn dễ test UI
	# Bạn có thể xóa phần reset này đi khi bắt đầu làm logic chuyển lượt (turn)
	# current_ink = max_ink 
	# update_ui()
func play_fizzle_effect():
	# 1. Rung màn hình nhẹ (nếu bạn có hệ thống camera shake)
	# 2. Đổi màu toàn bộ nét vẽ thành màu xám tối rồi biến mất
	if has_node("UI_Container/LinesContainer"):
		for line in $UI_Container/LinesContainer.get_children():
			line.default_color = Color(0.3, 0.3, 0.3, 1) # Màu xám tối
			
	# 3. Tạo hiệu ứng khói (nếu có GPUParticles2D)
	# spawn_smoke_particle() 
	
	# Đợi 0.5 giây để người chơi thấy hiệu ứng rồi mới ẩn bảng
	await get_tree().create_timer(0.5).timeout
