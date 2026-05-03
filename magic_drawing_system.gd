extends CanvasLayer

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
var ink_cost_per_pixel : float = 1.5

# Dữ liệu vẽ
var is_drawing : bool = false
var strokes : Array = [] # Mảng chứa các nét vẽ (mỗi nét là 1 mảng Vector2)
var current_stroke : Array = []

func _ready():
	update_ui()

# Bắt sự kiện chuột chỉ khi thao tác trên Cuộn Giấy (SpellScroll)
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
		update_ui()

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

func _on_end_turn_button_pressed():
	Global.paper_count -= 1 
	update_ui() 
	
	# 1. Tìm tọa độ tâm của vòng tròn phép (tương đối so với SpellScroll)
	var circle_center = magic_circle.position + (magic_circle.size / 2.0)
	
	# 2. Tạo 3 mảng để chứa các nét vẽ được phân loại
	var layer1_strokes = [] # Lõi (Ấn)
	var layer2_strokes = [] # Giữa (Tọa độ)
	var layer3_strokes = [] # Rìa (Hướng)
	
	# 3. Phân loại nét vẽ dựa vào khoảng cách đến tâm
	for stroke in strokes:
		var center_pt = get_stroke_center(stroke)
		var distance = circle_center.distance_to(center_pt)
		
		if distance < radius_inner:
			layer1_strokes.append(stroke)
		elif distance < radius_middle:
			layer2_strokes.append(stroke)
		else:
			layer3_strokes.append(stroke)

	# 4. NHẬN DIỆN LỚP 1: ẤN CHÚ (Bắt buộc phải có)
	var element = SpellDictionary.Element.NONE
	if layer1_strokes.size() > 0:
		# Gửi các nét ở lõi vào plugin (Bạn cần điều chỉnh hàm nhận của plugin cho phù hợp)
		var element_gesture = recognize_strokes_with_plugin(layer1_strokes)
		match element_gesture:
			"fire", "fire_hand_1", "fire_hand_2", "fire_hand_3": element = SpellDictionary.Element.FIRE
			"water", "water_hand_1": element = SpellDictionary.Element.WATER
			"earth", "earth_hand_1": element = SpellDictionary.Element.EARTH
			"wind", "wind_hand_1": element = SpellDictionary.Element.WIND

	# Nếu không nhận diện được ấn, báo lỗi phép xịt ngay
	if element == SpellDictionary.Element.NONE:
		play_fizzle_effect()
		self.hide()
		return
		
# 5. NHẬN DIỆN LỚP 2: TỌA ĐỘ (A-H, 1-8)
	var target_coords = []
	var valid_chars = ["A", "B", "C", "D", "E", "F", "G", "H", "1", "2", "3", "4", "5", "6", "7", "8"]
	
	# GỌI HÀM GOM NHÓM ĐỂ XỬ LÝ NHIỀU NÉT (MULTISTROKE)
	var layer2_clusters = cluster_strokes(layer2_strokes, 70.0)
	
	for cluster in layer2_clusters:
		var coord_gesture = recognize_strokes_with_plugin(cluster) # Truyền cả cụm đa nét vào plugin
		
		if coord_gesture != "Unknown":
			var base_char = coord_gesture.split("_")[0].to_upper()
			if base_char in valid_chars:
				target_coords.append(base_char)

	# 6. NHẬN DIỆN LỚP 3: HƯỚNG (Mũi tên)
	var directions = []
	
	# Mũi tên thường được vẽ bằng 2-3 nét nhấc bút, nên cũng cần gom nhóm
	var layer3_clusters = cluster_strokes(layer3_strokes, 100.0) 
	
	for cluster in layer3_clusters:
		var dir_gesture = recognize_strokes_with_plugin(cluster)
		match dir_gesture:
			"left", "left_hand_1": directions.append(Vector2.LEFT)
			"right", "right_hand_1": directions.append(Vector2.RIGHT)
			"up", "up_hand_1": directions.append(Vector2.UP)
			"down", "down_hand_1": directions.append(Vector2.DOWN)
	# 7. CHUYỂN DỮ LIỆU SANG CHO BÀN CỜ THỰC THI
	print("Đã niệm phép: ", element, " | Tọa độ: ", target_coords, " | Hướng: ", directions)
	get_parent().cast_complex_spell(element, target_coords, directions)
	
	self.hide()

# --- Hàm trung gian để gọi Plugin ---
func recognize_strokes_with_plugin(strokes_to_eval: Array) -> String:
	if strokes_to_eval.is_empty(): return "Unknown"
	
	# TODO: Chèn logic gọi plugin nhận diện của bạn vào đây.
	# Ví dụ: $GestureRecognizer.set_strokes(strokes_to_eval)
	# return $GestureRecognizer.get_recognized_gesture()
	
	return "Unknown" # Placeholder
func update_ui():
	if paper_label:
		# Đồng bộ hiển thị với biến giấy ở Global
		paper_label.text = "Giấy: " + str(Global.paper_count)
	
	if ink_bar:
		ink_bar.value = (current_ink / max_ink) * 100

func play_fizzle_effect():
	print("Phép xịt! Đang tạo hiệu ứng...")
	# Sử dụng trực tiếp biến lines_container đã được khai báo ở đầu
	for line in lines_container.get_children():
		line.default_color = Color(0.3, 0.3, 0.3, 1) # Màu xám tối
		
	await get_tree().create_timer(0.5).timeout
	# Thêm hàm này vào dưới cùng của script
func get_stroke_center(stroke_points: Array) -> Vector2:
	if stroke_points.is_empty(): return Vector2.ZERO
	
	var sum = Vector2.ZERO
	for pt in stroke_points:
		sum += pt
	return sum / stroke_points.size()
# Hàm gom các nét vẽ gần nhau thành 1 cụm (1 ký tự đa nét)
func cluster_strokes(layer_strokes: Array, threshold_distance: float = 70.0) -> Array:
	var clusters = [] # Chứa các cụm (mỗi cụm là mảng các nét vẽ)
	
	for stroke in layer_strokes:
		var stroke_center = get_stroke_center(stroke)
		var added_to_cluster = false
		
		for cluster in clusters:
			# Tìm trọng tâm của cụm hiện tại
			var cluster_center = Vector2.ZERO
			for s in cluster:
				cluster_center += get_stroke_center(s)
			cluster_center /= cluster.size()
			
			# Nếu nét vẽ nằm đủ gần cụm, gộp nó vào
			if stroke_center.distance_to(cluster_center) < threshold_distance:
				cluster.append(stroke)
				added_to_cluster = true
				break
				
		# Nếu nét vẽ nằm lẻ loi, tạo một cụm mới cho nó
		if not added_to_cluster:
			clusters.append([stroke])
			
	return clusters
