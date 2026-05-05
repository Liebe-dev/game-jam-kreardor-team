extends Node2D

@export var team: int = 2 # Đặt là 2 để hệ thống nhận diện đây là phe địch
@export var grid_pos: Vector2i = Vector2i.ZERO

# --- THÔNG SỐ TEST ---
var max_hp: int = 1000
var hp: int = 500
var is_enemy: bool = false
# --- CÁC BIẾN TƯƠNG THÍCH VỚI HỆ THỐNG ---
var is_grabbed: bool = false
var grabbed_by: Node2D = null
var has_moved: bool = false

func _ready():
	# Cập nhật thanh máu lúc mới sinh ra
	if has_node("HealthBar"):
		$HealthBar.max_value = max_hp
		$HealthBar.value = hp
	
	# Đổi màu hình nộm sang hơi vàng/nâu để dễ phân biệt với địch thật
	modulate = Color(0.8, 0.6, 0.2)

# Nhận sát thương từ phép Lửa hoặc chém thường
func take_damage(amount: int):
	hp -= amount
	print("[Hình Nộm] Nhận ", amount, " sát thương! Máu: ", hp, "/", max_hp)
	
	if has_node("HealthBar"):
		$HealthBar.value = hp
		
	if hp <= 0:
		print("[Hình Nộm] Đã bị phá hủy!")
		# Có thể gọi hàm xóa khỏi mảng all_pieces nếu cần, tạm thời cứ queue_free
		queue_free()

# Nhận hồi máu từ phép Nước
func heal(amount: int):
	hp += amount
	if hp > max_hp:
		hp = max_hp
	print("[Hình Nộm] Được hồi ", amount, " máu! Máu: ", hp, "/", max_hp)
	
	if has_node("HealthBar"):
		$HealthBar.value = hp

# Hàm rỗng để không bị lỗi khi hệ thống gọi update_visuals lúc bị túm cổ
func update_visuals():
	pass

# Tùy chọn: Hàm nhận Buff (nếu phép của bạn có add_buff)
func add_buff(buff_name: String, value = null):
	print("[Hình Nộm] Bị dính hiệu ứng: ", buff_name)
	
	# Nếu dính hiệu ứng cháy, ta cho nó mất máu luôn để test cho nhanh
	if buff_name == "burning" or buff_name == "fire":
		take_damage(20) # Giả sử cháy mất 20 máu
