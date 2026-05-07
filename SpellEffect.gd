extends AnimatedSprite2D

func _ready():
	# Lắng nghe: Khi nào chạy xong bộ ảnh thì tự động gọi hàm bên dưới
	animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	# queue_free() sẽ tự động xóa Node này khỏi game
	queue_free()
