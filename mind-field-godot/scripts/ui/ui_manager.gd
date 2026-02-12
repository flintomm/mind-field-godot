## UIManager — SC2-style UI: bottom panel with tabs, top info bar, right selection panel.
extends Control

@onready var snippet_panel: Control = %SnippetPanel
@onready var habit_panel: Control = %HabitPanel
@onready var day_unit_panel: Control = %DayUnitPanel

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var attendee_label: Label = %AttendeeLabel

@onready var tab_snippet: Button = %TabSnippet
@onready var tab_habits: Button = %TabHabits
@onready var tab_day_unit: Button = %TabDayUnit

@onready var bank_bars: Array[ProgressBar] = [%BankBar0, %BankBar1, %BankBar2, %BankBar3]
@onready var bank_labels: Array[Label] = [%BankLabel0, %BankLabel1, %BankLabel2, %BankLabel3]

@onready var camera_indicator: ColorRect = %CameraIndicator

@onready var btn_ivorai: Button = %BtnIvorai
@onready var btn_glyffins: Button = %BtnGlyffins
@onready var btn_zoraqians: Button = %BtnZoraqians
@onready var btn_yagari: Button = %BtnYagari

# Selection panel nodes (using unique names from scene)
@onready var selection_panel: PanelContainer = %SelectionPanel
@onready var selection_title: Label = %SelectionTitle
@onready var unit_portrait: ColorRect = %UnitPortrait
@onready var unit_name: Label = %UnitName
@onready var unit_type: Label = %UnitType
@onready var unit_race: Label = %UnitRace
@onready var unit_stage: Label = %UnitStage
@onready var unit_snippets: Label = %UnitSnippets
@onready var unit_active: Label = %UnitActive
@onready var unit_birthday: Label = %UnitBirthday
@onready var unit_thoughts: RichTextLabel = %UnitThoughts
@onready var unit_bio: RichTextLabel = %UnitBio

var _active_panel: Control = null
var _selected_unit_info: Dictionary = {}

const RACE_COLORS := {
	0: Color(0.85, 0.78, 0.55, 1.0),   # Ivorai - warm ivory/bronze
	1: Color(0.70, 0.72, 0.75, 1.0),   # Glyffins - cool metallic
	2: Color(0.25, 0.18, 0.30, 1.0),   # Zoraqians - dark alien purple
	3: Color(0.15, 0.15, 0.20, 1.0),   # Yagari - dark sentinel
}

const RACE_NAMES := ["Ivorai", "Glyffins", "Zoraqians", "Yagari"]
const STAGE_NAMES := ["Base", "Shoes", "Gloves", "Chest", "Helm", "Retired"]

func _ready() -> void:
	# Tab connections
	if tab_snippet:
		tab_snippet.pressed.connect(func() -> void: show_panel(snippet_panel))
	if tab_habits:
		tab_habits.pressed.connect(func() -> void: show_panel(habit_panel))
	if tab_day_unit:
		tab_day_unit.pressed.connect(func() -> void: show_panel(day_unit_panel))
	
	# District focus buttons
	if btn_ivorai:
		btn_ivorai.pressed.connect(func() -> void: _focus_district(0))
	if btn_glyffins:
		btn_glyffins.pressed.connect(func() -> void: _focus_district(1))
	if btn_zoraqians:
		btn_zoraqians.pressed.connect(func() -> void: _focus_district(2))
	if btn_yagari:
		btn_yagari.pressed.connect(func() -> void: _focus_district(3))

	# Selection signals
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.unit_deselected.connect(_on_unit_deselected)

	if selection_panel:
		selection_panel.visible = false

	show_panel(snippet_panel)

func _process(_delta: float) -> void:
	_update_status_bar()
	_update_bank_status()
	_update_minimap_indicator()

func show_panel(panel: Control) -> void:
	if snippet_panel:
		snippet_panel.visible = (panel == snippet_panel)
	if habit_panel:
		habit_panel.visible = (panel == habit_panel)
	if day_unit_panel:
		day_unit_panel.visible = (panel == day_unit_panel)
	_active_panel = panel
	if panel == habit_panel:
		_refresh_habits()
	EventBus.ui_panel_changed.emit(panel.name if panel else "")

