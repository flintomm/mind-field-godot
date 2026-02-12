## SimulationManager — Tick-based game loop: drives decay, fusion, day-end conversion.
extends Node

var current_day_unit: DayUnit
var tick_number: int = 0

var _tick_interval: float = 1.0
var _decay_tick_interval: int = 60
var _tick_timer: float = 0.0
var _ticks_since_decay: int = 0
var _attendees: Array = []  # Array of DayUnit
var _initialized := false

func initialize() -> void:
	_initialized = true
	GameManager.time_manager.day_ended_signal.connect(_handle_day_end)

func _process(delta: float) -> void:
	if not _initialized:
		return

	_tick_timer += delta
	if _tick_timer >= _tick_interval:
		_tick_timer -= _tick_interval
		_tick()

	# Update day unit active time
	if current_day_unit != null and current_day_unit.stage != DayUnit.MorphStage.RETIRED:
		current_day_unit.update_active_time(delta / 60.0)

func _tick() -> void:
	tick_number += 1
	var gm := GameManager

	# Bank tick
	gm.bank_registry.on_tick(_tick_interval)

	# District tick
	gm.district_manager.on_tick(_tick_interval)

	# Habit decay
	_ticks_since_decay += 1
	if _ticks_since_decay >= _decay_tick_interval:
		_ticks_since_decay = 0
		gm.habit_system.process_decay()

	# Update day unit fusion
	if current_day_unit != null:
		var secondary: int = gm.bank_registry.get_secondary_bank()
		var accent_count := 0
		if secondary >= 0:
			accent_count = gm.bank_registry.get_accent_count(secondary)
		current_day_unit.set_fusion(secondary, accent_count)

	EventBus.simulation_tick.emit(_tick_interval, tick_number)

func process_snippet(snippet: Dictionary) -> void:
	if current_day_unit == null:
		_spawn_day_unit()

	var spacing: float = GameManager.time_manager.get_snippet_spacing_minutes()
	GameManager.time_manager.record_snippet_time()

	current_day_unit.accumulate_snippet(snippet, spacing)

	# Update fusion
	var secondary: int = GameManager.bank_registry.get_secondary_bank()
	var accent_count := 0
	if secondary >= 0:
		accent_count = GameManager.bank_registry.get_accent_count(secondary)
	current_day_unit.set_fusion(secondary, accent_count)

func _spawn_day_unit() -> void:
	var dominant: int = GameManager.bank_registry.get_dominant_bank()
	current_day_unit = DayUnit.new(Time.get_unix_time_from_system(), dominant)
	print("[Simulation] Day Unit spawned: %d" % dominant)

func _handle_day_end() -> void:
	if current_day_unit == null:
		return

	current_day_unit.retire()
	_attendees.append(current_day_unit)

	EventBus.attendee_created.emit(current_day_unit.id, current_day_unit.race_type)
	EventBus.day_ended.emit(GameManager.time_manager.current_day, current_day_unit.id)

	print("[Simulation] Day Unit retired. Total attendees: %d" % _attendees.size())
	current_day_unit = null

func get_attendees() -> Array:
	return _attendees

func get_current_day_unit_data() -> Dictionary:
	if current_day_unit == null:
		return {}
	return current_day_unit.to_dict()

func get_attendees_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for att: DayUnit in _attendees:
		result.append(att.to_dict())
	return result

func restore_day_unit(data: Dictionary) -> void:
	var du := DayUnit.new(data.get("date_unix", 0.0), data.get("race_type", 0))
	du.restore_from(data)
	current_day_unit = du

func restore_attendees(attendees_data: Array) -> void:
	_attendees.clear()
	for a: Dictionary in attendees_data:
		var du := DayUnit.new(a.get("date_unix", 0.0), a.get("race_type", 0))
		du.restore_from(a)
		du.retire()
		_attendees.append(du)
