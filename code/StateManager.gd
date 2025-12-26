# StateManager.gd - ใช้เป็น Singleton (Autoload)
extends Node

# ----- สถานะของเกม -----
enum GameState {
	INTRO,
	MORNING_EVENT,
	MORNING_CLASS,
	LUNCH_BREAK,
	EVENING_CLASS,
	NIGHT_EVENT,
	WEEKEND_EVENT,
	GAME_OVER
}

var current_state = GameState.INTRO
var current_day = 1
var current_weekday = 0  # 0=Mon, 1=Tue, ..., 4=Fri, 5=Sat, 6=Sun

# ----- Flags ระดับสัมพันธ์กับตัวละคร -----
var flags = {
	"saya_level": 0,
	"mali_level": 0,
	"rin_level": 0
}

# ----- สถิติผู้เล่น -----
var player_stats = {
	"sanity": 100,
	"energy": 100,
	"health": 100,
	"pow": 5,
	"agi": 5,
	"cha": 5,
	"int": 5
}

# ----- Event Pools -----
var morning_events = []
var night_events = []
var weekend_events = []

signal state_changed(new_state)
signal day_changed(day_number)

func _ready():
	load_event_pools()

# โหลด event pools จาก JSON หรือ config
func load_event_pools():
	morning_events = [
		{"id": "morning_saya_1", "required_flags": {"saya_level": 0}},
		{"id": "morning_saya_2", "required_flags": {"saya_level": 1}},
		{"id": "morning_mali_1", "required_flags": {"mali_level": 0}},
		{"id": "morning_rin_1", "required_flags": {"rin_level": 0}},
		{"id": "morning_random_1", "required_flags": {}},
	]
	
	night_events = [
		{"id": "night_saya_1", "required_flags": {"saya_level": 1}},
		{"id": "night_mali_1", "required_flags": {"mali_level": 1}},
		{"id": "night_random_1", "required_flags": {}},
	]
	
	weekend_events = [
		{"id": "weekend_date_saya", "required_flags": {"saya_level": 2}},
		{"id": "weekend_date_mali", "required_flags": {"mali_level": 2}},
		{"id": "weekend_relax", "required_flags": {}},
	]

# เปลี่ยน state
func change_state(new_state: GameState):
	current_state = new_state
	state_changed.emit(new_state)
	print("[StateManager] State changed to:", GameState.keys()[new_state])

# วนลูปวันถัดไป
func next_day():
	current_day += 1
	current_weekday = (current_weekday + 1) % 7
	day_changed.emit(current_day)
	print("[StateManager] Day %d (%s)" % [current_day, get_weekday_name()])

# ตรวจสอบว่าเป็นวันหยุดสุดสัปดาห์ไหม
func is_weekend() -> bool:
	return current_weekday == 5 or current_weekday == 6  # Sat or Sun

func get_weekday_name() -> String:
	var days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	return days[current_weekday]

# ----- สุ่ม Event ตาม Flags -----
func get_random_event(event_pool: Array) -> String:
	var available_events = []
	
	for event_data in event_pool:
		if check_event_requirements(event_data["required_flags"]):
			available_events.append(event_data["id"])
	
	if available_events.size() > 0:
		return available_events[randi() % available_events.size()]
	else:
		return ""  # ไม่มี event ที่เข้าเงื่อนไข

# ตรวจสอบว่า flag ตรงตามเงื่อนไขไหม
func check_event_requirements(required_flags: Dictionary) -> bool:
	for flag_name in required_flags.keys():
		if !flags.has(flag_name):
			return false
		if flags[flag_name] < required_flags[flag_name]:
			return false
	return true

# ----- จัดการ Flag -----
func increase_flag(character: String, amount: int = 1):
	var flag_name = character.to_lower() + "_level"
	if flags.has(flag_name):
		flags[flag_name] += amount
		print("[StateManager] %s increased to %d" % [flag_name, flags[flag_name]])

func get_flag(character: String) -> int:
	var flag_name = character.to_lower() + "_level"
	return flags.get(flag_name, 0)

# ----- จัดการสถิติผู้เล่น -----
func modify_stat(stat_name: String, amount: int):
	if player_stats.has(stat_name):
		player_stats[stat_name] = clamp(player_stats[stat_name] + amount, 0, 100)
		print("[StateManager] %s changed by %d -> %d" % [stat_name, amount, player_stats[stat_name]])

func get_stat(stat_name: String) -> int:
	return player_stats.get(stat_name, 0)

# ----- Game Over Check -----
func check_game_over() -> bool:
	if player_stats["sanity"] <= 0 or player_stats["health"] <= 0:
		change_state(GameState.GAME_OVER)
		return true
	return false

# ----- บันทึก/โหลดเกม -----
func save_game():
	var save_data = {
		"day": current_day,
		"weekday": current_weekday,
		"flags": flags,
		"stats": player_stats,
		"state": current_state
	}
	
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[StateManager] Game saved!")

func load_game():
	var file = FileAccess.open("user://savegame.save", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var data = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			current_day = data.get("day", 1)
			current_weekday = data.get("weekday", 0)
			flags = data.get("flags", flags)
			player_stats = data.get("stats", player_stats)
			current_state = data.get("state", GameState.INTRO)
			print("[StateManager] Game loaded!")
		file.close()
