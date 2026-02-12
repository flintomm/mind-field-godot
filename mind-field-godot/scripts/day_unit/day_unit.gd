## DayUnit — Represents a single day's emotional avatar. Morphs as engagement increases.
class_name DayUnit
extends RefCounted

enum MorphStage { BASE = 0, SHOES = 1, GLOVES = 2, CHEST = 3, HELM = 4, RETIRED = 5 }

const MORPH_THRESHOLDS := [0.0, 30.0, 60.0, 120.0, 240.0]

var id: String
var date_unix: float
var race_type: int  # Bank.BankType
var stage: int = MorphStage.BASE
var snippet_count: int = 0
var active_minutes: float = 0.0
var attributes: Dictionary = {}

var _secondary_race: int = -1
var _accent_count: int = 0
var _last_snippet_time: float = -1.0
var _spam_count: int = 0

func _init(date: float, race: int) -> void:
	id = str(randi()) + "_" + str(Time.get_ticks_msec())
	date_unix = date
	race_type = race
	stage = MorphStage.BASE
	attributes = {
		"avg_mood": 0.0,
		"total_mood": 0.0,
		"avg_spacing": 0.0,
		"energy": 50.0,
		"focus": 50.0,
		"variety": 0.0,
	}

func accumulate_snippet(snippet: Dictionary, spacing_minutes: float) -> void:
	snippet_count += 1

	# Spam detection: <30 sec between inputs
	var is_spam := spacing_minutes < 0.5 and _last_snippet_time >= 0.0
	if is_spam:
		_spam_count += 1
		attributes["energy"] = maxf(0.0, attributes["energy"] - 1.0)
		_last_snippet_time = Time.get_unix_time_from_system()
		return

	_spam_count = 0
	_last_snippet_time = Time.get_unix_time_from_system()

	var mood: float = snippet.get("mood_score", 0.0)
	var total_mood: float = attributes["total_mood"] + mood
	attributes["total_mood"] = total_mood
	attributes["avg_mood"] = total_mood / snippet_count

	# Spacing affects focus
	if spacing_minutes > 5.0 and spacing_minutes < 120.0:
		attributes["focus"] = minf(100.0, attributes["focus"] + 3.0)
	elif spacing_minutes < 2.0:
		attributes["focus"] = maxf(0.0, attributes["focus"] - 2.0)

	var old_avg_spacing: float = attributes["avg_spacing"]
	attributes["avg_spacing"] = old_avg_spacing + (spacing_minutes - old_avg_spacing) / snippet_count

	attributes["energy"] = clampf(attributes["energy"] + mood * 5.0, 0.0, 100.0)

func update_active_time(additional_minutes: float) -> void:
	active_minutes += additional_minutes
	_check_morph_progression()

func _check_morph_progression() -> void:
	var new_stage := stage
	if active_minutes >= MORPH_THRESHOLDS[4] and stage < MorphStage.HELM:
		new_stage = MorphStage.HELM
	elif active_minutes >= MORPH_THRESHOLDS[3] and stage < MorphStage.CHEST:
		new_stage = MorphStage.CHEST
	elif active_minutes >= MORPH_THRESHOLDS[2] and stage < MorphStage.GLOVES:
		new_stage = MorphStage.GLOVES
	elif active_minutes >= MORPH_THRESHOLDS[1] and stage < MorphStage.SHOES:
		new_stage = MorphStage.SHOES

	if new_stage != stage:
		stage = new_stage
		EventBus.day_unit_morphed.emit(stage, id)

func set_fusion(secondary: int, accent_count: int) -> void:
	_secondary_race = secondary
	_accent_count = clampi(accent_count, 0, 3)

func get_secondary_race() -> int:
	return _secondary_race

func get_accent_count() -> int:
	return _accent_count

func is_spamming() -> bool:
	return _spam_count >= 3

func retire() -> void:
	stage = MorphStage.RETIRED

func to_dict() -> Dictionary:
	return {
		"id": id,
		"date_unix": date_unix,
		"race_type": race_type,
		"stage": stage,
		"snippet_count": snippet_count,
		"active_minutes": active_minutes,
		"attributes": attributes.duplicate(),
	}

func restore_from(data: Dictionary) -> void:
	id = data.get("id", id)
	date_unix = data.get("date_unix", date_unix)
	race_type = data.get("race_type", race_type)
	stage = data.get("stage", MorphStage.BASE)
	snippet_count = data.get("snippet_count", 0)
	active_minutes = data.get("active_minutes", 0.0)
	if data.has("attributes"):
		attributes = data["attributes"].duplicate()
