## UIManager — Controls which panels are visible, updates status bar, minimap.
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

var _active_panel: Control

func _ready() -> void:
	tab_snippet.pressed.connect(func() -> void: show_panel(snippet_panel))
	tab_habits.pressed.connect(func() -> void: show_panel(habit_panel))
	tab_day_unit.pressed.connect(func() -> void: show_panel(day_unit_panel))

	EventBus.habit_completed.connect(func(_id: String, _s: int, _m: bool) -> void: _refresh_habits())
	EventBus.habit_decayed.connect(func(_id: String, _h: float) -> void: _refresh_habits())

	# District focus buttons
	if btn_ivorai:
		btn_ivorai.pressed.connect(func() -> void: _focus_district(0))
	if btn_glyffins:
		btn_glyffins.pressed.connect(func() -> void: _focus_district(1))
	if btn_zoraqians:
		btn_zoraqians.pressed.connect(func() -> void: _focus_district(2))
	if btn_yagari:
		btn_yagari.pressed.connect(func() -> void: _focus_district(3))

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
	if attendee_label:
		var count: int = GameManager.simulation_manager.get_attendees().size()
		attendee_label.text = "👥 %d" % count

func _update_bank_status() -> void:
	var registry: Node = GameManager.bank_registry
	if registry == null:
		return
	for i: int in range(4):
		var bank: Bank = registry.get_bank(i)
		if bank == null:
			continue
		if i < bank_bars.size() and bank_bars[i]:
			bank_bars[i].value = bank.balance / float(bank.capacity) * 100.0
			bank_bars[i].modulate = bank.primary_color
		if i < bank_labels.size() and bank_labels[i]:
			bank_labels[i].text = "%d" % int(bank.balance)

func _update_minimap_indicator() -> void:
	if camera_indicator == null:
		return
	# Get camera position from the main scene
	var main := get_tree().current_scene
	if main == null:
		return
	var cam: Camera2D = main.get_node_or_null("Camera2D")
	if cam == null:
		return
	# Map camera position (0-1920, 0-1080) to minimap (0-160, 0-128)
	var minimap_x := clampf(cam.position.x / 1920.0 * 160.0, 0, 150)
	var minimap_y := clampf(cam.position.y / 1080.0 * 128.0, 0, 118)
	camera_indicator.position = Vector2(minimap_x - 10, minimap_y - 5)

func _focus_district(bank_type: int) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("center_camera_on_district"):
		main.center_camera_on_district(bank_type)

func _refresh_habits() -> void:
	if habit_panel and habit_panel.has_method("refresh"):
		habit_panel.refresh()
