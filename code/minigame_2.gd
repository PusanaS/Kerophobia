extends Node2D

# Node References
@onready var bar1 = $bar1
@onready var bar2 = $bar2
@onready var teacher_sprite = $teacher
@onready var ai_sprite = $Ai
@onready var ball = $Label
@onready var bounce_area_top_collision = $bounce_area/CollisionShape2D
@onready var bounce_area_bottom_collision = $bounce_area/CollisionShape2D2
@onready var player_dmg_collision = $player_dmg/CollisionShape2D
@onready var teacher_dmg_collision = $teacher_dmg/CollisionShape2D
@onready var ball_spawn_area = $ball_spawn_area

# Game Variables
var ball_velocity = Vector2(120, 60)
var teacher_speed = 250
var player_speed = 400
var topics = ["vocab", "grammar", "pronounce", "reading", "writing", "listening"]
var current_topic = "vocab"
var max_ball_speed = 300  # ความเร็วสูงสุดของบอล
var base_speed = 120  # ความเร็วพื้นฐาน

# Score
var player_score = 0
var teacher_score = 0

# Boundary limits
var top_boundary = 0
var bottom_boundary = 0

# Original sprite positions
var teacher_original_y = 0
var ai_original_y = 0

# Signal
signal minigame_finished(success: bool, rewards: Dictionary)

func _ready():
	randomize()
	setup_boundaries()
	setup_ball()
	setup_signals()
	
	# เก็บตำแหน่งเริ่มต้นของ sprites
	if teacher_sprite:
		teacher_original_y = teacher_sprite.position.y
	if ai_sprite:
		ai_original_y = ai_sprite.position.y

func setup_boundaries():
	# คำนวณขอบเขตจาก bounce area collisions
	if bounce_area_top_collision:
		var shape = bounce_area_top_collision.shape
		if shape is RectangleShape2D:
			var top_pos = bounce_area_top_collision.global_position
			var half_height = shape.size.y / 2
			top_boundary = top_pos.y + half_height
	
	if bounce_area_bottom_collision:
		var shape = bounce_area_bottom_collision.shape
		if shape is RectangleShape2D:
			var bottom_pos = bounce_area_bottom_collision.global_position
			var half_height = shape.size.y / 2
			bottom_boundary = bottom_pos.y - half_height

func setup_ball():
	# ตั้งค่าบอลเริ่มต้น
	ball.text = current_topic
	
	# วางบอลที่ spawn area
	var spawn_pos = ball_spawn_area.global_position
	ball.position = spawn_pos
	
	# ใช้ความเร็วพื้นฐานที่สม่ำเสมอ
	ball_velocity.x = base_speed * (1 if randf() > 0.5 else -1)
	ball_velocity.y = randf_range(-base_speed * 0.5, base_speed * 0.5)

func setup_signals():
	# เชื่อมต่อ signals สำหรับบาร์
	if bar1.has_signal("area_entered"):
		bar1.area_entered.connect(_on_teacher_bar_hit)
	if bar2.has_signal("area_entered"):
		bar2.area_entered.connect(_on_player_bar_hit)
	
	# สำหรับ damage zones
	var player_dmg = get_node_or_null("player_dmg")
	var teacher_dmg = get_node_or_null("teacher_dmg")
	
	if player_dmg and player_dmg.has_signal("area_entered"):
		player_dmg.area_entered.connect(_on_player_dmg)
	if teacher_dmg and teacher_dmg.has_signal("area_entered"):
		teacher_dmg.area_entered.connect(_on_teacher_dmg)
	
	# เชื่อมต่อ signals สำหรับ bounce areas
	var bounce_area = get_node_or_null("bounce_area")
	if bounce_area and bounce_area.has_signal("area_entered"):
		bounce_area.area_entered.connect(_on_bounce_area_hit)

func _process(delta):
	update_ball(delta)
	update_teacher_ai(delta)
	update_player_input(delta)

# ===== BALL MOVEMENT =====
func update_ball(delta):
	ball.position += ball_velocity * delta

# ===== TEACHER AI =====
func update_teacher_ai(delta):
	if not bar1 or not ball:
		return
	
	# AI ตามบอล (ขึ้น-ลง)
	var target_y = ball.position.y
	
	if abs(bar1.position.y - target_y) > 10:
		if bar1.position.y < target_y:
			bar1.position.y += teacher_speed * delta
		else:
			bar1.position.y -= teacher_speed * delta
	
	# จำกัดไม่ให้ข้ามขอบเขต
	if top_boundary > 0 and bottom_boundary > 0:
		bar1.position.y = clamp(bar1.position.y, top_boundary, bottom_boundary)
	
	# อัปเดตตำแหน่ง sprite ครูให้ตามบาร์
	if teacher_sprite:
		teacher_sprite.position.x = bar1.position.x

