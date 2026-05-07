extends CanvasLayer
var current_elements: Array = []
var current_coord_chars: Array = []
signal scroll_closed
signal spell_casted(elements, coordinates, directions_list)

# Sử dụng Unique Name (%) để không bao giờ bị lỗi sai đường dẫn Node nữa
@onready var lines_container = %LinesContainer
@onready var current_line = %CurrentLine
@onready var ink_bar = %InkBar
@onready var paper_label = %PaperLabel
# Khai báo cấu trúc UI đã có
@onready var spell_scroll = %SpellScroll
@onready var magic_circle = %MagicCircleImage # Thêm node này để lấy vị trí tâm

# Cấu hình Bán kính 3 lớp (Tính bằng pixel, bạn có thể chỉnh trong Inspector)
@export var radius_inner: float = 80.0
@export var radius_middle: float = 180.0

# Tài nguyên
var max_ink : float = 2000.0
var current_ink : float = 2000.0
var ink_cost_per_pixel : float = 1
var max_scroll_width: float = 0.0
# Dữ liệu vẽ
var is_drawing : bool = false
var strokes : Array = [] # Mảng chứa các nét vẽ (mỗi nét là 1 mảng Vector2)
var current_stroke : Array = []

func _ready():
	Global.magic_system = self
	$GestureRecognizer.LoadGesturesFromResources("res://addons/Gesture_recognizer/resources/gestures/")
	update_ui()
	max_scroll_width = %UI_Container.size.x
func _on_spell_scroll_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drawing(event.position)
			else:
				stop_drawing()
				
	elif event is InputEventMouseMotion and is_drawing:
		add_point(event.position)

func start_drawing(pos: Vector2):
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
	
	if distance > 5.0: 
		current_stroke.append(pos)
		current_line.add_point(pos)
		current_ink -= distance * ink_cost_per_pixel
		update_ui()

func stop_drawing():
	if not is_drawing: return
	is_drawing = false
	
	if current_stroke.size() > 1:
		strokes.append(current_stroke.duplicate())
		var new_line = Line2D.new()
		new_line.points = current_line.points
		new_line.width = current_line.width
		new_line.default_color = current_line.default_color
		lines_container.add_child(new_line)
		
	current_line.clear_points()

func _on_undo_button_pressed():
	if strokes.size() > 0:
		strokes.pop_back()
		var child_count = lines_container.get_child_count()
		if child_count > 0:
			var last_line = lines_container.get_child(child_count - 1)
			last_line.queue_free()

