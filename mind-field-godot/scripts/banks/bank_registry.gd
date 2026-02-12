## BankRegistry — Manages the four banks and all snippets.
extends Node

var _banks: Dictionary = {}  # BankType -> Bank
var _all_snippets: Array[Dictionary] = []

func initialize() -> void:
	pass

func create_default_banks() -> void:
	_banks.clear()
	_all_snippets.clear()
	for t: int in [Bank.BankType.IVORAI, Bank.BankType.GLYFFINS, Bank.BankType.ZORAQIANS, Bank.BankType.YAGARI]:
		_banks[t] = Bank.new(t, 100)

func get_bank(bank_type: int) -> Bank:
	return _banks.get(bank_type) as Bank

func get_all_banks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bank: Bank in _banks.values():
		result.append(bank.to_dict())
	return result

func get_all_bank_objects() -> Array:
	var result: Array = []
	for bank: Bank in _banks.values():
		result.append(bank)
	return result

func get_all_snippets() -> Array[Dictionary]:
	return _all_snippets

func get_all_snippets_data() -> Array[Dictionary]:
	return _all_snippets.duplicate()

func submit_snippet(content: String, bank_type: int, mood_score: float = 0.0) -> Dictionary:
	var bank := get_bank(bank_type)
	if bank == null:
		return {}

	var snippet := bank.add_snippet(content, mood_score)
	_all_snippets.append(snippet)

	EventBus.snippet_added.emit(content, bank_type, mood_score)

	# Feed to simulation
	GameManager.simulation_manager.process_snippet(snippet)

	return snippet

func get_dominant_bank() -> int:
	var dominant := Bank.BankType.IVORAI
	var max_count := 0
	for bank_type: int in _banks:
		var bank: Bank = _banks[bank_type]
		if bank.snippet_count > max_count:
			max_count = bank.snippet_count
			dominant = bank_type
	return dominant

func get_secondary_bank() -> int:
	var dominant := get_dominant_bank()
	var secondary := -1
	var max_count := 0
	for bank_type: int in _banks:
		if bank_type == dominant:
			continue
		var bank: Bank = _banks[bank_type]
		if bank.snippet_count > max_count:
			max_count = bank.snippet_count
			secondary = bank_type
	return secondary if max_count > 0 else -1

func get_today_snippet_counts() -> Dictionary:
	var counts := {}
	for t: int in [Bank.BankType.IVORAI, Bank.BankType.GLYFFINS, Bank.BankType.ZORAQIANS, Bank.BankType.YAGARI]:
		counts[t] = 0
	var today_start := _get_today_start_unix()
	for s: Dictionary in _all_snippets:
		if s["created_at"] >= today_start:
			counts[s["bank_type"]] = counts.get(s["bank_type"], 0) + 1
	return counts

func get_accent_count(secondary: int) -> int:
	var counts := get_today_snippet_counts()
	var sec_count: int = counts.get(secondary, 0)
	if sec_count >= 10:
		return 3
	if sec_count >= 5:
		return 2
	if sec_count >= 1:
		return 1
	return 0

func get_total_balance() -> float:
	var total := 0.0
	for bank: Bank in _banks.values():
		total += bank.balance
	return total

func on_tick(delta_time: float) -> void:
	for bank: Bank in _banks.values():
		bank.on_tick(delta_time)

func restore_bank(data: Dictionary) -> void:
	var bank_type: int = data.get("type", 0)
	var bank := get_bank(bank_type)
	if bank:
		bank.restore(data.get("balance", 0.0), data.get("capacity", 100), data.get("snippet_count", 0))

func restore_snippet(data: Dictionary) -> void:
	_all_snippets.append(data)
	var bank := get_bank(data.get("bank_type", 0))
	if bank:
		bank.restore_snippet(data)

func _get_today_start_unix() -> float:
	var date := Time.get_date_dict_from_system()
	var today_dict := {"year": date["year"], "month": date["month"], "day": date["day"], "hour": 0, "minute": 0, "second": 0}
	return Time.get_unix_time_from_datetime_dict(today_dict)
