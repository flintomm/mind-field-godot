## AttendeeVisual — Retired Day Units wandering the entire park between districts.
extends Node2D

@onready var body_sprite: Sprite2D = $BodySprite
@onready var stage_indicator: Sprite2D = $StageIndicator
@onready var selection_ring: Node2D = $SelectionRing

var _day_unit_data: DayUnit
var _race_type: int = 0
var _stage: int = 0
var _selected: bool = false

# Roaming
var _district_positions: Dictionary = {}
var _district_size: Vector2 = Vector2(1800, 1100)
var _pathway_points: Dictionary = {}
var _current_district: int = 0
var _target_district: int = -1

var _current_path: Array[Vector2] = []
var _path_index: int = 0
var _walk_target: Vector2
var _walk_timer: float = 0.0
var _walk_pause: float = 3.0
var _is_walking: bool = false
var _walk_speed: float = 35.0
var _bob_phase: float = 0.0

const RACE_SPRITES := {
	0: "res://assets/sprites/races/ivorai-base.svg",
	1: "res://assets/sprites/races/glyffins-base.svg",
	2: "res://assets/sprites/races/zoraqians-base.svg",
	3: "res://assets/sprites/races/yagari-base.svg",
}

const RACE_COLORS := {
	0: Color(0.96, 0.91, 0.78, 0.7),
	1: Color(0.75, 0.75, 0.75, 0.7),
	2: Color(0.30, 0.15, 0.35, 0.7),
	3: Color(0.12, 0.12, 0.18, 0.7),
}

const RACE_NAMES := ["Ivorai", "Glyffins", "Zoraqians", "Yagari"]
const STAGE_NAMES := ["Base", "Shoes", "Gloves", "Chest", "Helm", "Retired"]

func setup(day_unit: DayUnit, positions: Dictionary, size: Vector2, pathways: Dictionary) -> void:
	_day_unit_data = day_unit
	_race_type = day_unit.race_type
	_stage = day_unit.stage
	_current_district = day_unit.race_type
	_district_positions = positions
	_district_size = size
	_pathway_points = pathways

	if body_sprite:
		var tex_path: String = RACE_SPRITES.get(_race_type, RACE_SPRITES[0])
		var tex := load(tex_path) as Texture2D
		if tex:
			body_sprite.texture = tex
		body_sprite.modulate = RACE_COLORS.get(_race_type, Color.WHITE)
		body_sprite.scale = Vector2(0.35, 0.35)

	if stage_indicator:
		stage_indicator.visible = _stage >= DayUnit.MorphStage.SHOES
		var stage_alpha := minf(float(_stage) / 4.0, 1.0) * 0.5
		stage_indicator.modulate = Color(1, 1, 1, stage_alpha)

	modulate = Color(1, 1, 1, 0.75)
	_walk_pause = randf_range(2.0, 6.0)
	_bob_phase = randf() * TAU
	_walk_speed = randf_range(25.0, 45.0)

func _process(delta: float) -> void:
	_bob_phase += delta * 1.0
	var bob := sin(_bob_phase) * 2.0

	if _current_path.size() > 0:
		_follow_path(delta)
	elif _is_walking:
		var dir := (_walk_target - position).normalized()
		var dist := position.distance_to(_walk_target)
		if dist < 5.0:
			_is_walking = false
			_walk_timer = 0.0
			_walk_pause = randf_range(3.0, 8.0)
			if _target_district >= 0:
				_current_district = _target_district
				_target_district = -1
		else:
			position += dir * _walk_speed * delta
			if body_sprite and dir.x != 0:
				body_sprite.flip_h = dir.x < 0
	else:
		_walk_timer += delta
		if _walk_timer >= _walk_pause:
			if randf() < 0.25 and _district_positions.size() > 1:
				_plan_district_travel()
			else:
				_pick_local_target()

	if body_sprite:
		body_sprite.position.y = bob

	z_index = int(position.y)

	if selection_ring:
		selection_ring.visible = _selected

func _follow_path(delta: float) -> void:
	if _path_index >= _current_path.size():
		_current_path.clear()
		_path_index = 0
		_is_walking = false
		_walk_timer = 0.0
		_walk_pause = randf_range(2.0, 6.0)
		if _target_district >= 0:
			_current_district = _target_district
			_target_district = -1
		return

	var target: Vector2 = _current_path[_path_index]
	var dir := (target - position).normalized()
	var dist := target.distance_to(position)
	if dist < 8.0:
		_path_index += 1
	else:
		position += dir * _walk_speed * delta
		if body_sprite and dir.x != 0:
			body_sprite.flip_h = dir.x < 0

