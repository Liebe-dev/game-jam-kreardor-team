extends Node2D

var grid_position: Vector2i = Vector2i.ZERO
var duration: int = 0

func _ready():
	print("Tường đất được tạo tại: ", grid_position, " - Tồn tại: ", duration, " lượt.")

# Hàm này sẽ được gọi mỗi khi kết thúc lượt để trừ thời gian tồn tại
func decrease_duration():
	duration -= 1
	if duration <= 0:
		print("Tường đất tại ", grid_position, " đã sụp đổ!")
		queue_free() # Xóa tường khỏi bàn cờ
