extends Node

# Game States
enum GameState {
	DIALOGUE,
	MINIGAME,
	PAUSED
}

# Player Stats
var player_stats = {
	"health": 100,
	"sanity": 100,
	"energy": 100,
	"pow": 5,
	"agi": 5,
	"cha": 5,
	"int": 5
}

# Inventory
var inventory = []

# Game Progress
var current_dialogue_id = "Intro_1" 
var completed_events = []
var game_flags = {}

# State Management
var current_state = GameState.DIALOGUE
var minigame_scene_path = "res://scenes/minigame_1.tscn"
var active_minigame_instance = null

# Reference to Main Scene nodes
var dialogue_node = null
var minigame_container = null

# Signals
signal stats_changed(stat_name, new_value)
signal state_changed(new_state)
signal minigame_completed(success, rewards)

func _ready():
	print("GameManager Initialized")

# ============ Scene References ============

func register_dialogue_node(node):
	dialogue_node = node

func register_minigame_container(node):
	minigame_container = node

# ============ State Management ============

func change_state(new_state: GameState):
	current_state = new_state
	emit_signal("state_changed", new_state)
	print("State changed: ", GameState.keys()[new_state])

# ============ Minigame Management ============

func start_minigame(minigame_data: Dictionary = {}):
	if active_minigame_instance != null:
		print("Minigame already active!")
		return
	
	change_state(GameState.MINIGAME)

	var mg_name = minigame_data.get("name", "")
	if mg_name == "":
		print("ERROR: Missing minigame name!")
		change_state(GameState.DIALOGUE)
		return

	var scene_path = "res://scenes/" + mg_name + ".tscn"
	var minigame_scene = load(scene_path)

	if minigame_scene == null:
		print("ERROR: Cannot load minigame scene at path:", scene_path)
		change_state(GameState.DIALOGUE)
		return

	# instantiate ก่อน
	active_minigame_instance = minigame_scene.instantiate()

	if minigame_container:
		minigame_container.add_child(active_minigame_instance) # add เข้า container ก่อน

		# ตั้งตำแหน่ง spawn ถ้ามี
		if minigame_container.has_node("MinigameSpawnPos"):
			var spawn_pos = minigame_container.get_node("MinigameSpawnPos")
			active_minigame_instance.position = spawn_pos.global_position

	else:
		print("ERROR: Minigame container not registered!")


	# ✅ ส่งข้อมูล setup ถ้ามี
	if active_minigame_instance.has_method("setup"):
		active_minigame_instance.setup({"level": minigame_data.get("level", 1)})

	# ✅ เชื่อมสัญญาณ
	if active_minigame_instance.has_signal("minigame_finished"):
		active_minigame_instance.minigame_finished.connect(_on_minigame_finished)
	else:
		print("ERROR: Minigame container not registered!")


func _on_minigame_finished(success: bool, rewards: Dictionary = {}):
	"""เรียกจาก Minigame เมื่อจบ"""
	end_minigame(success, rewards)

func end_minigame(success: bool, rewards: Dictionary = {}):

	if success:
		apply_rewards(rewards)
	
	# ลบ minigame instance
	if active_minigame_instance:
		active_minigame_instance.queue_free()
		active_minigame_instance = null
	
	# แสดง dialogue กลับมา
	if dialogue_node:
		dialogue_node.visible = true
	
	change_state(GameState.DIALOGUE)
	emit_signal("minigame_completed", success, rewards)
	
	# ✅ เลือก event ถัดไปตาม success
	var next_event_id = ""
	var current_event = dialogue_node.current_event
	
	if current_event:
		if success and current_event.has("next_A") and current_event["next_A"] != "":
			next_event_id = current_event["next_A"]
		elif not success and current_event.has("next_B") and current_event["next_B"] != "":
			next_event_id = current_event["next_B"]
		
		if next_event_id != "":
			dialogue_node.show_event_by_id(next_event_id)

func modify_stat(stat_name: String, amount: int):
	if player_stats.has(stat_name):
		player_stats[stat_name] += amount
		player_stats[stat_name] = clamp(player_stats[stat_name], 0, 100)
		emit_signal("stats_changed", stat_name, player_stats[stat_name])

func set_stat(stat_name: String, value: int):
	if player_stats.has(stat_name):
		player_stats[stat_name] = value
		emit_signal("stats_changed", stat_name, value)

func get_stat(stat_name: String) -> int:
	return player_stats.get(stat_name, 0)

# ============ Inventory Management ============

func add_item(item_id: String):
	inventory.append(item_id)
	print("Added item: ", item_id)

func remove_item(item_id: String):
	var index = inventory.find(item_id)
	if index != -1:
		inventory.remove_at(index)
		print("Removed item: ", item_id)

func has_item(item_id: String) -> bool:
	return inventory.has(item_id)

# ============ Game Flags ============

func set_flag(flag_name: String, value):
	game_flags[flag_name] = value
	print("Flag set: ", flag_name, " = ", value)

func get_flag(flag_name: String, default_value = false):
	return game_flags.get(flag_name, default_value)

