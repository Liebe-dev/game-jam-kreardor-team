extends Node2D
class_name Piece

# Các thuộc tính cơ bản
@export var team: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO

# --- THÔNG SỐ CHIẾN ĐẤU ---
@export var max_health: int = 250
@export var damage: int = 20
@onready var current_health: int = max_health
# Túi chứa buff. Ví dụ: {"burn": 2, "invulnerable": 1}
var active_buffs: Dictionary = {}
var is_charging: bool = false # Trạng thái đang nạp đạn
var is_grabbed: bool = false
var grabbed_by: Node2D = null
var has_moved: bool = false
# --- BIẾN QUẢN LÝ ĐẠN ---
var max_ammo = 3
var current_ammo = 3
var is_reloading = false
var reload_turns_left = 0
var damage_reduction_rate = 0.0
func _ready():
	# Đảm bảo thanh máu khớp với chỉ số khi vừa sinh ra
	if has_node("HealthBar"):
		get_node("HealthBar").max_value = max_health
		get_node("HealthBar").value = current_health

# Hàm nhận sát thương
func take_damage(amount: float):
	# Tính toán sát thương sau khi giảm trừ
	var final_damage = amount * (1.0 - damage_reduction_rate)
	
	# Trừ lượng sát thương ĐÃ GIẢM vào máu hiện tại
	current_health -= final_damage 
	
	if has_node("HealthBar"):
		get_node("HealthBar").value = current_health
	
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
var burn_ticks = 0


# 1. BẬT ANIMATION KHI NHẬN BUFF
func add_buff(buff_name: String, value: float, duration_turns: int):
	active_buffs[buff_name] = duration_turns
	
	if buff_name == "damage_reduction":
		damage_reduction_rate = value
		
		# --- Bật Animation Khiên của bạn ở đây ---
		# Thay "ShieldAnim" bằng tên Node thực tế của bạn
		if has_node("ShieldAnim"):
			$ShieldAnim.visible = true
			$ShieldAnim.play("ShieldAnim") # Điền tên animation loop của khiên vào
			
		print("[Pawn] Bật khiên bảo vệ cho ", name)

# 2. TẮT ANIMATION KHI HẾT LƯỢT
func on_turn_end():
	if active_buffs.has("damage_reduction"):
		active_buffs["damage_reduction"] -= 1 
		
		# Hết lượt -> Tắt buff
		if active_buffs["damage_reduction"] <= 0:
			active_buffs.erase("damage_reduction")
			damage_reduction_rate = 0.0
			
			# --- Tắt Animation Khiên đi ---
			if has_node("ShieldAnim"):
				$ShieldAnim.visible = false
				$ShieldAnim.stop()
				
			print("[Pawn] Đã vỡ khiên Đất trên ", name)
func process_buffs():
	# 1. Gây tác dụng của các buff bất lợi đầu hiệp (như rút máu do cháy)
	if active_buffs.has("burn"):
		take_damage(10) # Cháy thì mất 10 máu mỗi hiệp
		print(name, " bị mất máu do thiêu đốt!")

	# 2. Giảm số lượt của tất cả các buff đi 1
	var expired_buffs = []
	for buff in active_buffs.keys():
		active_buffs[buff] -= 1
		
		# Nếu hết lượt thì đánh dấu để xóa
		if active_buffs[buff] <= 0:
			expired_buffs.append(buff)
			
	# 3. Xóa các buff đã hết hạn
	for buff in expired_buffs:
		active_buffs.erase(buff)
		# Khôi phục màu sắc gốc nếu cần
		if active_buffs.is_empty():
			modulate = Color(1, 1, 1)
func heal(amount):
	current_health += amount
	# Chặn không cho máu vượt mức tối đa (Giả sử max_current_health là biến máu tối đa của bạn)
	if current_health > max_health: 
		current_health = max_health
		
	# Cập nhật lại cái thanh máu hiển thị trên đầu
	if has_node("HealthBar"):
		get_node("HealthBar").value = current_health
