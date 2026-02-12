## LocalDataStore — JSON-based save/load to user:// directory.
extends Node

const SAVE_FILE := "user://mind-field-save.json"

func initialize() -> void:
	pass

func save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[LocalDataStore] Saved to %s" % SAVE_FILE)
	else:
		push_error("[LocalDataStore] Save failed: %s" % FileAccess.get_open_error())

func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE):
		return {}
	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		push_error("[LocalDataStore] Load failed: %s" % FileAccess.get_open_error())
		return {}
	var json_string := file.get_as_text()
	file.close()
	if json_string.is_empty():
		return {}
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[LocalDataStore] Parse failed: %s" % json.get_error_message())
		return {}
	if json.data is Dictionary:
		return json.data as Dictionary
	return {}

func delete_data() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)
