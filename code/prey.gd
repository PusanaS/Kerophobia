extends Area2D

@onready var sprite = $Minigame1Fireflly
@onready var collision = $CollisionShape2D

var velocity = Vector2.ZERO
var speed = 50
var modulate_speed = 3.0
var time_passed = 0.0

func set_speed(new_speed: float):
	speed = new_speed

func _ready():
	add_to_group("prey")
	randomize()
	_set_random_velocity()
	sprite.modulate.a = randf_range(0.5, 1.0) # ความสว่างสุ่มเริ่มต้น

func _process(delta):
	# เก็บเวลา
	time_passed += delta

	# แว้บสลับความสว่าง
	var alpha = 0.5 + 0.5 * sin(time_passed * modulate_speed * 10.0)
	sprite.modulate.a = alpha

	# เคลื่อนที่
	position += velocity * delta


	# เปลี่ยนความเร็วเล็กน้อยแบบสุ่มเพื่อความสมจริง
	if randi() % 100 < 2:
		_set_random_velocity()

func _set_random_velocity():
	# เคลื่อนที่ซ้ายขวา + ขึ้นลงแบบสุ่ม
	velocity = Vector2(randf_range(-speed, speed), randf_range(-speed, speed))

func _on_hit():
	# เพิ่มคะแนน
	if get_parent().has_method("add_score"):
		get_parent().add_score(1)
	queue_free()
