extends Node2D
class_name Piece

# Các thuộc tính cơ bản
@export var team: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var max_health: int = 250
@export var damage: int = 20
@onready var current_health: int = max_health

var active_buffs: Dictionary = {}
var is_charging: bool = false
var is_grabbed: bool = false
var grabbed_by: Node2D = null
var has_moved: bool = false

var max_ammo = 3
var current_ammo = 3
var is_reloading = false
var reload_turns_left = 0
var damage_reduction_rate = 0.0
var is_shield_new = false
var current_wind_visual = null
var stun_turns = 0
var root_turns = 0

@onready var anim_sprite = $anim_sprite
func _ready():
	if has_node("HealthBar"):
		get_node("HealthBar").max_value = max_health
		get_node("HealthBar").value = current_health
	if anim_sprite:
		if team == 1:
			anim_sprite.play("idle_up")
		else:
			anim_sprite.play("idle_down")
func take_damage(amount: float):
	var final_damage = amount * (1.0 - damage_reduction_rate)
	current_health -= final_damage 
	
	if has_node("HealthBar"):
		$HealthBar.value = current_health
	
	var t = create_tween()
	t.tween_property(self, "modulate", Color.RED, 0.1)
	t.tween_callback(update_visuals)
	
	if current_health <= 0:
		die()

func die():
	var logic_game = get_node("/root/board/logicgame")
	if logic_game:
		logic_game.kill_piece(self)
	else:
		queue_free()

func move_to_grid(new_grid_pos: Vector2i, new_world_pos: Vector2):
	if stun_turns > 0 or root_turns > 0:
		var loai_buff = "Choáng" if stun_turns > 0 else "Trói chân"
		print("Không thể đi! Quân lính đang bị: ", loai_buff)
		return
	SoundManager.play_sound(SoundManager.sfx_move_pawn)
	var direction_vector = new_grid_pos - grid_pos 
	
	if anim_sprite:
		if direction_vector.x > 0:
			anim_sprite.play("idle_right")
		elif direction_vector.x < 0:
			anim_sprite.play("idle_left")
		elif direction_vector.y > 0:
			anim_sprite.play("idle_down")
		elif direction_vector.y < 0:
			anim_sprite.play("idle_up")

	grid_pos = new_grid_pos
	var tween = create_tween()
	tween.tween_property(self, "global_position", new_world_pos, 0.3).set_trans(Tween.TRANS_SINE)
	await tween.finished
	Global.tutorial_pawn_moved.emit()
	var logic_game = get_node("/root/board") 
	if logic_game.has_method("check_trap_at"):
		logic_game.check_trap_at(self, grid_pos)
func play_attack_animation(target_pos: Vector2i):
	if not anim_sprite: return
	SoundManager.play_sound(SoundManager.sfx_slash)
	var dir = target_pos - grid_pos
	var anim_name = "attack_down"
	var idle_name = "idle_down"
	if dir.x > 0: 
		anim_name = "attack_right"
		idle_name = "idle_right"
	elif dir.x < 0: 
		anim_name = "attack_left"
		idle_name = "idle_left"
	elif dir.y < 0: 
		anim_name = "attack_up"
		idle_name = "idle_up"
	anim_sprite.stop()
	if anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(anim_sprite):
		if anim_sprite.sprite_frames.has_animation(idle_name):
			anim_sprite.play(idle_name)
func update_visuals():
	if is_grabbed:
		modulate = Color(0.5, 0.5, 0.5)
	elif is_charging:
		modulate = Color(2.0, 1.2, 0.5)
	else:
		modulate = Color(1, 1, 1)

func add_buff(buff_name: String, value: float, duration_turns: int):
	SoundManager.play_sound(SoundManager.buffspell)
	active_buffs[buff_name] = duration_turns
	
	if buff_name == "damage_reduction":
		damage_reduction_rate = value
		self.is_shield_new = true
		if has_node("ShieldAnim"):
			$ShieldAnim.visible = true
			$ShieldAnim.play("ShieldAnim")
	if buff_name == "stun":
		self.stun_turns = duration_turns
	elif buff_name == "root":
		self.root_turns = duration_turns
		if is_instance_valid(current_wind_visual):
			current_wind_visual.queue_free()
			
		var effect = preload("res://spell_effect.tscn").instantiate()
		add_child(effect)
		effect.position = Vector2(0, -15)
		effect.z_index = 1
		effect.play("gio") 
		self.current_wind_visual = effect

func on_turn_end():
	if active_buffs.has("damage_reduction"):
		active_buffs["damage_reduction"] -= 1 
		
		if active_buffs["damage_reduction"] <= 0:
			active_buffs.erase("damage_reduction")
			damage_reduction_rate = 0.0
			if has_node("ShieldAnim"):
				$ShieldAnim.visible = false
				$ShieldAnim.stop()
				
	if stun_turns > 0:
		if stun_turns == 0:
			if is_instance_valid(current_wind_visual):
				current_wind_visual.queue_free()

func process_buffs():
	if active_buffs.has("burn"):
		take_damage(10)

	var expired_buffs = []
	for buff in active_buffs.keys():
		active_buffs[buff] -= 1
		if active_buffs[buff] <= 0:
			expired_buffs.append(buff)
			
	for buff in expired_buffs:
		active_buffs.erase(buff)
		if active_buffs.is_empty():
			modulate = Color(1, 1, 1)

func heal(amount):
	current_health += amount
	if current_health > max_health: 
		current_health = max_health
		
	if has_node("HealthBar"):
		get_node("HealthBar").value = current_health