func _pick_local_target() -> void:
	var dist_pos: Vector2 = _district_positions.get(_current_district, Vector2(2400, 1600))
	_walk_target = dist_pos + Vector2(
		randf_range(80, _district_size.x - 80),
		randf_range(80, _district_size.y - 80)
	)
	_is_walking = true
	_walk_timer = 0.0

func _plan_district_travel() -> void:
	var options: Array[int] = []
	for d: int in _district_positions.keys():
		if d != _current_district:
			options.append(d)
	if options.is_empty():
		_pick_local_target()
		return

	_target_district = options[randi() % options.size()]
	_current_path.clear()

	var pathway_key := _get_pathway_key(_current_district, _target_district)
	if _pathway_points.has(pathway_key):
		var pts: Array = _pathway_points[pathway_key]
		if _needs_reverse(pathway_key, _current_district):
			for i in range(pts.size() - 1, -1, -1):
				_current_path.append(pts[i] as Vector2)
		else:
			for p: Vector2 in pts:
				_current_path.append(p)

	var target_pos: Vector2 = _district_positions.get(_target_district, Vector2(2400, 1600))
	_current_path.append(target_pos + Vector2(
		randf_range(150, _district_size.x - 150),
		randf_range(150, _district_size.y - 150)
	))
	_path_index = 0
	_is_walking = true

func _get_pathway_key(from: int, to: int) -> String:
	var names: Array[String] = ["ivorai", "glyffins", "zoraqians", "yagari"]
	var a: String = names[from] if from < names.size() else "unknown"
	var b: String = names[to] if to < names.size() else "unknown"
	var key1: String = a + "_" + b
	var key2: String = b + "_" + a
	if _pathway_points.has(key1):
		return key1
	if _pathway_points.has(key2):
		return key2
	return key1

func _needs_reverse(key: String, from_district: int) -> bool:
	var names := ["ivorai", "glyffins", "zoraqians", "yagari"]
	var from_name: String = names[from_district] if from_district < names.size() else ""
	return not key.begins_with(from_name)

# --- Selection / Inspect ---

func set_selected(sel: bool) -> void:
	_selected = sel

func get_info() -> Dictionary:
	if _day_unit_data == null:
		return {}
	
	# Format birthday
	var unix_time: float = _day_unit_data.date_unix
	var date_dict: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_time))
	var birthday_str: String = "%02d/%02d/%d" % [date_dict["month"], date_dict["day"], date_dict["year"]]
	
	# Get thoughts from stored snippets
	var thoughts_text: String = ""
	var gm: Node = GameManager
	if gm and gm.bank_registry:
		var snippets: Array = gm.bank_registry.get_snippets_for_day_unit(_day_unit_data.id)
		if snippets.size() > 0:
			for i in range(min(snippets.size(), 5)):
				var snippet: Dictionary = snippets[i]
				thoughts_text += "• %s\n" % snippet.get("content", "").left(40)
	
	return {
		"type": "attendee",
		"name": "Attendee #%s" % _day_unit_data.id.substr(0, 6),
		"race": RACE_NAMES[_race_type] if _race_type < RACE_NAMES.size() else "Unknown",
		"race_type": _race_type,
		"stage": STAGE_NAMES[_stage] if _stage < STAGE_NAMES.size() else "?",
		"stage_idx": _stage,
		"snippet_count": _day_unit_data.snippet_count,
		"active_minutes": _day_unit_data.active_minutes,
		"energy": _day_unit_data.attributes.get("energy", 50.0),
		"focus": _day_unit_data.attributes.get("focus", 50.0),
		"avg_mood": _day_unit_data.attributes.get("avg_mood", 0.0),
		"current_district": _current_district,
		"birthday": birthday_str,
		"thoughts_text": thoughts_text.strip_edges(),
		"bio": _get_race_bio(_race_type),
	}

func _get_race_bio(race: int) -> String:
	match race:
		0: return "A retired Ivorai — golden memories of warmth and introspection linger."
		1: return "A retired Glyffinwork — precise patterns etched into park history."
		2: return "A retired Zoraqian — deep emotional echoes still ripple through."
		3: return "A retired Yagari — shadow memories that strengthen with time."
	return "A mysterious retired unit."
