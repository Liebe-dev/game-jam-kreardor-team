extends AnimatedSprite2D
var grid_position: Vector2i
var duration: int
func _ready():
	# Ngay khi cột đất được tạo ra, gọi hàm play() trực tiếp cho chính bản thân nó
	play("default")
