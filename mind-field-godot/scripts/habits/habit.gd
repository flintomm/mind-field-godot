## Habit — A trackable habit with decay, leveling, and module attachment.
class_name Habit
extends RefCounted

enum FoundationType { STATION = 0, WORKSHOP = 1, SANCTUARY = 2, FORGE = 3, MARKET = 4 }
enum ModuleType { STRUCTURAL = 0, UTILITY = 1, COSMETIC = 2 }
enum ModuleSlot { LEFT = 0, RIGHT = 1, TOP = 2, FRONT = 3, BACK = 4 }

const FOUNDATION_NAMES := {
	FoundationType.STATION: "Station",
	FoundationType.WORKSHOP: "Workshop",
	FoundationType.SANCTUARY: "Sanctuary",
	FoundationType.FORGE: "Forge",
	FoundationType.MARKET: "Market",
}

const FOUNDATION_COLORS := {
	FoundationType.STATION: Color(0.2, 0.7, 0.3),
	FoundationType.WORKSHOP: Color(0.3, 0.4, 0.8),
	FoundationType.SANCTUARY: Color(0.6, 0.4, 0.8),
	FoundationType.FORGE: Color(0.9, 0.4, 0.2),
	FoundationType.MARKET: Color(0.8, 0.7, 0.2),
}

var id: String
var habit_name: String
var description: String = ""
var foundation: int = FoundationType.STATION
var health: float = 100.0
var level: int = 1
var streak: int = 0
var total_completions: int = 0
var last_completed_at: float = 0.0  # unix
var created_at: float = 0.0
var config: Dictionary = {}

var _modules: Array[Dictionary] = []
var _occupied_slots: Dictionary = {}

func _init(n: String = "", found: int = FoundationType.STATION, cfg: Dictionary = {}) -> void:
	id = str(randi()) + "_" + str(Time.get_ticks_msec())
	habit_name = n
	foundation = found
	created_at = Time.get_unix_time_from_system()
	config = {
		"time_window_start": cfg.get("time_window_start", 0.0),
		"time_window_end": cfg.get("time_window_end", 24.0),
		"streak_milestone": cfg.get("streak_milestone", 7),
		"duration_bucket_minutes": cfg.get("duration_bucket_minutes", 30.0),
		"decay_rate": cfg.get("decay_rate", 0.95),
		"completion_boost": cfg.get("completion_boost", 20.0),
	}

func apply_decay() -> void:
	health = clampf(health * config.get("decay_rate", 0.95), 0.0, 100.0)

func complete() -> bool:
	# Check time window
	var now := Time.get_time_dict_from_system()
	var current_hour: float = float(now["hour"]) + float(now["minute"]) / 60.0
	var tw_start: float = config.get("time_window_start", 0.0)
	var tw_end: float = config.get("time_window_end", 24.0)
	if tw_start < tw_end:
		if current_hour < tw_start or current_hour > tw_end:
			return false

	# Check already completed today
	var today_start := _get_today_start_unix()
	if last_completed_at >= today_start:
		return false

	# Streak
	var yesterday_start := today_start - 86400.0
	if last_completed_at >= yesterday_start and last_completed_at < today_start:
		streak += 1
	else:
		streak = 1

	total_completions += 1
	last_completed_at = Time.get_unix_time_from_system()

	# Apply boost
	var decay_rate: float = config.get("decay_rate", 0.95)
	var boost: float = config.get("completion_boost", 20.0)
	health = minf(100.0, health * decay_rate + boost)

	# Level up
	var major_reward := false
	if total_completions % 10 == 0:
		level += 1
		major_reward = true
	var milestone: int = config.get("streak_milestone", 7)
	if streak > 0 and streak % milestone == 0:
		major_reward = true

	return major_reward

func can_attach_module(module: Dictionary) -> bool:
	if module.get("required_level", 1) > level:
		return false
	if _occupied_slots.has(module.get("slot", 0)):
		return false
	return true

func attach_module(module: Dictionary) -> bool:
	if not can_attach_module(module):
		return false
	_modules.append(module)
	_occupied_slots[module.get("slot", 0)] = true
	return true

func detach_module(module_id: String) -> bool:
	for i: int in range(_modules.size()):
		if _modules[i].get("id", "") == module_id:
			_occupied_slots.erase(_modules[i].get("slot", 0))
			_modules.remove_at(i)
			return true
	return false

func get_modules() -> Array[Dictionary]:
	return _modules

func get_module_bonus(bonus_key: String) -> float:
	var total := 0.0
	for m: Dictionary in _modules:
		var bonuses: Dictionary = m.get("bonuses", {})
		total += bonuses.get(bonus_key, 0.0)
	return total

func is_healthy() -> bool:
	return health > 50.0

func is_decaying() -> bool:
	return health > 0.0 and health <= 50.0

func is_dead() -> bool:
	return health <= 0.0

func get_health_color() -> Color:
	if health > 70.0:
		return Color.GREEN
	if health > 40.0:
		return Color.YELLOW
	return Color.RED

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": habit_name,
		"description": description,
		"foundation": foundation,
		"health": health,
		"level": level,
		"streak": streak,
		"total_completions": total_completions,
		"last_completed_at": last_completed_at,
		"config": config.duplicate(),
		"modules": _modules.duplicate(true),
	}

func restore_from(data: Dictionary) -> void:
	id = data.get("id", id)
	habit_name = data.get("name", habit_name)
	description = data.get("description", "")
	foundation = data.get("foundation", foundation)
	health = data.get("health", 100.0)
	level = data.get("level", 1)
	streak = data.get("streak", 0)
	total_completions = data.get("total_completions", 0)
	last_completed_at = data.get("last_completed_at", 0.0)
	if data.has("config"):
		config = data["config"].duplicate()
	if data.has("modules"):
		_modules.clear()
		_occupied_slots.clear()
		for m: Dictionary in data["modules"]:
			_modules.append(m)
			_occupied_slots[m.get("slot", 0)] = true

static func _get_today_start_unix() -> float:
	var date := Time.get_date_dict_from_system()
	return Time.get_unix_time_from_datetime_dict({"year": date["year"], "month": date["month"], "day": date["day"], "hour": 0, "minute": 0, "second": 0})
