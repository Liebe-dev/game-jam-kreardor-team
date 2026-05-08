extends AnimatedSprite2D

var grid_pos: Vector2i
var team: int = 1      
var hp: int = 500
var max_hp: int = 500
var duration: int = 9  
var is_grabbed: bool = false
var has_moved: bool = false
# --- THÊM HÀM NÀY VÀO ĐÂY ---
func _ready():
	# Chỉnh thứ tự hiển thị để nằm dưới lính (tùy chọn, z_index = 0 hoặc -1)
	self.z_index = 0 
	
	# Bật animation giodat ngay lập tức
	self.play("default")
# ----------------------------


func take_damage(amount: int, source = null):
	hp -= amount
	print("[Khối Đất] Bị tấn công! Sát thương: ", amount, " | Máu còn: ", hp)
	
	# Hiệu ứng nháy đỏ khi bị đánh
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)
	
	if hp <= 0:
		print("[Khối Đất] Bị phá hủy tại ô: ", grid_pos)
		die()

func die():
	# Biến mất khỏi bàn cờ
	queue_free()
