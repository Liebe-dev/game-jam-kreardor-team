extends Node2D # Thêm dòng này lên đầu cùng

# Sử dụng % (Unique Name) cực kỳ an toàn
@onready var magic_system = %MagicDrawingSystem 
@onready var closed_scroll_btn = %ClosedScrollButton

func _ready():
	# Lắng nghe tín hiệu đóng cuộn giấy
	magic_system.scroll_closed.connect(_on_magic_scroll_closed)

# Khi nghe thấy tín hiệu, hiện lại nút cuộn giấy ở góc màn hình
func _on_magic_scroll_closed():
	if not Global.has_casted_spell:
		closed_scroll_btn.show()
func _on_closed_scroll_button_pressed():
	# Ẩn cuộn giấy nhỏ đi
	closed_scroll_btn.hide()
	# Hiển thị giao diện vẽ phép lên
	magic_system.show_scroll()
