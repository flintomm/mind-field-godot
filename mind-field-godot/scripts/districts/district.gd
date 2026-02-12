## District — A themed area tied to a bank type, with structures and traffic simulation.
class_name District
extends RefCounted

var id: String
var bank_type: int
var district_name: String
var level: int = 1
var traffic_score: float = 0.0
var decay_rate_multiplier: float = 1.0
var terrain_color: Color
var ambient_color: Color
var lighting_intensity: float = 1.0

var _structures: Array[Dictionary] = []
var _ambient_intensity: float = 1.0

func _init(btype: int, dname: String) -> void:
	id = str(randi()) + "_" + str(Time.get_ticks_msec())
	bank_type = btype
	district_name = dname
	_apply_theme()

func _apply_theme() -> void:
	match bank_type:
		Bank.BankType.IVORAI:
			terrain_color = Color(0.85, 0.78, 0.55)
			ambient_color = Color(1.0, 0.9, 0.7)
			lighting_intensity = 1.1
			decay_rate_multiplier = 0.9
		Bank.BankType.GLYFFINS:
			terrain_color = Color(0.7, 0.72, 0.75)
			ambient_color = Color(0.85, 0.85, 0.9)
			lighting_intensity = 1.0
			decay_rate_multiplier = 1.0
		Bank.BankType.ZORAQIANS:
			terrain_color = Color(0.25, 0.18, 0.30)
			ambient_color = Color(0.4, 0.2, 0.5)
			lighting_intensity = 0.7
			decay_rate_multiplier = 1.2
		Bank.BankType.YAGARI:
			terrain_color = Color(0.15, 0.15, 0.2)
			ambient_color = Color(0.3, 0.35, 0.45)
			lighting_intensity = 0.6
			decay_rate_multiplier = 1.1

func place_structure(habit_index: int, pos: Vector2, rotation: float = 0.0) -> Dictionary:
	var structure := {
		"id": str(randi()) + "_" + str(Time.get_ticks_msec()),
		"habit_index": habit_index,
		"position": pos,
		"rotation": rotation,
	}
	_structures.append(structure)
	recalculate_traffic()
	return structure

func remove_structure(structure_id: String) -> bool:
	for i: int in range(_structures.size()):
		if _structures[i]["id"] == structure_id:
			_structures.remove_at(i)
			recalculate_traffic()
			return true
	return false

func get_structures() -> Array[Dictionary]:
	return _structures

func recalculate_traffic() -> void:
	var base_traffic := float(_structures.size()) * 10.0
	var density_bonus := 0.0
	for i: int in range(_structures.size()):
		for j: int in range(i + 1, _structures.size()):
			var dist: float = (_structures[i]["position"] as Vector2).distance_to(_structures[j]["position"] as Vector2)
			if dist < 3.0:
				density_bonus += (3.0 - dist) * 2.0
	var level_bonus := float(level - 1) * 5.0
	var old_traffic := traffic_score
	traffic_score = base_traffic + density_bonus + level_bonus
	if absf(old_traffic - traffic_score) > 0.5:
		EventBus.district_traffic_changed.emit(id, traffic_score)

func level_up() -> void:
	level += 1
	recalculate_traffic()

func on_tick(_delta_time: float) -> void:
	_ambient_intensity = lighting_intensity + sin(Time.get_ticks_msec() / 1000.0 * 0.5) * 0.05

func get_current_ambient_intensity() -> float:
	return _ambient_intensity

func to_dict() -> Dictionary:
	var structs: Array[Dictionary] = []
	for s: Dictionary in _structures:
		structs.append({
			"id": s["id"],
			"habit_index": s["habit_index"],
			"x": (s["position"] as Vector2).x,
			"y": (s["position"] as Vector2).y,
			"rotation": s["rotation"],
		})
	return {
		"id": id,
		"bank_type": bank_type,
		"name": district_name,
		"level": level,
		"traffic_score": traffic_score,
		"structures": structs,
	}

func restore_from(data: Dictionary) -> void:
	id = data.get("id", id)
	level = data.get("level", 1)
	traffic_score = data.get("traffic_score", 0.0)
	if data.has("structures"):
		_structures.clear()
		for sd: Dictionary in data["structures"]:
			_structures.append({
				"id": sd.get("id", ""),
				"habit_index": sd.get("habit_index", 0),
				"position": Vector2(sd.get("x", 0.0), sd.get("y", 0.0)),
				"rotation": sd.get("rotation", 0.0),
			})
