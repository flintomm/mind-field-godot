## HabitSystem — Manages all habits: creation, completion, decay, modules, rewards.
extends Node

signal habit_created(habit_data: Dictionary)
signal habit_completed_signal(habit_data: Dictionary)
signal habit_removed(habit_data: Dictionary)
signal habit_decayed_signal(habit_data: Dictionary, new_health: float)

var _habits: Array = []  # Array of Habit

func initialize() -> void:
	pass

func create_habit(habit_name: String, foundation: int, description: String = "", cfg: Dictionary = {}) -> Habit:
	var habit := Habit.new(habit_name, foundation, cfg)
	habit.description = description
	_habits.append(habit)
	habit_created.emit(habit.to_dict())
	return habit

func remove_habit(habit_id: String) -> bool:
	for i: int in range(_habits.size()):
		if _habits[i].id == habit_id:
			var data: Dictionary = _habits[i].to_dict()
			_habits.remove_at(i)
			habit_removed.emit(data)
			return true
	return false

func get_habit(habit_id: String) -> Habit:
	for h: Habit in _habits:
		if h.id == habit_id:
			return h
	return null

func get_all_habits() -> Array:
	return _habits

func get_all_habits_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for h: Habit in _habits:
		result.append(h.to_dict())
	return result

func get_habits_by_foundation(foundation_type: int) -> Array:
	var result: Array = []
	for h: Habit in _habits:
		if h.foundation == foundation_type:
			result.append(h)
	return result

func complete_habit(habit_id: String) -> bool:
	var habit := get_habit(habit_id)
	if habit == null:
		return false
	var major_reward := habit.complete()
	habit_completed_signal.emit(habit.to_dict())
	EventBus.habit_completed.emit(habit_id, habit.streak, major_reward)

	_grant_reward(habit, major_reward)
	return true

func process_decay() -> void:
	for habit: Habit in _habits:
		var old_health := habit.health
		habit.apply_decay()
		if absf(old_health - habit.health) > 0.01:
			habit_decayed_signal.emit(habit.to_dict(), habit.health)
			EventBus.habit_decayed.emit(habit.id, habit.health)

func _grant_reward(habit: Habit, major: bool) -> void:
	var slot := _get_next_available_slot(habit)
	if major:
		var module := {
			"id": str(randi()) + "_" + str(Time.get_ticks_msec()),
			"type": Habit.ModuleType.STRUCTURAL,
			"slot": slot,
			"name": "Tier %d Frame" % habit.level,
			"required_level": habit.level,
			"bonuses": {"decay_resist": 0.02},
		}
		habit.attach_module(module)
		print("[HabitSystem] Major reward for '%s': Structural module unlocked." % habit.habit_name)
	else:
		var module := {
			"id": str(randi()) + "_" + str(Time.get_ticks_msec()),
			"type": Habit.ModuleType.COSMETIC,
			"slot": slot,
			"name": "Streak %d Badge" % habit.streak,
			"required_level": 1,
			"bonuses": {"visual": 1.0},
		}
		habit.attach_module(module)

func _get_next_available_slot(habit: Habit) -> int:
	var used := {}
	for m: Dictionary in habit.get_modules():
		used[m.get("slot", 0)] = true
	for slot: int in [Habit.ModuleSlot.LEFT, Habit.ModuleSlot.RIGHT, Habit.ModuleSlot.TOP, Habit.ModuleSlot.FRONT, Habit.ModuleSlot.BACK]:
		if not used.has(slot):
			return slot
	return Habit.ModuleSlot.FRONT

func attach_module(habit_id: String, module: Dictionary) -> bool:
	var habit := get_habit(habit_id)
	if habit == null:
		return false
	return habit.attach_module(module)

func detach_module(habit_id: String, module_id: String) -> bool:
	var habit := get_habit(habit_id)
	if habit == null:
		return false
	return habit.detach_module(module_id)

func clear_all() -> void:
	_habits.clear()

func restore_habit(data: Dictionary) -> Habit:
	var habit := Habit.new(data.get("name", ""), data.get("foundation", 0), data.get("config", {}))
	habit.restore_from(data)
	_habits.append(habit)
	return habit

func get_active_count() -> int:
	var count := 0
	for h: Habit in _habits:
		if not h.is_dead():
			count += 1
	return count

func get_healthy_count() -> int:
	var count := 0
	for h: Habit in _habits:
		if h.is_healthy():
			count += 1
	return count

func get_average_health() -> float:
	if _habits.is_empty():
		return 0.0
	var total := 0.0
	for h: Habit in _habits:
		total += h.health
	return total / _habits.size()
