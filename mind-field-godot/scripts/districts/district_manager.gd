## DistrictManager — Creates and manages the four themed districts.
extends Node

signal district_created(district_data: Dictionary)
signal district_updated(district_data: Dictionary)

var _districts: Dictionary = {}  # BankType -> District

func initialize() -> void:
	pass

func create_default_districts() -> void:
	_districts.clear()
	create_district(Bank.BankType.IVORAI, "Ivorai Grove")
	create_district(Bank.BankType.GLYFFINS, "Glyffinworks")
	create_district(Bank.BankType.ZORAQIANS, "Zoraqian Depths")
	create_district(Bank.BankType.YAGARI, "Yagari Sanctum")

func create_district(bank_type: int, dname: String) -> District:
	var district := District.new(bank_type, dname)
	_districts[bank_type] = district
	district_created.emit(district.to_dict())
	return district

func get_district(bank_type: int) -> District:
	return _districts.get(bank_type) as District

func get_district_by_id(district_id: String) -> District:
	for d: District in _districts.values():
		if d.id == district_id:
			return d
	return null

func get_all_districts() -> Array:
	var result: Array = []
	for d: District in _districts.values():
		result.append(d)
	return result

func get_all_districts_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for d: District in _districts.values():
		result.append(d.to_dict())
	return result

func place_habit_in_district(bank_type: int, habit_index: int, pos: Vector2) -> Dictionary:
	var district := get_district(bank_type)
	if district == null:
		return {}
	var structure := district.place_structure(habit_index, pos)
	district_updated.emit(district.to_dict())
	return structure

func on_tick(delta_time: float) -> void:
	for district: District in _districts.values():
		district.on_tick(delta_time)
		district.recalculate_traffic()

func get_total_traffic() -> float:
	var total := 0.0
	for d: District in _districts.values():
		total += d.traffic_score
	return total

func clear_all() -> void:
	_districts.clear()

func restore_district(data: Dictionary) -> void:
	var bank_type: int = data.get("bank_type", 0)
	var district := District.new(bank_type, data.get("name", ""))
	district.restore_from(data)
	_districts[bank_type] = district
