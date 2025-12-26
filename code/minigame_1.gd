extends Node2D

signal minigame_finished(success: bool, rewards: Dictionary)

@onready var player = $frog
@onready var Left_pos = $PlayerPosition/Left
@onready var Right_pos = $PlayerPosition/Right
@onready var Center_pos = $PlayerPosition/center
@onready var timer_label = $timer
@onready var scores_label = $scores
@onready var charges_bar = $TextureProgressBar
@onready var low_shoot_collision = $frog/low/CollisionShape2D 
@onready var mid_shoot_collision = $frog/mid/CollisionShape2D 
@onready var high_shoot_collision = $frog/high/CollisionShape2D
@onready var left_border = $border/left/CollisionShape2D
@onready var right_border = $border/right/CollisionShape2D
@onready var top_border = $border/top/CollisionShape2D
@onready var bottom_border = $border/bottom/CollisionShape2D
@onready var left_spawner = $Spawner/Left
@onready var right_spawner = $Spawner/Right

var current_pos = 1
var is_charging = false
var charging_up = true
var shooting = false

@export var firefly_scene: PackedScene

# ===== ตั้งค่าสำหรับดีบั๊ก =====
@export_group("Debug Settings")
@export var debug_mode: bool = false
@export_range(1, 5) var debug_level: int = 1
@export var auto_start: bool = false

var spawn_interval = 1.0
var max_fireflies = 10

var spawn_timer = 0.0
var fireflies = []

# ===== ระบบ Level =====
var current_level = 1
var score = 0
var game_time = 0.0
var level_time_limit = 30.0
var is_game_active = false

# Level Configuration
var level_configs = {
	1: {
		"time_limit": 30.0,
		"target_score": 10,
		"spawn_interval": 1.2,
		"max_fireflies": 8,
		"firefly_speed": 50.0,
		"description": "Easy - จับหิ่งห้อย 10 ตัว"
	},
	2: {
		"time_limit": 40.0,
		"target_score": 20,
		"spawn_interval": 1.0,
		"max_fireflies": 12,
		"firefly_speed": 70.0,
		"description": "Normal - จับหิ่งห้อย 20 ตัว"
	},
	3: {
		"time_limit": 45.0,
		"target_score": 30,
		"spawn_interval": 0.8,
		"max_fireflies": 15,
		"firefly_speed": 90.0,
		"description": "Hard - จับหิ่งห้อย 30 ตัว"
	},
	4: {
		"time_limit": 60.0,
		"target_score": 50,
		"spawn_interval": 0.6,
		"max_fireflies": 20,
		"firefly_speed": 110.0,
		"description": "Expert - จับหิ่งห้อย 50 ตัว"
	},
	5: {
		"time_limit": 50.0,
		"target_score": 40,
		"spawn_interval": 0.5,
		"max_fireflies": 25,
		"firefly_speed": 130.0,
		"description": "Master - จับหิ่งห้อย 40 ตัว (เร็วมาก!)"
	}
}
func _update_ui():
	"""อัปเดต UI"""
	var target = level_configs[current_level]["target_score"]
	scores_label.text = "Score: %d / %d" % [score, target]
	
	# แสดงเวลาที่เหลือ (นาที:วินาที ถ้ามากกว่า 60 วิ)
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	
	if game_time >= 60:
		timer_label.text = "Time: %d:%02d" % [minutes, seconds]
	else:
		timer_label.text = "Time: %.1fs" % game_time
	
	# เปลี่ยนสีเตือนถ้าเวลาเหลือน้อย
	if game_time <= 10:
		timer_label.modulate = Color.RED
	elif game_time <= 20:
		timer_label.modulate = Color.YELLOW
	else:
		timer_label.modulate = Color.WHITE

func _start_game():
	"""เริ่มเกม"""
	is_game_active = true
	game_time = level_time_limit
	score = 0
	spawn_timer = 0.0  # รีเซ็ต spawn timer
	
	# รีเซ็ต UI
	if timer_label:
		timer_label.modulate = Color.WHITE
	
	_update_ui()
	print("🎮 Game Started - Level %d" % current_level)