func _update_status_bar() -> void:
	var tm: Node = GameManager.time_manager
	if tm == null:
		return
	if day_label:
		day_label.text = "Day %d" % tm.current_day
	if time_label:
		var h: int = int(tm.game_time_hours)
		var m: int = int((tm.game_time_hours - h) * 60.0)
		var period := "AM" if h < 12 else "PM"
		var display_h := h % 12
		if display_h == 0:
			display_h = 12
		time_label.text = "%d:%02d %s" % [display_h, m, period]
	
	# Update attendee count
	if attendee_label:
		var sim: Node = GameManager.simulation_manager
		if sim and sim.has_method("get_attendees"):
			var attendees: Array = sim.get_attendees()
			var count: int = attendees.size()
			attendee_label.text = "👥 %d" % count

func _update_bank_status() -> void:
	var br: Node = GameManager.bank_registry
	if br == null:
		return
	
	for i in range(4):
		var bank: Bank = br.get_bank(i)
		if bank:
			var balance: float = bank.balance
			var capacity: float = bank.capacity
			var display_balance: int = int(balance)
			if bank_bars[i]:
				bank_bars[i].value = display_balance
				bank_bars[i].max_value = capacity
			if bank_labels[i]:
				bank_labels[i].text = "%d" % display_balance

func _update_minimap_indicator() -> void:
	if camera_indicator and GameManager.time_manager:
		var cam: Camera2D = get_node_or_null("../Camera2D")
		if cam:
			# Map camera position to minimap coords
			var cam_pos: Vector2 = cam.position
			var map_size := Vector2(4800, 3200)
			var minimap_rect := Rect2(0, 0, 200, 180)
			var indicator_pos := Vector2(
				(cam_pos.x / map_size.x) * minimap_rect.size.x,
				(cam_pos.y / map_size.y) * minimap_rect.size.y
			)
			camera_indicator.position = indicator_pos - Vector2(10, 5)

func _focus_district(bank_type: int) -> void:
	var dm: Node = GameManager.district_manager
	if dm:
		var district: Node = dm.get_district(bank_type)
		if district:
			var cam: Camera2D = get_node_or_null("../Camera2D")
			if cam:
				var target_pos: Vector2 = district.position + Vector2(900, 550)
				cam.position = target_pos

func _refresh_habits() -> void:
	EventBus.habit_list_requested.emit()

# --- Selection Panel (SC2-style) ---

func _on_unit_selected(info: Dictionary) -> void:
	_selected_unit_info = info
	
	if selection_panel == null:
		return
	
	selection_panel.visible = true
	selection_panel.get_parent().move_child(selection_panel, -1)  # Move to front
	
	var unit_type_str: String = info.get("type", "unknown")
	if selection_title:
		selection_title.text = "Day Unit" if unit_type_str == "day_unit" else "Attendee"
	
	# Portrait color based on race
	if unit_portrait:
		var race_type: int = info.get("race_type", 0)
		unit_portrait.color = RACE_COLORS.get(race_type, Color(0.2, 0.2, 0.2))
	
	# Basic info
	if unit_name:
		unit_name.text = info.get("name", "Unknown Unit")
	if unit_type:
		unit_type.text = "Type: %s" % ("Active Day Unit" if unit_type_str == "day_unit" else "Retired Attendee")
	if unit_race:
		var race_idx: int = info.get("race_type", 0)
		unit_race.text = "Race: %s" % RACE_NAMES[race_idx] if race_idx >= 0 and race_idx < 4 else "Race: Unknown"
	if unit_stage:
		var stage_idx: int = info.get("stage_idx", 0)
		unit_stage.text = "Stage: %s" % STAGE_NAMES[stage_idx] if stage_idx >= 0 and stage_idx < 6 else "Stage: Unknown"
	if unit_snippets:
		unit_snippets.text = "Thoughts: %d" % info.get("snippet_count", 0)
	if unit_active:
		unit_active.text = "Active: %dm" % int(info.get("active_minutes", 0.0))
	
	# Birthday
	if unit_birthday:
		var birthday: String = info.get("birthday", "Unknown")
		unit_birthday.text = "Born: %s" % birthday
	
	# Thoughts/Journal entries
	if unit_thoughts:
		var thoughts_text: String = info.get("thoughts_text", "No thoughts recorded yet.")
		unit_thoughts.text = "[b]Today's Thoughts:[/b]\n%s" % thoughts_text
	
	# Bio
	if unit_bio:
		var bio: String = info.get("bio", "")
		if bio.is_empty():
			bio = "[i]No biography yet...[/i]"
		unit_bio.text = bio

func _on_unit_deselected() -> void:
	_selected_unit_info = {}
	if selection_panel:
		selection_panel.visible = false