func _on_end_turn_button_pressed():
	Global.paper_count -= 1 
	update_ui() 
	
	# 1. Tìm tọa độ tâm
	var circle_center = magic_circle.position + (magic_circle.size / 2.0)
	
	# =========================================================
	# BƯỚC MỚI: GOM NHÓM TẤT CẢ NÉT VẼ TRƯỚC KHI CHIA LỚP
	# Tăng khoảng cách gom nhóm lên 90 để các nét xa nhau vẫn dính lại
	# =========================================================
	var all_clusters = cluster_strokes(strokes, 90.0)
	
	# Tạo 3 mảng chứa CỤM nét vẽ (Thay vì từng nét lẻ tẻ)
	var layer1_clusters = []
	var layer2_clusters = []
	var layer3_clusters = []
	
	# ĐIỀU CHỈNH LẠI BÁN KÍNH THỰC TẾ CHO KHỚP VỚI UI (Bạn có thể tăng giảm số này)
	var actual_radius_inner = 87.15
	var actual_radius_middle = 174.3
	
	# Phân loại nguyên cả CỤM vào các Lớp
	for cluster in all_clusters:
		var cluster_center = get_cluster_center(cluster)
		var distance = circle_center.distance_to(cluster_center)
		
		if distance < actual_radius_inner:
			layer1_clusters.append(cluster)
		elif distance < actual_radius_middle:
			layer2_clusters.append(cluster)
		else:
			layer3_clusters.append(cluster)

	# =========================================================
	# 4. NHẬN DIỆN LỚP 1: ẤN CHÚ
	# =========================================================
	var recognized_elements = []
	
	if layer1_clusters.size() > 0:
		for cluster in layer1_clusters:
			var element_gesture = recognize_strokes_with_plugin(cluster, "l1_")
			var elem = SpellDictionary.Element.NONE
			
			match element_gesture:
				"l1_fire_hand_1", "l1_fire_hand_2", "l1_fire_hand_3": elem = SpellDictionary.Element.FIRE
				"l1_water_hand_1": elem = SpellDictionary.Element.WATER
				"l1_earth_hand_1": elem = SpellDictionary.Element.EARTH
				"l1_wind_hand_1": elem = SpellDictionary.Element.WIND
				
			if elem != SpellDictionary.Element.NONE:
				recognized_elements.append(elem)

	if recognized_elements.is_empty():
		play_fizzle_effect()
		await get_tree().create_timer(0.5).timeout
		clear_all_strokes()
		close_scroll()
		return
		
	# ... (GIỮ NGUYÊN CODE TỪ BƯỚC 5 TRỞ ĐI: Nhận diện Lớp 2...) ...
	# 5. NHẬN DIỆN LỚP 2 (ĐÃ ÁP DỤNG LỌC LÙI TOP 1, 2, 3...)
	var valid_letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
	var valid_numbers = ["1", "2", "3", "4", "5", "6", "7", "8"]
	var target_coords = []

	for cluster in layer2_clusters:
		var cluster_center = get_cluster_center(cluster)
		var angle = get_angle_deg(cluster_center)
		
		# Xác định luật vùng này: Trục ngang (chữ) hay Trục dọc (số)
		var is_horizontal = abs(angle) <= 45.0 or abs(angle) >= 135.0
		var allowed_chars = valid_letters if is_horizontal else valid_numbers
		
		# Gọi hàm "Lọc lùi" đặc biệt
		var final_char = get_valid_gesture_with_fallback(cluster, "l2_", allowed_chars)
		
		if final_char != "":
			target_coords.append(final_char)
		else:
			print("Nét vẽ quá xấu hoặc không khớp luật vùng, bỏ qua!")

# 6. NHẬN DIỆN LỚP 3: HƯỚNG
	var directions = []
	
	for cluster in layer3_clusters:
		var cluster_center = get_cluster_center(cluster)
		var angle = get_angle_deg(cluster_center)
		var rotated_cluster = []
		for stroke in cluster:
			var rotated_stroke = []
			for pt in stroke:
				# 1. Đưa điểm về hệ quy chiếu tâm nét vẽ
				var local_pt = pt - cluster_center
				# 2. Xoay ngược lại đúng bằng góc lệch (chuyển sang radian)
				var rotated_pt = local_pt.rotated(deg_to_rad(-angle))
				# 3. Trả điểm về vị trí cũ
				rotated_stroke.append(rotated_pt + cluster_center)
			rotated_cluster.append(rotated_stroke)
			
		# Gọi plugin đọc nét vẽ ĐÃ ĐƯỢC XOAY (Nó sẽ khớp hoàn hảo với template mũi tên sang phải)
		var is_arrow = recognize_strokes_with_plugin(rotated_cluster, "l3_") != "Unknown"
		
		if is_arrow:
			var final_dir = Vector2.ZERO
			
			# Chia 360 độ thành 8 vùng (mỗi vùng 45 độ)
			if angle >= -22.5 and angle < 22.5: final_dir = Vector2(1, 0) # Phải
			elif angle >= 22.5 and angle < 67.5: final_dir = Vector2(1, 1) # Xuống Phải
			elif angle >= 67.5 and angle < 112.5: final_dir = Vector2(0, 1) # Xuống
			elif angle >= 112.5 and angle < 157.5: final_dir = Vector2(-1, 1) # Xuống Trái
			elif angle >= 157.5 or angle < -157.5: final_dir = Vector2(-1, 0) # Trái
			elif angle >= -157.5 and angle < -112.5: final_dir = Vector2(-1, -1) # Lên Trái
			elif angle >= -112.5 and angle < -67.5: final_dir = Vector2(0, -1) # Lên
			elif angle >= -67.5 and angle < -22.5: final_dir = Vector2(1, -1) # Lên Phải
				
			directions.append(final_dir)
			print("Nhận diện mũi tên thành công tại hướng: ", final_dir)
	print("Đã niệm phép: ", recognized_elements, " | Tọa độ: ", target_coords, " | Hướng: ", directions)
	Global.has_casted_spell = true
	spell_casted.emit(recognized_elements, target_coords, directions)
	get_tree().call_group("logic_board", "cast_complex_spell", recognized_elements, target_coords, directions)
	clear_all_strokes()
	close_scroll()