func has_flag(flag_name: String) -> bool:
	return game_flags.has(flag_name)

# ============ Event Management ============

func mark_event_completed(event_id: String):
	if !completed_events.has(event_id):
		completed_events.append(event_id)

func is_event_completed(event_id: String) -> bool:
	return completed_events.has(event_id)

# ============ Rewards ============
func apply_rewards(rewards):
	# ✅ ถ้า rewards เป็น String → แปลงเป็น Dictionary
	if typeof(rewards) == TYPE_STRING:
		# แทนที่ curly quotes ด้วย straight quotes
		var cleaned = rewards.replace(""", "\"").replace(""", "\"")
		rewards = JSON.parse_string(cleaned)
		
		if rewards == null:
			print("ERROR: Cannot parse rewards string:", rewards)
			return
	
	# ✅ ถ้า rewards ไม่ใช่ Dictionary → ยกเลิก
	if typeof(rewards) != TYPE_DICTIONARY:
		print("ERROR: rewards is not a Dictionary")
		return
	
	# Stats
	for stat in ["health", "sanity", "energy", "pow", "agi", "cha", "int"]:
		if rewards.has(stat):
			modify_stat(stat, rewards[stat])
	
	# Items
	if rewards.has("items"):
		for item in rewards["items"]:
			add_item(item)
	
	# Flags
	if rewards.has("flags"):
		for flag_name in rewards["flags"]:
			set_flag(flag_name, rewards["flags"][flag_name])
	
	# ✅ Force update UI
	if dialogue_node and dialogue_node.has_method("update_initial_stats"):
		dialogue_node.update_initial_stats()

# ============ Save/Load ============

func save_game():
	var save_data = {
		"player_stats": player_stats,
		"inventory": inventory,
		"current_dialogue_id": current_dialogue_id,
		"completed_events": completed_events,
		"game_flags": game_flags
	}
	
	var save_file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()
		print("Game saved!")

func load_game():
	var save_file = FileAccess.open("user://savegame.save", FileAccess.READ)
	if save_file:
		var save_data = JSON.parse_string(save_file.get_as_text())
		if save_data:
			player_stats = save_data.get("player_stats", player_stats)
			inventory = save_data.get("inventory", [])
			current_dialogue_id = save_data.get("current_dialogue_id", "intro_1")
			completed_events = save_data.get("completed_events", [])
			game_flags = save_data.get("game_flags", {})
			print("Game loaded!")
		save_file.close()
		
func trigger_dynamic_event():
	# อ่านค่าความสัมพันธ์ของแต่ละคน
	var rin = get_flag("Rin", 0)
	var mali = get_flag("Mali", 0)
	var saya = get_flag("Saya", 0)
	
	# หาค่ามากสุดและน้อยสุด
	var max_value = max(rin, mali, saya)
	var min_value = min(rin, mali, saya)
		
	var chosen_event = ""
	var event_candidates = []

		# 1. เงื่อนไขค่าต่ำ (สำคัญที่สุด ถ้าไม่สนใครเลย)
	if max_value < 20:
			event_candidates = ["neutral_event", "bad_luck"]
		# 2. เงื่อนไขสมดุล (สำคัญรองลงมา ถ้าความสัมพันธ์เท่ากันหมด)
	elif abs(rin - mali) < 5 and abs(rin - saya) < 5:
			event_candidates = ["group_event", "balanced_scene"]
		# 3. เงื่อนไขค่าสูง (เลือกคนที่มีค่าสูงสุด)
	elif max_value == rin:
			event_candidates = ["rin_good", "rin_special"]
	elif max_value == mali:
			event_candidates = ["mali_good", "mali_special"]
	elif max_value == saya:
			event_candidates = ["saya_good", "saya_special"]
	
	chosen_event = _get_random_event(event_candidates)
	# ส่งอีเวนต์นี้ไปยัง DialogueManager
	if chosen_event != "":
		if dialogue_node:
			dialogue_node.show_event_by_id(chosen_event)
			print("Triggered event:", chosen_event)
	else:
		print("No suitable event found.")

	# ============ Flag Check System ============
func process_flagcheck(event: Dictionary) -> String:
	if !event.has("condition_flag") or !event.has("condition_operator"):
		print("⚠️ Invalid flagcheck event:", event)
		return event.get("next", "")
	
	var flag_name = event["condition_flag"]
	var op = event["condition_operator"]
	var value = int(event.get("condition_value", 0))
	var flag_val = int(get_flag(flag_name, 0))
	
	var result := false
	match op:
		">": result = flag_val > value
		">=": result = flag_val >= value
		"<": result = flag_val < value
		"<=": result = flag_val <= value
		"==": result = flag_val == value
		"!=": result = flag_val != value
	
	if result:
		return event.get("next_A", "")
	else:
		return event.get("next_B", "")


# ยูทิลิตี้เล็ก ๆ สำหรับสุ่มจากรายการ
func _get_random_event(event_list: Array) -> String:
	if event_list.is_empty():
		return ""
		print("no random event")
	return event_list[randi() % event_list.size()]

