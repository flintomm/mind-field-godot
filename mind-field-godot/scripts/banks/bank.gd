## Bank — Represents one of the four emotional banks (Ivorai, Glyffins, Zoraqians, Yagari).
## Pure data class, no Node dependency.
class_name Bank
extends RefCounted

enum BankType { IVORAI = 0, GLYFFINS = 1, ZORAQIANS = 2, YAGARI = 3 }

var id: String
var type: int  # BankType
var balance: float = 0.0
var capacity: int = 100
var snippet_count: int = 0
var primary_color: Color
var secondary_color: Color
var race_name: String

var _snippets: Array[Dictionary] = []

func _init(bank_type: int, cap: int = 100) -> void:
	id = _generate_id()
	type = bank_type
	capacity = cap
	_apply_theme()

func _apply_theme() -> void:
	match type:
		BankType.IVORAI:
			primary_color = Color(0.96, 0.91, 0.78)
			secondary_color = Color(0.80, 0.60, 0.20)
			race_name = "Ivorai"
		BankType.GLYFFINS:
			primary_color = Color(0.75, 0.75, 0.75)
			secondary_color = Color(0.72, 0.58, 0.20)
			race_name = "Glyffins"
		BankType.ZORAQIANS:
			primary_color = Color(0.30, 0.15, 0.35)
			secondary_color = Color(0.55, 0.85, 0.25)
			race_name = "Zoraqians"
		BankType.YAGARI:
			primary_color = Color(0.12, 0.12, 0.18)
			secondary_color = Color(0.40, 0.55, 0.65)
			race_name = "Yagari"

func deposit(amount: float) -> void:
	var old := balance
	balance = minf(balance + absf(amount), float(capacity))
	if absf(balance - old) > 0.01:
		EventBus.bank_balance_changed.emit(type, balance)

func withdraw(amount: float) -> bool:
	if balance < amount:
		return false
	balance -= amount
	EventBus.bank_balance_changed.emit(type, balance)
	return true

func add_snippet(content: String, mood_score: float) -> Dictionary:
	var snippet := {
		"id": _generate_id(),
		"content": content,
		"bank_type": type,
		"mood_score": clampf(mood_score, -1.0, 1.0),
		"created_at": Time.get_unix_time_from_system(),
	}
	_snippets.append(snippet)
	snippet_count += 1
	var deposit_amount := (1.0 + absf(mood_score)) * 5.0
	deposit(deposit_amount)
	return snippet

func get_snippets() -> Array[Dictionary]:
	return _snippets

func get_snippets_since(since_unix: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s: Dictionary in _snippets:
		if s["created_at"] >= since_unix:
			result.append(s)
	return result

func restore(bal: float, cap: int, scount: int) -> void:
	balance = bal
	capacity = cap
	snippet_count = scount

func restore_snippet(snippet: Dictionary) -> void:
	_snippets.append(snippet)

func on_tick(delta_time: float) -> void:
	if balance > 0.0:
		balance = maxf(0.0, balance - 0.001 * delta_time)

func to_dict() -> Dictionary:
	return {
		"type": type,
		"balance": balance,
		"capacity": capacity,
		"snippet_count": snippet_count,
	}

static func _generate_id() -> String:
	return str(randi()) + "_" + str(Time.get_ticks_msec())