func recognize_strokes_with_plugin(strokes_to_eval: Array, layer_prefix: String) -> String:
	if strokes_to_eval.is_empty(): return "Unknown"
	
	var plugin_points = []
	var stroke_id = 0
	for stroke in strokes_to_eval:
		for pt in stroke:
			plugin_points.append($GestureRecognizer.Point.new(pt.x, pt.y, stroke_id))
		stroke_id += 1

	var all_gestures = $GestureRecognizer._gestures_templates.duplicate() 
	var filtered_gestures = []
	for g in all_gestures:
		if g["name"].begins_with(layer_prefix): filtered_gestures.append(g)
			
	if filtered_gestures.is_empty(): return "Unknown"
			
	$GestureRecognizer._gestures_templates = filtered_gestures
	var result_dict = $GestureRecognizer.Recognize(plugin_points, 0.7) 
	$GestureRecognizer._gestures_templates = all_gestures
	
	if result_dict["name"] == "No Match" or result_dict["name"] == "No Templates":
		return "Unknown"
	return result_dict["name"]

# TÍNH NĂNG MỚI: HÀM TÌM KẾT QUẢ THEO LUẬT (LỌC LÙI TỪ TOP 1 ĐẾN TOP N)
func get_valid_gesture_with_fallback(strokes_to_eval: Array, layer_prefix: String, allowed_chars: Array) -> String:
	if strokes_to_eval.is_empty(): return ""

	var plugin_points = []
	var stroke_id = 0
	for stroke in strokes_to_eval:
		for pt in stroke:
			plugin_points.append($GestureRecognizer.Point.new(pt.x, pt.y, stroke_id))
		stroke_id += 1

	# Lấy danh sách template gốc
	var all_gestures = $GestureRecognizer._gestures_templates.duplicate()
	var filtered_gestures = []
	for g in all_gestures:
		if g["name"].begins_with(layer_prefix):
			filtered_gestures.append(g)

	var best_valid_char = ""
	
	# Vòng lặp cho phép sai tối đa 5 lần (xét đến top 5)
	for attempt in range(5):
		if filtered_gestures.is_empty(): break
			
		$GestureRecognizer._gestures_templates = filtered_gestures
		var result_dict = $GestureRecognizer.Recognize(plugin_points, 0.7)
		
		# Nếu không nhận diện được nữa thì dừng
		if result_dict["name"] == "No Match" or result_dict["name"] == "No Templates":
			break
			
		var gesture_name = result_dict["name"]
		var parsed_char = gesture_name.split("_")[1].to_upper()
		
		# KIỂM TRA LUẬT
		if parsed_char in allowed_chars:
			best_valid_char = parsed_char
			print("Đã chốt '", best_valid_char, "' tại Top ", attempt + 1, " (Template: ", gesture_name, ")")
			break # Tìm thấy rồi thì thoát vòng lặp
		else:
			# NẾU SAI LUẬT: Xóa template này khỏi danh sách và cho máy nhận diện lại
			for i in range(filtered_gestures.size() - 1, -1, -1):
				if filtered_gestures[i]["name"] == gesture_name:
					filtered_gestures.remove_at(i) # Xóa phần tử mảng trong Godot 4
					break

	# Trả lại dữ liệu gốc cho plugin để không làm hỏng các lượt vẽ sau
	$GestureRecognizer._gestures_templates = all_gestures
	return best_valid_char

