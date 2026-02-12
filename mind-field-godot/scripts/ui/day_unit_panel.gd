## DayUnitPanel — Inspector showing current Day Unit stats.
extends VBoxContainer

@onready var race_label: Label = %RaceLabel
@onready var stage_label: Label = %StageLabel
@onready var snippet_count_label: Label = %SnippetCountLabel
@onready var active_time_label: Label = %ActiveTimeLabel
@onready var mood_bar: ProgressBar = %MoodBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var focus_bar: ProgressBar = %FocusBar
@onready var attendee_list: VBoxContainer = %AttendeeList

const RACE_NAMES := ["Ivorai", "Glyffins", "Zoraqians", "Yagari"]
const STAGE_NAMES := ["Base", "Shoes", "Gloves", "Chest", "Helm", "Retired"]

func _process(_delta: float) -> void:
	_update_inspector()

func _update_inspector() -> void:
	var du: DayUnit = GameManager.simulation_manager.current_day_unit
	if du == null:
		if race_label:
			race_label.text = "No Day Unit yet — submit a snippet!"
		if stage_label:
			stage_label.text = ""
		if snippet_count_label:
			snippet_count_label.text = ""
		if active_time_label:
			active_time_label.text = ""
		return

	if race_label:
		race_label.text = "Race: %s" % RACE_NAMES[du.race_type] if du.race_type < RACE_NAMES.size() else "Unknown"
	if stage_label:
		stage_label.text = "Stage: %s" % STAGE_NAMES[du.stage] if du.stage < STAGE_NAMES.size() else "?"
	if snippet_count_label:
		snippet_count_label.text = "Snippets: %d" % du.snippet_count
	if active_time_label:
		active_time_label.text = "Active: %dm" % int(du.active_minutes)

	if mood_bar:
		mood_bar.value = (du.attributes.get("avg_mood", 0.0) + 1.0) / 2.0 * 100.0
	if energy_bar:
		energy_bar.value = du.attributes.get("energy", 50.0)
	if focus_bar:
		focus_bar.value = du.attributes.get("focus", 50.0)

	# Attendee list (update occasionally)
	if Engine.get_frames_drawn() % 60 == 0 and attendee_list:
		_refresh_attendees()

func _refresh_attendees() -> void:
	for child: Node in attendee_list.get_children():
		child.queue_free()
	var attendees: Array = GameManager.simulation_manager.get_attendees()
	for att: DayUnit in attendees:
		var lbl := Label.new()
		var rname: String = RACE_NAMES[att.race_type] if att.race_type < RACE_NAMES.size() else "?"
		var sname: String = STAGE_NAMES[att.stage] if att.stage < STAGE_NAMES.size() else "?"
		lbl.text = "%s — %s (Snippets: %d)" % [rname, sname, att.snippet_count]
		attendee_list.add_child(lbl)