func _ready():
	charges_bar.value = 0
	player.play("default")
	
	# ===== โหมดดีบั๊ก =====
	if debug_mode:
		print("🐛 DEBUG MODE ENABLED")
		print("Press F5 to restart minigame")
		print("Press 1-5 to change level")
		if auto_start:
			setup({"level": debug_level})

func setup(data: Dictionary):
	"""เรียกจาก GamestateManager เพื่อตั้งค่า level"""
	current_level = int(data.get("level", 1))
	
	# ตรวจสอบว่า level ถูกต้องหรือไม่
	if not level_configs.has(current_level):
		current_level = 1
	
	_apply_level_config()
	_start_game()

func _apply_level_config():
	"""นำค่าจาก config มาใช้"""
	var config = level_configs[current_level]
	
	level_time_limit = config["time_limit"]
	spawn_interval = config["spawn_interval"]
	max_fireflies = config["max_fireflies"]
	
	print("Level %d: %s" % [current_level, config["description"]])


func _process(delta):
	# ===== Debug Controls =====
	if debug_mode:
		_handle_debug_input()
	
	if not is_game_active:
		return
	
	# ===== อัปเดตเวลา =====
	game_time -= delta
	if game_time <= 0:
		_end_game(false)
		return
	
	# ===== เช็คชนะ =====
	var target = level_configs[current_level]["target_score"]
	if score >= target:
		_end_game(true)
		return
	
	_update_ui()
	
	if shooting:
		return

	handle_move_input()
	handle_charge_input(delta)
	
	# ===== Spawn หิ่งห้อย =====
	spawn_timer += delta
	if spawn_timer >= spawn_interval and fireflies.size() < max_fireflies:
		spawn_timer = 0
		_spawn_firefly()

func _handle_debug_input():
	"""ควบคุมการดีบั๊ก"""
	# กด F5 เพื่อรีสตาร์ท
	if Input.is_action_just_pressed("ui_cancel"):  # ESC
		_restart_game()
	
	# กด 1-5 เพื่อเปลี่ยน level
	if Input.is_action_just_pressed("ui_page_up"):  # Page Up = เพิ่ม level
		debug_level = min(debug_level + 1, 5)
		_restart_game()
	elif Input.is_action_just_pressed("ui_page_down"):  # Page Down = ลด level
		debug_level = max(debug_level - 1, 1)
		_restart_game()
	
	# กด F1-F5 เพื่อเลือก level โดยตรง
	if Input.is_key_pressed(KEY_F1):
		debug_level = 1
		_restart_game()
	elif Input.is_key_pressed(KEY_F2):
		debug_level = 2
		_restart_game()
	elif Input.is_key_pressed(KEY_F3):
		debug_level = 3
		_restart_game()
	elif Input.is_key_pressed(KEY_F4):
		debug_level = 4
		_restart_game()
	elif Input.is_key_pressed(KEY_F5):
		debug_level = 5
		_restart_game()
	
	# กด Space ยาวๆ เพื่อเพิ่มคะแนน (โกง)
	if Input.is_key_pressed(KEY_SPACE) and Input.is_key_pressed(KEY_SHIFT):
		score += 1

func _restart_game():
	"""รีสตาร์ทเกมด้วย level ปัจจุบัน"""
	# ลบหิ่งห้อยเก่า
	for ff in fireflies:
		if is_instance_valid(ff):
			ff.queue_free()
	fireflies.clear()
	
	setup({"level": debug_level})
	print("🔄 Restarted Level %d" % debug_level)