func update_ui():
	if paper_label: paper_label.text = "Giấy: " + str(Global.paper_count)
	if ink_bar: ink_bar.value = (current_ink / max_ink) * 100

func play_fizzle_effect():
	print("Phép xịt! Đang tạo hiệu ứng...")
	for line in lines_container.get_children():
		line.default_color = Color(0.3, 0.3, 0.3, 1)
	await get_tree().create_timer(0.5).timeout

func get_stroke_center(stroke_points: Array) -> Vector2:
	if stroke_points.is_empty(): return Vector2.ZERO
	var sum = Vector2.ZERO
	for pt in stroke_points: sum += pt
	return sum / stroke_points.size()

func cluster_strokes(layer_strokes: Array, threshold_distance: float = 70.0) -> Array:
	var clusters = []
	for stroke in layer_strokes:
		var stroke_center = get_stroke_center(stroke)
		var added_to_cluster = false
		for cluster in clusters:
			var cluster_center = Vector2.ZERO
			for s in cluster: cluster_center += get_stroke_center(s)
			cluster_center /= cluster.size()
			if stroke_center.distance_to(cluster_center) < threshold_distance:
				cluster.append(stroke)
				added_to_cluster = true
				break
		if not added_to_cluster: clusters.append([stroke])
	return clusters

func get_cluster_center(cluster: Array) -> Vector2:
	var center = Vector2.ZERO
	var count = 0
	for stroke in cluster:
		for point in stroke:
			center += point
			count += 1
	if count == 0: return Vector2.ZERO
	return center / count

func get_angle_deg(cluster_center: Vector2) -> float:
	var circle_center = magic_circle.position + (magic_circle.size / 2.0)
	
	var dir_vec = cluster_center - circle_center
	return rad_to_deg(dir_vec.angle())
func _on_close_area_button_pressed():
	close_scroll()
func show_scroll():
	self.show()
	%UI_Container.position.y = 0 
	%UI_Container.size.x = 0
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(%UI_Container, "size:x", max_scroll_width, 0.2)
func close_scroll():
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(%UI_Container, "size:x", 0.0, 0.3)
	
	tween.finished.connect(_on_close_animation_finished)
func _on_close_animation_finished():
	self.hide()
	scroll_closed.emit()

func clear_all_strokes():
	strokes.clear()
	current_stroke.clear()
	current_line.clear_points()
	for line in lines_container.get_children():
		line.queue_free()
		
	current_ink = max_ink
	update_ui()
# Hàm này để các script khác (như logicgame) có thể gọi tới
func add_ink(amount: float):
	# Cộng mực vào biến có sẵn
	current_ink += amount
	
	# Đảm bảo mực không vượt quá giới hạn (giả sử max là 100)
	if current_ink > 2000:
		current_ink = 2000
	
	# In ra để debug xem mực có tăng thật không
	print("[Magic System] Đã nhận ", amount, " mực. Mực hiện tại: ", current_ink)
	
	# QUAN TRỌNG: Nếu bạn có thanh ProgressBar hiển thị mực, hãy cập nhật nó ở đây
	# Ví dụ:
	# if has_node("InkBar"):
	#    $InkBar.value = current_ink
# Hàm này để cập nhật con số hiển thị trên màn hình
func update_paper_ui(new_amount: int):
	# Dùng find_child để Godot tự đi tìm cái nhãn cho mình, đỡ bị lỗi null
	var label = find_child("PaperLabel", true, false)
	
	if label:
		label.text = "Giấy: " + str(new_amount)
