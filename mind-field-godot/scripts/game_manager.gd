## GameManager — Singleton orchestrator. Initializes all systems, handles auto-save.
## Autoloaded singleton.
extends Node

var state_manager: Node
var time_manager: Node
var bank_registry: Node
var habit_system: Node
var district_manager: Node
var simulation_manager: Node
var data_store: Node

var _initialized := false
var _auto_save_timer := 0.0
var _auto_save_interval := 300.0  # 5 minutes

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _initialized:
		return

	# Create system nodes
	state_manager = _create_system("res://scripts/state_manager.gd", "StateManager")
	time_manager = _create_system("res://scripts/time_manager.gd", "TimeManager")
	bank_registry = _create_system("res://scripts/banks/bank_registry.gd", "BankRegistry")
	habit_system = _create_system("res://scripts/habits/habit_system.gd", "HabitSystem")
	district_manager = _create_system("res://scripts/districts/district_manager.gd", "DistrictManager")
	simulation_manager = _create_system("res://scripts/simulation/simulation_manager.gd", "SimulationManager")
	data_store = _create_system("res://scripts/data/local_data_store.gd", "LocalDataStore")

	# Initialize in order
	state_manager.initialize()
	time_manager.initialize()
	bank_registry.initialize()
	habit_system.initialize()
	district_manager.initialize()
	simulation_manager.initialize()
	data_store.initialize()

	# Load or start new
	load_game()

	_initialized = true
	print("[GameManager] Mind-Field initialized.")

func _create_system(script_path: String, node_name: String) -> Node:
	var node := Node.new()
	node.name = node_name
	node.set_script(load(script_path))
	add_child(node)
	return node

func _process(delta: float) -> void:
	if not _initialized:
		return
	_auto_save_timer += delta
	if _auto_save_timer >= _auto_save_interval:
		_auto_save_timer = 0.0
		save_game()

func save_game() -> void:
	var save_data: Dictionary = state_manager.export_state()
	data_store.save_data(save_data)
	EventBus.game_saved.emit()
	print("[GameManager] Game saved.")

func load_game() -> void:
	var save_data: Dictionary = data_store.load_data()
	if not save_data.is_empty():
		state_manager.import_state(save_data)
		EventBus.game_loaded.emit()
		print("[GameManager] Game loaded.")
	else:
		state_manager.initialize_new_game()
		print("[GameManager] New game started.")

func reset_game() -> void:
	data_store.delete_data()
	state_manager.initialize_new_game()
	print("[GameManager] Game reset.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _initialized:
		save_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and _initialized:
		save_game()
