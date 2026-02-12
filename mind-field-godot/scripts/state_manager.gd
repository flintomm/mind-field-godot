## StateManager — Central state container with observer pattern and save/load.
extends Node

signal state_changed()
signal property_changed(key: String)

var _store: Dictionary = {}
var _observers: Dictionary = {}  # key -> Array[Callable]

func initialize() -> void:
	pass

func set_value(key: String, value: Variant) -> void:
	_store[key] = value
	property_changed.emit(key)
	if _observers.has(key):
		for cb: Callable in _observers[key]:
			cb.call(value)
	state_changed.emit()

func get_value(key: String, default_value: Variant = null) -> Variant:
	return _store.get(key, default_value)

func has_key(key: String) -> bool:
	return _store.has(key)

func observe(key: String, callback: Callable) -> void:
	if not _observers.has(key):
		_observers[key] = []
	_observers[key].append(callback)

func remove_observer(key: String, callback: Callable) -> void:
	if _observers.has(key):
		_observers[key].erase(callback)

func export_state() -> Dictionary:
	var gm := GameManager
	var data := {
		"version": "1.0",
		"saved_at": Time.get_unix_time_from_system(),
		"game_time_hours": gm.time_manager.game_time_hours,
		"banks": [],
		"habits": [],
		"districts": [],
		"current_day_unit": {},
		"attendees": [],
		"snippets": [],
	}

	# Banks
	for bank: Dictionary in gm.bank_registry.get_all_banks():
		data["banks"].append({
			"type": bank["type"],
			"balance": bank["balance"],
			"capacity": bank["capacity"],
			"snippet_count": bank["snippet_count"],
		})

	# Habits
	for habit: Dictionary in gm.habit_system.get_all_habits_data():
		data["habits"].append(habit)

	# Districts
	for district: Dictionary in gm.district_manager.get_all_districts_data():
		data["districts"].append(district)

	# Day Unit
	var du: Dictionary = gm.simulation_manager.get_current_day_unit_data()
	if not du.is_empty():
		data["current_day_unit"] = du

	# Attendees
	data["attendees"] = gm.simulation_manager.get_attendees_data()

	# Snippets
	data["snippets"] = gm.bank_registry.get_all_snippets_data()

	return data

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var gm := GameManager

	gm.time_manager.set_game_time_hours(data.get("game_time_hours", 12.0))

	# Banks
	if data.has("banks"):
		for bd: Dictionary in data["banks"]:
			gm.bank_registry.restore_bank(bd)

	# Habits
	if data.has("habits"):
		gm.habit_system.clear_all()
		for hd: Dictionary in data["habits"]:
			gm.habit_system.restore_habit(hd)

	# Districts
	if data.has("districts"):
		gm.district_manager.clear_all()
		for dd: Dictionary in data["districts"]:
			gm.district_manager.restore_district(dd)

	# Day Unit
	if data.has("current_day_unit") and not data["current_day_unit"].is_empty():
		gm.simulation_manager.restore_day_unit(data["current_day_unit"])

	# Attendees
	if data.has("attendees"):
		gm.simulation_manager.restore_attendees(data["attendees"])

	# Snippets
	if data.has("snippets"):
		for sd: Dictionary in data["snippets"]:
			gm.bank_registry.restore_snippet(sd)

	state_changed.emit()

func initialize_new_game() -> void:
	var gm := GameManager
	gm.bank_registry.create_default_banks()
	gm.district_manager.create_default_districts()
	gm.time_manager.reset_time()
	state_changed.emit()
