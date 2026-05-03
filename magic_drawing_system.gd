extends CanvasLayer

@onready var lines_container = $UI_Container/LinesContainer
@onready var current_line = $UI_Container/CurrentLine
@onready var ink_bar = $UI_Container/ResourceUI/InkBar
@onready var paper_label = $UI_Container/ResourceUI/PaperLabel

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

func _on_end_turn_button_pressed():
	paper_count -= 1
	update_ui()
	
	print("Bắt đầu xử lý tính toán phép thuật...")
	# Bước tiếp theo: Đưa mảng 'strokes' vào thuật toán nhận diện
	evaluate_magic()
	# Hàm cập nhật số lượng Giấy và thanh Mực trên UI
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
