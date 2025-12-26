extends Node2D

@onready var health_bar = $Ui/health_bar
@onready var sanity_bar = $Ui/sanity_bar
@onready var energy_bar = $Ui/energy_bar
@onready var pow_label = $Ui/stats_label/pow
@onready var agi_label = $Ui/stats_label/agi
@onready var cha_label = $Ui/stats_label/cha
@onready var int_label = $Ui/stats_label/int
@onready var Ai_anim = $Ai
@onready var characters_anim = $Cha
@onready var background = $Bg
@onready var name_label = $txt_box/name
@onready var dialogue_box = $txt_box/Dialogue
@onready var A_button = $buttons/Choice_A
@onready var B_button = $buttons/Choice_B
@onready var effect_label_1 = $"Ui/effect_label/1"
@onready var effect_label_2 = $"Ui/effect_label/2"

var dialogue_data = {}
var current_event = null
var is_typing = false
var full_text = ""
var typing_speed = 0.05

signal event_finished  # ← เพิ่ม signal สำหรับบอกว่า event จบแล้ว

func _ready():
	load_dialogue("res://dialogues/dialogue_data.json")
	update_ui_from_state()

func load_dialogue(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var data = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			dialogue_data = data
		else:
			print("JSON parse failed:", text)
		file.close()

func show_event_by_id(event_id: String):
	if !dialogue_data.has("events"):
		return
	
	current_event = null
	
	for event in dialogue_data["events"]:
		if event["id"] == event_id:
			current_event = event
			break
	
	if current_event == null:
		print("Event not found:", event_id)
		return
	
	name_label.text = current_event["name"]
	full_text = current_event["dialogue"]
	
	change_background(current_event["background"])
	
	play_effect(current_event["effect"])
	play_partner_animation(current_event["emotion"], current_event["name"])
	
	# ← แทนที่จะอัพเดต UI เอง เราจะส่งค่าไปยัง StateManager
	apply_stats_to_state(current_event.get("stats", {}))
	
	update_choices(current_event.get("choices", {}))
	start_typing()

# ← ฟังก์ชันใหม่: ส่งค่า stats ไปยัง StateManager
func apply_stats_to_state(stats: Dictionary):
	for stat_name in stats.keys():
		StateManager.modify_stat(stat_name, stats[stat_name])
	
	# อัพเดต UI หลังจากเปลี่ยนค่า
	update_ui_from_state()

# ← ฟังก์ชันใหม่: อัพเดต UI จากข้อมูลใน StateManager
func update_ui_from_state():
	health_bar.value = StateManager.get_stat("health")
	sanity_bar.value = StateManager.get_stat("sanity")
	energy_bar.value = StateManager.get_stat("energy")
	pow_label.text = str(StateManager.get_stat("pow"))
	agi_label.text = str(StateManager.get_stat("agi"))
	cha_label.text = str(StateManager.get_stat("cha"))
	int_label.text = str(StateManager.get_stat("int"))

func start_typing():
	is_typing = true
	dialogue_box.text = ""
	
	for i in range(full_text.length()):
		if !is_typing:
			break
		dialogue_box.text += full_text[i]
		await get_tree().create_timer(typing_speed).timeout
	
	is_typing = false

func skip_typing():
	is_typing = false
	dialogue_box.text = full_text

func change_background(bg_name: String):
	if background.sprite_frames.has_animation(bg_name):
		background.play(bg_name)
	else:
		print("Background animation not found:", bg_name)

func play_partner_animation(emotion: String, speaker: String = ""):
	var anim_name = ""
	if speaker != "":
		anim_name = "%s_%s" % [speaker, emotion]
	else:
		anim_name = emotion
	
	if characters_anim.sprite_frames.has_animation(anim_name):
		characters_anim.play(anim_name)
	else:
		print("Animation not found for partner:", anim_name)
		if characters_anim.sprite_frames.has_animation("idle"):
			characters_anim.play("idle")

func play_effect(effect_name: String):
	match effect_name:
		"shake":
			effect_label_1.text = "💢"
		"calm":
			effect_label_1.text = "✨"
		_:
			effect_label_1.text = ""

func update_choices(choices: Dictionary):
	# ตรวจสอบว่ามี next event (next, next_A, หรือ next_B) ที่ต้องไปต่อหรือไม่
	var has_next_segment = current_event.has("next") or current_event.has("next_A") or current_event.has("next_B")

	# ซ่อนปุ่มทั้งหมดไว้ก่อน
	A_button.hide()
	B_button.hide()

	if choices.has("A"):
		# มี Choice A/B จริงๆ (ตัวเลือกการตัดสินใจ)
		A_button.text = choices["A"]
		A_button.show()
	else:
		# ไม่มี Choice A/B
		if has_next_segment:
			# แต่มี next segment ให้ไปต่อ (ปุ่ม Next)
			A_button.text = "Next"
			A_button.show()
			# ในกรณีนี้ ไม่ต้องแสดง B_button
			
	# ตรวจสอบปุ่ม B (ถ้ามี Choice B จริงๆ)
	if choices.has("B"):
		B_button.text = choices["B"]
		B_button.show()
		# ถ้ามี B เราจะแสดง A (Choice A) ด้วย ไม่ใช่ "Next"

func _on_choice_a_pressed():
	if is_typing:
		skip_typing()
		return
	
	if current_event.has("next_A"):
		show_event_by_id(current_event["next_A"])
	elif current_event.has("next"):
		show_event_by_id(current_event["next"])
	else:
		# ← ถ้าไม่มี next = event จบแล้ว
		print("Event chain finished")
		event_finished.emit()

func _on_choice_b_pressed():
	if is_typing:
		skip_typing()
		return
	
	if current_event.has("next_B"):
		show_event_by_id(current_event["next_B"])
	elif current_event.has("next"):
		show_event_by_id(current_event["next"])
	else:
		print("Event chain finished")
		event_finished.emit()
