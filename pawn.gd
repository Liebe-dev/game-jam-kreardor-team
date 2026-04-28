extends Node2D
class_name Piece

# Các thuộc tính cơ bản
@export var team: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO

# --- THÔNG SỐ CHIẾN ĐẤU ---
@export var max_health: int = 250
@export var damage: int = 20
@onready var current_health: int = max_health

var has_moved: bool = false
var is_grabbed = false
var grabbed_by = null

func _ready():
	# Đảm bảo thanh máu khớp với chỉ số khi vừa sinh ra
	if has_node("HealthBar"):
		get_node("HealthBar").max_value = max_health
		get_node("HealthBar").value = current_health

# Hàm nhận sát thương
func take_damage(amount: int):
	current_health -= amount
	
	# Cập nhật thanh máu (Kiểm tra an toàn xem node có tồn tại không)
	if has_node("HealthBar"):
		$HealthBar.value = current_health
	
	# Hiệu ứng nhấp nháy đỏ khi trúng đòn (tùy chọn)
	var t = create_tween()
	t.tween_property(self, "modulate", Color.RED, 0.1)
	t.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

# Hàm xử lý khi quân cờ chết
func die():
	# Có thể phát âm thanh hoặc tạo hiệu ứng hạt ở đây
	queue_free() 

func move_to_grid(new_grid_pos: Vector2i, new_world_pos: Vector2):
	grid_pos = new_grid_pos
	var tween = create_tween()
	tween.tween_property(self, "global_position", new_world_pos, 0.3).set_trans(Tween.TRANS_SINE)
	await tween.finished
