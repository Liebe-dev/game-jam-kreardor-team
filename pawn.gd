extends Node2D
class_name Piece

# Các thuộc tính cơ bản
@export var team: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO

# --- THÔNG SỐ CHIẾN ĐẤU ---
@export var max_health: int = 250
@export var damage: int = 20
@onready var current_health: int = max_health

var is_charging: bool = false # Trạng thái đang nạp đạn
var is_grabbed: bool = false
var grabbed_by: Node2D = null
var has_moved: bool = false
# --- BIẾN QUẢN LÝ ĐẠN ---
var max_ammo = 3
var current_ammo = 3
var is_reloading = false
var reload_turns_left = 0

func _ready():
	# Đảm bảo thanh máu khớp với chỉ số khi vừa sinh ra
	if has_node("HealthBar"):
		get_node("HealthBar").max_value = max_health
		get_node("HealthBar").value = current_health

# Hàm nhận sát thương
func take_damage(amount: int):
	current_health -= amount
	
	if has_node("HealthBar"):
		$HealthBar.value = current_health
	
	var t = create_tween()
	t.tween_property(self, "modulate", Color.RED, 0.1)
	
	# SỬA Ở ĐÂY: Trả về trạng thái màu hiện tại (Cam nạp đạn, Xám bị ôm, hoặc Trắng bình thường)
	t.tween_callback(update_visuals)
	
	if current_health <= 0:
		die()
# Hàm xử lý khi quân cờ chết
func die():
	# Gọi hàm xử lý xóa quân cờ từ logicgame.gd
	var logic_game = get_node("/root/board/logicgame") # Chỉnh lại đường dẫn chuẩn đến logicgame của bạn
	if logic_game:
		logic_game.kill_piece(self)
	else:
		queue_free()
func move_to_grid(new_grid_pos: Vector2i, new_world_pos: Vector2):
	# --- LOGIC QUAY ĐẦU (CODE MỚI ĐÂY) ---
	
	# Vectơ hướng di chuyển (Mới - Cũ)
	var direction_vector = new_grid_pos - grid_pos 
	
	# Cập nhật frame dựa theo hướng di chuyển logic (X, Y)
# Giả sử thứ tự frame sheet của bạn là: 0:Xuống, 1:Phải, 2:Trái, 3:Lên
	if direction_vector.x > 0:
		$Sprite2D.frame = 1 # Đi sang ô X+ (Phải)
	elif direction_vector.x < 0:
		$Sprite2D.frame = 2 # Đi sang ô X- (Trái)
	elif direction_vector.y > 0:
		$Sprite2D.frame = 0 # Đi sang ô Y+ (Hướng Xuống Dưới)
	elif direction_vector.y < 0:
		$Sprite2D.frame = 3 # Đi sang ô Y- (Hướng Lên Trên)

	# --- LOGIC DI CHUYỂN (CODE CŨ CỦA BẠN) ---
	grid_pos = new_grid_pos
	var tween = create_tween()
	tween.tween_property(self, "global_position", new_world_pos, 0.3).set_trans(Tween.TRANS_SINE)
	await tween.finished
func update_visuals():
	if is_grabbed:
		modulate = Color(0.5, 0.5, 0.5) # Vẫn giữ màu xám khi bị ôm
	elif "is_charging" in self and is_charging:
		modulate = Color(2.0, 1.2, 0.5) # Màu cam rực rỡ khi nạp đạn
	else:
		# SỬA Ở ĐÂY: Xóa bỏ việc chia team. Trả tất cả về màu gốc của ảnh (Trắng)
		modulate = Color(1, 1, 1)
