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
@onready var background =$Bg
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

func _ready():
	GamestateManager.stats_changed.connect(_on_stats_changed)
	GamestateManager.register_dialogue_node($".")
	GamestateManager.register_minigame_container($"../MinigameContainer")
	load_dialogue("res://dialogue/dialogue_data.json.txt")
	
	# ✅ เพิ่มบรรทัดนี้เพื่ออัพเดท UI ให้ตรงกับค่าใน GameManager
	update_initial_stats()
	
	show_event_by_id("Intro_1")

# ✅ เพิ่มฟังก์ชันใหม่
func update_initial_stats():
	# อัพเดท health, sanity, energy bars
	health_bar.value = GamestateManager.get_stat("health")
	sanity_bar.value = GamestateManager.get_stat("sanity")
	energy_bar.value = GamestateManager.get_stat("energy")
	
	# อัพเดท pow, agi, cha, int labels
	pow_label.text = str(GamestateManager.get_stat("pow"))
	agi_label.text = str(GamestateManager.get_stat("agi"))
	cha_label.text = str(GamestateManager.get_stat("cha"))
	int_label.text = str(GamestateManager.get_stat("int"))

# ✅ ฟังก์ชันที่จะถูกเรียกเมื่อ stats เปลี่ยน
func _on_stats_changed(stat_name: String, new_value: int):
	match stat_name:
		"health":
			health_bar.value = new_value
		"sanity":
			sanity_bar.value = new_value
		"energy":
			energy_bar.value = new_value
		"pow":
			pow_label.text = str(new_value)
		"agi":
			agi_label.text = str(new_value)
		"cha":
			cha_label.text = str(new_value)
		"int":
			int_label.text = str(new_value)

