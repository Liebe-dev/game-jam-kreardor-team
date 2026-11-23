extends AnimatedSprite2D

var grid_pos: Vector2i
var team: int = 1      
var hp: int = 500
var max_hp: int = 500
var duration: int = 9  
var is_grabbed: bool = false
var has_moved: bool = false
func _ready():
	self.z_index = 0 
	self.play("default")
func take_damage(amount: int, source = null):
	hp -= amount
	print("[Khối Đất] Bị tấn công! Sát thương: ", amount, " | Máu còn: ", hp)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)
	if hp <= 0:
		print("[Khối Đất] Bị phá hủy tại ô: ", grid_pos)
		die()
func die():
	var logic = get_tree().get_first_node_in_group("logic_board")
	if logic != null:
		logic.kill_piece(self)
	else:
		queue_free()