func _spawn_firefly():
	if not firefly_scene:
		print("ERROR: firefly_scene not set!")
		return
		
	var ff = firefly_scene.instantiate()
	
	# ตำแหน่ง spawn แบบสุ่ม
	var min_x = left_spawner.position.x
	var max_x = right_spawner.position.x
	var x = randf_range(min_x, max_x) + randf_range(-25, 25)
	var y = Center_pos.position.y + randf_range(-25, 25)
	
	ff.position = Vector2(x, y)
	
	# ตั้งความเร็วตาม level
	if ff.has_method("set_speed"):
		var speed = level_configs[current_level]["firefly_speed"]
		ff.set_speed(speed)
	
	add_child(ff)
	fireflies.append(ff)

func add_score(points: int):
	"""เรียกจาก firefly เมื่อโดนยิง"""
	score += points
	_update_ui()  # ⬅️ อัปเดต UI ทันทีที่ได้คะแนน
	
	# เช็คชนะทันทีหลังเพิ่มคะแนน
	var target = level_configs[current_level]["target_score"]
	if score >= target and is_game_active:
		# หน่วงเวลานิดนึงให้เห็นคะแนนเต็ม
		await get_tree().create_timer(0.3).timeout
		_end_game(true)
	
	print("Score: %d / %d" % [score, target])

func _end_game(success: bool):
	"""จบเกม"""
	is_game_active = false
	
	# ทำลายหิ่งห้อยที่เหลือ
	for ff in fireflies:
		if is_instance_valid(ff):
			ff.queue_free()
	fireflies.clear()
	
	# คำนวณรางวัล
	var rewards = _calculate_rewards(success)
	
	# แสดงผลลัพธ์
	if success:
		print("✅ LEVEL %d CLEAR! Score: %d" % [current_level, score])
	else:
		print("❌ TIME'S UP! Score: %d" % score)
	
	# ===== โหมดดีบั๊ก: ไม่ส่ง signal =====
	if debug_mode:
		print("🐛 Debug Mode: Press ESC to restart")
		return
	
	# ส่งสัญญาณกลับไปที่ GamestateManager
	emit_signal("minigame_finished", success, rewards)
	
func _calculate_rewards(success: bool) -> Dictionary:
	"""คำนวณรางวัลตาม level และผลการเล่น"""
	var rewards = {}
	
	if success:
		# คำนวณเปอร์เซ็นต์ที่ทำได้
		var target = level_configs[current_level]["target_score"]
		var score_percent = (float(score) / float(target)) * 100.0
		
		# รางวัลพื้นฐานตาม level
		var base_rewards = {}
		match current_level:
			1:
				base_rewards = {"agi": 2, "energy": -5}
			2:
				base_rewards = {"agi": 3, "int": 1, "energy": -10}
			3:
				base_rewards = {"agi": 5, "int": 2, "energy": -15}
			4:
				base_rewards = {"agi": 7, "int": 3, "pow": 1, "energy": -20}
			5:
				base_rewards = {"agi": 10, "int": 5, "pow": 2, "energy": -25}
		
		rewards = base_rewards.duplicate()
		
		# ⭐ โบนัสถ้าทำได้ดี (คะแนนเกิน 150% ของเป้าหมาย)
		if score_percent >= 150:
			rewards["health"] = 50  # ฟื้น HP 50%
			rewards["sanity"] = 20
			print("🌟 PERFECT! Bonus: +50% HP, +20 Sanity")
		# ⭐ โบนัสปานกลาง (คะแนนเกิน 120%)
		elif score_percent >= 120:
			rewards["health"] = 30  # ฟื้น HP 30%
			print("✨ GREAT! Bonus: +30% HP")
		# ⭐ ผ่านแบบพอดี (100-119%)
		else:
			print("✅ CLEAR!")
		
		# ไอเทมพิเศษสำหรับ level 5 perfect
		if current_level == 5 and score_percent >= 150:
			if not rewards.has("items"):
				rewards["items"] = []
			rewards["items"].append("golden_firefly")
			print("🏆 Got Golden Firefly!")
		
		print("Final Score: %d / %d (%.1f%%)" % [score, target, score_percent])
		
	else:
		# ล้มเหลว แต่ได้บางอย่างตามคะแนนที่ทำได้
		var target = level_configs[current_level]["target_score"]
		var score_percent = (float(score) / float(target)) * 100.0
		
		if score_percent >= 80:
			# เกือบผ่าน ได้รางวัลบางส่วน
			rewards = {"agi": 1, "energy": -15}
			print("😓 Almost there! (80%+)")
		elif score_percent >= 50:
			# ผ่านครึ่ง
			rewards = {"energy": -10}
			print("😅 Not bad! (50%+)")
		else:
			# แย่มาก
			rewards = {"energy": -20, "sanity": -10}
			print("😰 Try harder next time")
	
	return rewards


