extends GridContainer

const SIZE = 8

func _ready():
	for child in get_children():
		child.queue_free()
		
	columns = SIZE
	
	for y in range(SIZE):
		for x in range(SIZE):
			var cell = Button.new()
			cell.custom_minimum_size = Vector2(80, 80)
			
			cell.flat = true
			
			# Lưu tọa độ vào metadata
			cell.set_meta("grid_pos", Vector2i(x, y))
			
			# Kết nối tín hiệu click
			cell.pressed.connect(_on_cell_pressed.bind(cell))
			
			add_child(cell)

func _on_cell_pressed(cell_node):
	var pos = cell_node.get_meta("grid_pos")
	var logic = get_node("../../logicgame") # Đảm bảo đường dẫn này đúng tới node logicgame
	
	# Thay vì check state phức tạp, cứ truyền tọa độ sang cho logicgame xử lý
	if logic.has_method("handle_player_input"):
		logic.handle_player_input(pos)
