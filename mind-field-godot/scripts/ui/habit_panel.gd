## HabitPanel — Create habits, view list, complete them.
extends VBoxContainer

@onready var habit_name_input: LineEdit = %HabitNameInput
@onready var foundation_dropdown: OptionButton = %FoundationDropdown
@onready var create_button: Button = %CreateHabitButton
@onready var habit_list: VBoxContainer = %HabitList

func _ready() -> void:
	create_button.pressed.connect(_on_create)

	# Populate foundation dropdown
	foundation_dropdown.clear()
	for fname: String in ["Station", "Workshop", "Sanctuary", "Forge", "Market"]:
		foundation_dropdown.add_item(fname)

	refresh()

func _on_create() -> void:
	var hname := habit_name_input.text.strip_edges()
	if hname.is_empty():
		return
	var found_idx := foundation_dropdown.selected
	GameManager.habit_system.create_habit(hname, found_idx)
	habit_name_input.text = ""
	refresh()

func refresh() -> void:
	if habit_list == null:
		return
	# Clear
	for child: Node in habit_list.get_children():
		child.queue_free()

	var habits: Array = GameManager.habit_system.get_all_habits()
	for habit: Habit in habits:
		var entry := HBoxContainer.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var info := Label.new()
		info.text = "%s [%s] HP:%d Lv:%d Streak:%d" % [
			habit.habit_name,
			Habit.FOUNDATION_NAMES.get(habit.foundation, "?"),
			int(habit.health),
			habit.level,
			habit.streak,
		]
		info.modulate = habit.get_health_color()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(info)

		var complete_btn := Button.new()
		complete_btn.text = "Complete"
		var hid := habit.id
		complete_btn.pressed.connect(func() -> void:
			GameManager.habit_system.complete_habit(hid)
			refresh()
		)
		entry.add_child(complete_btn)

		var remove_btn := Button.new()
		remove_btn.text = "X"
		remove_btn.pressed.connect(func() -> void:
			GameManager.habit_system.remove_habit(hid)
			refresh()
		)
		entry.add_child(remove_btn)

		habit_list.add_child(entry)