func load_dialogue(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var data = JSON.parse_string(text)
		
		# ✅ ถ้าได้ Array มาให้ wrap เป็น {"events": [...]}
		if typeof(data) == TYPE_ARRAY:
			dialogue_data = {"events": data}
			print("Auto-wrapped array. Loaded events:", data.size())
		elif typeof(data) == TYPE_DICTIONARY:
			dialogue_data = data
			print("Loaded events:", dialogue_data.get("events", []).size())
		else:
			print("JSON parse failed:", text)
		file.close()

func show_event_by_id(event_id: String):
	if !dialogue_data.has("events"):
		print("ERROR: No events in dialogue_data")
		return

	current_event = null
	for event in dialogue_data["events"]:
		if event["id"] == event_id:
			current_event = event
			break

	if current_event == null:
		print("ERROR: Event not found:", event_id)
		return

	# ✅ ตรวจว่าเป็น flagcheck หรือไม่
	if current_event["id"].begins_with("flagcheck"):
		var next_id = GamestateManager.process_flagcheck(current_event)
		if next_id != "":
			show_event_by_id(next_id)
		else:
			print("⚠️ No valid next event found for flagcheck:", current_event["id"])
		return

	name_label.text = current_event.get("name", "")
	full_text = current_event.get("dialogue", "")

	# ✅ เริ่มมินิเกม (ถ้ามี และไม่ใช่ empty string)
	if current_event.has("minigame_name") and current_event["minigame_name"] != "":
		var mg_name = current_event["minigame_name"]
		var mg_level = current_event.get("minigame_level", 1)
		
		# ✅ ซ่อนปุ่มทั้งหมดก่อนเริ่มมินิเกม
		A_button.hide()
		B_button.hide()
		
		GamestateManager.start_minigame({
			"name": mg_name,
			"level": mg_level
		})
		return

	# ... ส่วนที่เหลือเหมือนเดิม

	# เปลี่ยนฉาก / เอฟเฟกต์ / อนิเมชันอย่างปลอดภัย
	change_background(current_event.get("background", ""))
	play_effect(current_event.get("effect", ""))
	play_partner_animation(current_event.get("cha_sprite", ""))
	
	if current_event.has("ai_reaction") and Ai_anim:
		var ai_anim_name = current_event["ai_reaction"]
		if Ai_anim.sprite_frames.has_animation(ai_anim_name):
			Ai_anim.play(ai_anim_name)
		else:
			print("AI animation not found:", ai_anim_name)

	update_stats(current_event.get("stats", {}))
	
	# ✅ แก้ตรงนี้: ส่ง current_event เข้าไปตรงๆ แทนที่จะส่ง choices: {}
	update_choices()

	start_typing()

# ✅ เปลี่ยนฟังก์ชัน update_choices ให้อ่านจาก current_event
func update_choices():
	if current_event == null:
		A_button.hide()
		B_button.hide()
		return
	
	var has_next = (current_event.has("next") and current_event["next"] != "") or \
				   (current_event.has("next_A") and current_event["next_A"] != "") or \
				   (current_event.has("next_B") and current_event["next_B"] != "")
	
	# ✅ เช็คจาก "choice_A" ใน JSON
	if current_event.has("choice_A") and current_event["choice_A"] != "":
		A_button.text = current_event["choice_A"]
		A_button.show()
	elif has_next:
		A_button.text = "Next"
		A_button.show()
	else:
		A_button.hide()
	
	# ✅ เช็คจาก "choice_B" ใน JSON
	if current_event.has("choice_B") and current_event["choice_B"] != "":
		B_button.text = current_event["choice_B"]
		B_button.show()
	elif has_next:
		B_button.text = "Next"
		B_button.show()
	else:
		B_button.hide()

# ← ฟังก์ชันใหม่: เริ่มพิมพ์ตัวอักษร
func start_typing():
	is_typing = true
	dialogue_box.text = ""
	
	for i in range(full_text.length()):
		if !is_typing:  # ถ้ากด Next ระหว่างพิมพ์
			break
		dialogue_box.text += full_text[i]
		await get_tree().create_timer(typing_speed).timeout
	
	is_typing = false

# ← ฟังก์ชันใหม่: แสดงข้อความทั้งหมดทันที
func skip_typing():
	is_typing = false
	dialogue_box.text = full_text

func change_background(bg_name: String):
	if bg_name == "":  # ✅ เพิ่มการเช็ค empty string
		return
	if background.sprite_frames.has_animation(bg_name):
		background.play(bg_name)
	else:
		print("Background animation not found:", bg_name)

func play_partner_animation(anim_name: String):
	if anim_name == "":
		return
	if characters_anim.sprite_frames.has_animation(anim_name):
		characters_anim.play(anim_name)
	else:
		print("Animation not found:", anim_name)
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

func update_stats(stats: Dictionary):
	if stats.has("sanity"):
		sanity_bar.value += stats["sanity"]
	if stats.has("energy"):
		energy_bar.value += stats["energy"]
	if stats.has("cha"):
		var current_cha = int(cha_label.text if cha_label.text != "" else "0")
		cha_label.text = str(current_cha + stats["cha"])
		
func _on_choice_a_pressed():
	if is_typing:
		skip_typing()
		return
	
	if current_event == null:
		print("ERROR: current_event is null in choice A")
		return
	
	if current_event.has("rewards"):
		GamestateManager.apply_rewards(current_event["rewards"])
	
	# ✅ เช็ค empty string ด้วย
	if current_event.has("next_A") and current_event["next_A"] != "":
		var next_id = current_event["next_A"]
		if next_id == "RANDOM":
			GamestateManager.trigger_dynamic_event()
		else:
			show_event_by_id(next_id)
	elif current_event.has("next") and current_event["next"] != "":
		var next_id = current_event["next"]
		if next_id == "RANDOM":
			GamestateManager.trigger_dynamic_event()
		else:
			show_event_by_id(next_id)
	else:
		print("No next event for A")

func _on_choice_b_pressed():
	if is_typing:
		skip_typing()
		return
	
	if current_event == null:
		print("ERROR: current_event is null in choice B")
		return
	
	if current_event.has("rewards"):
		GamestateManager.apply_rewards(current_event["rewards"])
	
	# ✅ เช็ค empty string ด้วย
	if current_event.has("next_B") and current_event["next_B"] != "":
		var next_id = current_event["next_B"]
		if next_id == "RANDOM":
			GamestateManager.trigger_dynamic_event()
		else:
			show_event_by_id(next_id)
	elif current_event.has("next") and current_event["next"] != "":
		var next_id = current_event["next"]
		if next_id == "RANDOM":
			GamestateManager.trigger_dynamic_event()
		else:
			show_event_by_id(next_id)
	else:
		print("No next event for B")