# ===== PLAYER INPUT =====
func update_player_input(delta):
	if not bar2:
		return
	
	var new_y = bar2.position.y
	var move_amount = player_speed * delta
	
	# คำนวณตำแหน่งใหม่
	if Input.is_action_pressed("ui_left"):
		new_y -= move_amount
	if Input.is_action_pressed("ui_right"):
		new_y += move_amount
	
	# จำกัดไม่ให้ข้ามขอบเขต
	if top_boundary > 0 and bottom_boundary > 0:
		new_y = clamp(new_y, top_boundary, bottom_boundary)
	
	bar2.position.y = new_y
	
	# อัปเดตตำแหน่ง sprite ผู้เล่นให้ตามบาร์
	if ai_sprite:
		ai_sprite.position.x = bar2.position.x

# ===== COLLISION HANDLERS =====
func _on_teacher_bar_hit(area):
	# เมื่อบอลชนบาร์ครู
	if area.get_parent() == ball or area == ball:
		bounce_from_teacher()
		play_jump_animation(teacher_sprite, teacher_original_y)

func _on_player_bar_hit(area):
	# เมื่อบอลชนบาร์ผู้เล่น
	if area.get_parent() == ball or area == ball:
		bounce_from_player()
		play_jump_animation(ai_sprite, ai_original_y)

func _on_bounce_area_hit(area):
	# เมื่อบอลชน bounce area (บนหรือล่าง)
	if area.get_parent() == ball or area == ball:
		# เด้งในแนวตั้ง
		ball_velocity.y = -ball_velocity.y
		# เพิ่มความสุ่มเล็กน้อย
		ball_velocity.x += randf_range(-20, 20)
		clamp_ball_velocity()

# ===== JUMP ANIMATION =====
func play_jump_animation(sprite, original_y):
	if not sprite:
		return
	
	# สร้าง Tween สำหรับแอนิเมชันกระโดด
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# กระโดดขึ้น
	tween.tween_property(sprite, "position:y", original_y - 30, 0.15)
	# ลงกลับตำแหน่งเดิม
	tween.tween_property(sprite, "position:y", original_y, 0.15)

# ===== จำกัดความเร็วสูงสุด =====
func clamp_ball_velocity():
	var current_speed = ball_velocity.length()
	if current_speed > max_ball_speed:
		ball_velocity = ball_velocity.normalized() * max_ball_speed

func bounce_from_teacher():
	# เปลี่ยนหัวข้อเมื่อเด้งจากครู
	current_topic = topics[randi() % topics.size()]
	ball.text = current_topic
	
	# กลับทิศทางแนวนอน
	ball_velocity.x = -ball_velocity.x
	# เพิ่มความสุ่มในแนวตั้งแต่ลดลง
	ball_velocity.y += randf_range(-30, 30)
	
	# เพิ่มความเร็วเล็กน้อย (5% แทน 20%)
	ball_velocity = ball_velocity * 1.05
	
	# จำกัดความเร็วสูงสุด
	clamp_ball_velocity()

func bounce_from_player():
	# กลับทิศทางแนวนอน
	ball_velocity.x = -ball_velocity.x
	# เพิ่มความสุ่มในแนวตั้งแต่ลดลง
	ball_velocity.y += randf_range(-30, 30)
	
	# เพิ่มความเร็วเล็กน้อย (5% แทน 20%)
	ball_velocity = ball_velocity * 1.05
	
	# จำกัดความเร็วสูงสุด
	clamp_ball_velocity()

# ===== DAMAGE ZONES =====
func _on_player_dmg(area):
	if area.get_parent() == ball or area == ball:
		teacher_score += 1
		print("Teacher Score: ", teacher_score)
		reset_ball()
		check_game_end()

func _on_teacher_dmg(area):
	if area.get_parent() == ball or area == ball:
		player_score += 1
		print("Player Score: ", player_score)
		reset_ball()
		check_game_end()

# ===== RESET BALL =====
func reset_ball():
	# รีเซ็ตบอลไปยังตำแหน่งสุ่มใน ball_spawn_area
	var spawn_pos = ball_spawn_area.position
	ball.position = spawn_pos
	
	# ใช้ความเร็วพื้นฐานเหมือนตอนเริ่มเกม
	ball_velocity.x = -base_speed  # ไปทางซ้ายเสมอ
	ball_velocity.y = randf_range(-base_speed * 0.5, base_speed * 0.5)
	
	# รีเซ็ตหัวข้อ
	current_topic = topics[randi() % topics.size()]
	ball.text = current_topic

func _on_bar_2_area_area_shape_entered(area_rid, area, area_shape_index, local_shape_index):
	_on_player_bar_hit(area)

func _on_bar_1_area_area_shape_entered(area_rid, area, area_shape_index, local_shape_index):
	_on_teacher_bar_hit(area)

# ===== CHECK GAME END =====
func check_game_end():
	if player_score >= 9:
		end_game(true)
	elif teacher_score >= 9:
		end_game(false)

# ===== END GAME =====
func end_game(success: bool):
	var rewards = {}
	
	if success:
		rewards = {"sanity": 10, "energy": 5, "cha": 2}
		print("Player wins!")
	else:
		rewards = {"sanity": -5, "energy": -3}
		print("Teacher wins!")
	
	emit_signal("minigame_finished", success, rewards)
