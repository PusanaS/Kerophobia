extends Node2D
@onready var dialogue_manager = $DialogueManager  # โหนดของคุณ

func _ready():
	# เชื่อม signal จาก StateManager
	StateManager.state_changed.connect(_on_state_changed)
	StateManager.day_changed.connect(_on_day_changed)
	
	# เริ่มเกม
	start_game()

func start_game():
	StateManager.change_state(StateManager.GameState.INTRO)

# เมื่อ state เปลี่ยน
func _on_state_changed(new_state):
	match new_state:
		StateManager.GameState.INTRO:
			play_intro()
		
		StateManager.GameState.MORNING_EVENT:
			play_morning_event()
		
		StateManager.GameState.MORNING_CLASS:
			play_morning_class()
		
		StateManager.GameState.LUNCH_BREAK:
			play_lunch_break()
		
		StateManager.GameState.EVENING_CLASS:
			play_evening_class()
		
		StateManager.GameState.NIGHT_EVENT:
			play_night_event()
		
		StateManager.GameState.WEEKEND_EVENT:
			play_weekend_event()
		
		StateManager.GameState.GAME_OVER:
			show_game_over()

func _on_day_changed(day_number):
	print("=== Day %d - %s ===" % [day_number, StateManager.get_weekday_name()])

# ----- Intro -----
func play_intro():
	dialogue_manager.show_event_by_id("intro_1")

# ----- Morning Event -----
func play_morning_event():
	var event_id = StateManager.get_random_event(StateManager.morning_events)
	
	if event_id != "":
		dialogue_manager.show_event_by_id(event_id)
	else:
		print("No morning event available, skip to class")
		proceed_to_next_state()

# ----- Morning Class -----
func play_morning_class():
	# แสดง UI เรียนเช้า หรือข้ามไปเลย
	print("Morning class...")
	await get_tree().create_timer(0.5).timeout
	proceed_to_next_state()

# ----- Lunch Break -----
func play_lunch_break():
	print("Lunch break...")
	await get_tree().create_timer(0.5).timeout
	proceed_to_next_state()

# ----- Evening Class -----
func play_evening_class():
	print("Evening class...")
	await get_tree().create_timer(0.5).timeout
	proceed_to_next_state()

# ----- Night Event -----
func play_night_event():
	var event_id = StateManager.get_random_event(StateManager.night_events)
	
	if event_id != "":
		dialogue_manager.show_event_by_id(event_id)
	else:
		proceed_to_next_state()

# ----- Weekend Event -----
func play_weekend_event():
	var event_id = StateManager.get_random_event(StateManager.weekend_events)
	
	if event_id != "":
		dialogue_manager.show_event_by_id(event_id)
	else:
		end_weekend()

func end_weekend():
	# จบวันหยุด กลับเข้าลูปปกติ
	StateManager.next_day()
	StateManager.change_state(StateManager.GameState.MORNING_EVENT)

# ----- Game Over -----
func show_game_over():
	print("GAME OVER")
	# แสดง UI Game Over

# ----- ไปขั้นตอนถัดไป -----
func proceed_to_next_state():
	match StateManager.current_state:
		StateManager.GameState.INTRO:
			StateManager.next_day()  # เริ่มวันที่ 1
			StateManager.change_state(StateManager.GameState.MORNING_EVENT)
		
		StateManager.GameState.MORNING_EVENT:
			StateManager.change_state(StateManager.GameState.MORNING_CLASS)
		
		StateManager.GameState.MORNING_CLASS:
			StateManager.change_state(StateManager.GameState.LUNCH_BREAK)
		
		StateManager.GameState.LUNCH_BREAK:
			StateManager.change_state(StateManager.GameState.EVENING_CLASS)
		
		StateManager.GameState.EVENING_CLASS:
			StateManager.change_state(StateManager.GameState.NIGHT_EVENT)
		
		StateManager.GameState.NIGHT_EVENT:
			# เช็คว่าวันศุกร์/เสาร์ไหม
			if StateManager.is_weekend():
				StateManager.change_state(StateManager.GameState.WEEKEND_EVENT)
			else:
				# ไม่ใช่ → วันใหม่
				StateManager.next_day()
				
				# เช็ค Game Over
				if StateManager.check_game_over():
					return
				
				StateManager.change_state(StateManager.GameState.MORNING_EVENT)
		
		StateManager.GameState.WEEKEND_EVENT:
			end_weekend()

# เรียกฟังก์ชันนี้เมื่อ Event จบ (จาก DialogueManager)
func on_event_finished():
	proceed_to_next_state()