func handle_move_input():
	if Input.is_action_just_pressed("ui_left"):
		if current_pos > 0:
			current_pos -= 1
			_update_player_position()
	elif Input.is_action_just_pressed("ui_right"):
		if current_pos < 2:
			current_pos += 1
			_update_player_position()

func _update_player_position():
	match current_pos:
		0:
			player.position = Left_pos.position
		1:
			player.position = Center_pos.position
		2:
			player.position = Right_pos.position

func handle_charge_input(delta):
	if Input.is_action_just_pressed("ui_accept"):
		if not is_charging:
			is_charging = true
			charging_up = true
		else:
			_perform_shoot()
			is_charging = false
			charges_bar.value = 0

	if is_charging:
		_update_charge(delta)

func _update_charge(delta):
	var speed = 0.0
	if charging_up:
		if charges_bar.value < 50:
			speed = 100 * delta * 3
		elif charges_bar.value < 75:
			speed = 100 * delta * 2
		else:
			speed = 100 * delta * 1
		charges_bar.value += speed
		if charges_bar.value >= 100:
			charges_bar.value = 100
			charging_up = false
	else:
		if charges_bar.value > 80:
			speed = 100 * delta * 3
		elif charges_bar.value > 60:
			speed = 100 * delta * 2
		else:
			speed = 100 * delta * 1
		charges_bar.value -= speed
		if charges_bar.value <= 0:
			charges_bar.value = 0
			charging_up = true

func _perform_shoot():
	shooting = true

	var value = charges_bar.value
	if value < 60:
		player.play("low_shoot")
		low_shoot_collision.disabled = false
	elif value < 80:
		player.play("middle_shoot")
		mid_shoot_collision.disabled = false
	else:
		player.play("high_shoot")
		high_shoot_collision.disabled = false

	await player.animation_finished
	_reset_collisions()
	shooting = false
	
func _reset_collisions():
	low_shoot_collision.disabled = true
	mid_shoot_collision.disabled = true
	high_shoot_collision.disabled = true
	player.animation = "default"

# ===== Collision Handlers =====

func _on_left_area_entered(area):
	if area.is_in_group("prey"):
		area.queue_free()
	if fireflies.has(area):
		fireflies.erase(area)

func _on_right_area_entered(area):
	if area.is_in_group("prey"):
		area.queue_free()
	if fireflies.has(area):
		fireflies.erase(area)

func _on_top_area_entered(area):
	if area.is_in_group("prey"):
		area.queue_free()
	if fireflies.has(area):
		fireflies.erase(area)

func _on_bottom_area_entered(area):
	if area.is_in_group("prey"):
		area.queue_free()
	if fireflies.has(area):
		fireflies.erase(area)

func _on_high_area_entered(area):
	if area.is_in_group("prey") and area.has_method("_on_hit"):
		area._on_hit()
		add_score(1)  # เพิ่มคะแนน
	if fireflies.has(area):
		fireflies.erase(area)

func _on_mid_area_entered(area):
	if area.is_in_group("prey") and area.has_method("_on_hit"):
		area._on_hit()
		add_score(1)
	if fireflies.has(area):
		fireflies.erase(area)

func _on_low_area_entered(area):
	if area.is_in_group("prey") and area.has_method("_on_hit"):
		area._on_hit()
		add_score(1)
	if fireflies.has(area):
		fireflies.erase(area)
