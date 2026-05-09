extends CanvasLayer

# Khai báo tham chiếu an toàn (Strict node referencing)
@onready var closed_book_btn: TextureButton = $ClosedBookButton
@onready var opened_book_panel: Control = $OpenedBookPanel
@onready var close_btn: Button = $OpenedBookPanel/CloseButton # Giả định bạn có nút X

func _ready() -> void:
	# Khởi tạo trạng thái gốc một cách tường minh
	opened_book_panel.hide()
	closed_book_btn.show()
	
	# Kết nối tín hiệu (Signals) bằng code thay vì qua giao diện để dễ kiểm soát
	closed_book_btn.pressed.connect(_on_closed_book_pressed)
	
	if close_btn:
		close_btn.pressed.connect(_on_close_book_pressed)
	else:
		push_warning("[UI_Book] Chưa thiết lập nút Đóng (CloseButton) cho OpenedBookPanel.")

func _on_closed_book_pressed() -> void:
	open_book()

func _on_close_book_pressed() -> void:
	close_book()

# Tách riêng logic xử lý để dễ dàng mở rộng (ví dụ: thêm âm thanh lật sách, hiệu ứng Tween)
func open_book() -> void:
	closed_book_btn.hide()   # Tạm ẩn icon sách đóng
	opened_book_panel.show() # Hiện giao diện sách mở
	
	# Gợi ý: Gọi hàm phát âm thanh lật giấy ở đây

func close_book() -> void:
	opened_book_panel.hide() # Ẩn giao diện sách mở
	closed_book_btn.show()   # Hiện lại icon sách đóng


func _on_close_botton_pressed() -> void:
	close_book()
	pass # Replace with function body.
