## DayUnitController — Visual controller for a DayUnit entity.
## Roams between districts autonomously. Click-to-inspect. Thought bubbles.
extends Node2D

@export var bob_speed: float = 1.5
@export var bob_height: float = 3.0
@export var morph_transition_time: float = 0.5
@export var pulse_speed: float = 2.0
@export var walk_speed: float = 60.0

@onready var body_sprite: Sprite2D = $BodySprite
@onready var shoes_sprite: Sprite2D = $ShoesSprite
@onready var gloves_sprite: Sprite2D = $GlovesSprite
@onready var chest_sprite: Sprite2D = $ChestSprite
@onready var helm_sprite: Sprite2D = $HelmSprite
@onready var accent_sprites: Array[Sprite2D] = [$Accent0, $Accent1, $Accent2]
@onready var thought_anchor: Marker2D = $ThoughtAnchor
@onready var shadow: Sprite2D = $Shadow
@onready var selection_ring: Node2D = $SelectionRing

var _day_unit: DayUnit
var _base_position: Vector2
var _morph_timer: float = 0.0
var _displayed_stage: int = DayUnit.MorphStage.BASE
var _pulse_phase: float = 0.0
var _selected: bool = false

# Roaming between districts
var _district_positions: Dictionary = {}
var _district_size: Vector2 = Vector2(1800, 1100)
var _pathway_points: Dictionary = {}
var _current_path: Array[Vector2] = []
var _path_index: int = 0
var _walk_target: Vector2
var _is_walking: bool = false
var _walk_timer: float = 0.0
var _walk_pause: float = 3.0
var _current_district: int = 0
var _target_district: int = -1

const RACE_SPRITES := {
	0: "res://assets/sprites/races/ivorai-base.svg",
	1: "res://assets/sprites/races/glyffins-base.svg",
	2: "res://assets/sprites/races/zoraqians-base.svg",
	3: "res://assets/sprites/races/yagari-base.svg",
}

const MORPH_SPRITES := {
	"shoes": "res://assets/sprites/morph/shoes.svg",
	"gloves": "res://assets/sprites/morph/gloves.svg",
	"chest": "res://assets/sprites/morph/chest.svg",
	"helm": "res://assets/sprites/morph/helm.svg",
}

const RACE_NAMES := ["Ivorai", "Glyffins", "Zoraqians", "Yagari"]
const STAGE_NAMES := ["Base", "Shoes", "Gloves", "Chest", "Helm", "Retired"]

func bind(day_unit: DayUnit) -> void:
	_day_unit = day_unit
	_base_position = position
	_displayed_stage = DayUnit.MorphStage.BASE
	_current_district = day_unit.race_type
	_load_race_sprite(day_unit.race_type)
	_load_morph_sprites()
	_apply_race_visuals(day_unit.race_type)
	_update_morph_visuals()
	_update_accent_visuals()
	EventBus.day_unit_morphed.connect(_on_morphed)
	EventBus.snippet_added.connect(_on_snippet_added)

func set_roam_data(positions: Dictionary, size: Vector2, pathways: Dictionary) -> void:
	_district_positions = positions
	_district_size = size
	_pathway_points = pathways
	# Start wandering within home district, then roam
	_pick_local_target()

func _load_race_sprite(race: int) -> void:
	if body_sprite == null:
		return
	var tex_path: String = RACE_SPRITES.get(race, RACE_SPRITES[0])
	var tex := load(tex_path) as Texture2D
	if tex:
		body_sprite.texture = tex
	if shadow and tex:
		shadow.texture = tex

func _load_morph_sprites() -> void:
	var tex: Texture2D
	tex = load(MORPH_SPRITES["shoes"]) as Texture2D
	if shoes_sprite and tex:
		shoes_sprite.texture = tex
	tex = load(MORPH_SPRITES["gloves"]) as Texture2D
	if gloves_sprite and tex:
		gloves_sprite.texture = tex
	tex = load(MORPH_SPRITES["chest"]) as Texture2D
	if chest_sprite and tex:
		chest_sprite.texture = tex
	tex = load(MORPH_SPRITES["helm"]) as Texture2D
	if helm_sprite and tex:
		helm_sprite.texture = tex

func _exit_tree() -> void:
	if EventBus.day_unit_morphed.is_connected(_on_morphed):
		EventBus.day_unit_morphed.disconnect(_on_morphed)
	if EventBus.snippet_added.is_connected(_on_snippet_added):
		EventBus.snippet_added.disconnect(_on_snippet_added)

func _process(delta: float) -> void:
	if _day_unit == null:
		return

	# Movement
	if _current_path.size() > 0:
		_follow_path(delta)
	elif _is_walking:
		_walk_to_target(delta)
	else:
		_walk_timer += delta
		if _walk_timer >= _walk_pause:
			# Decide: wander locally or travel to another district
			if randf() < 0.3 and _district_positions.size() > 1:
				_plan_district_travel()
			else:
				_pick_local_target()

	# Idle bob when stationary
	if not _is_walking and _current_path.size() == 0:
		var bob := sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
		position = _base_position + Vector2(0, -bob)

	# Y-sort hint
	z_index = int(position.y)

	# Race pulse
	_pulse_phase += delta * pulse_speed
	_apply_race_pulse()

	# Morph transition
	if _displayed_stage != _day_unit.stage:
		_morph_timer += delta
		if _morph_timer >= morph_transition_time:
			_displayed_stage = _day_unit.stage
			_morph_timer = 0.0
			_update_morph_visuals()
		else:
			var t := _morph_timer / morph_transition_time
			_apply_morph_transition(t)

	# Selection ring
	if selection_ring:
		selection_ring.visible = _selected

func _walk_to_target(delta: float) -> void:
	var dir := (_walk_target - position).normalized()
	var dist := position.distance_to(_walk_target)
	if dist < 5.0:
		_is_walking = false
		_walk_timer = 0.0
		_walk_pause = randf_range(2.0, 5.0)
		_base_position = position
	else:
		position += dir * walk_speed * delta
		_base_position = position
		if body_sprite and dir.x != 0:
			body_sprite.flip_h = dir.x < 0

func _follow_path(delta: float) -> void:
	if _path_index >= _current_path.size():
		_current_path.clear()
		_path_index = 0
		_is_walking = false
		_walk_timer = 0.0
		_walk_pause = randf_range(2.0, 6.0)
		_base_position = position
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
		position += dir * walk_speed * delta
		_base_position = position
		if body_sprite and dir.x != 0:
			body_sprite.flip_h = dir.x < 0

func _pick_local_target() -> void:
	var dist_pos: Vector2 = _district_positions.get(_current_district, Vector2(2400, 1600))
	_walk_target = dist_pos + Vector2(
		randf_range(100, _district_size.x - 100),
		randf_range(100, _district_size.y - 100)
	)
	_is_walking = true
	_walk_timer = 0.0

func _plan_district_travel() -> void:
	# Pick a random different district
	var options: Array[int] = []
	for d: int in _district_positions.keys():
		if d != _current_district:
			options.append(d)
	if options.is_empty():
		_pick_local_target()
		return

	_target_district = options[randi() % options.size()]

	# Build path: current pos -> pathway -> target district center
	_current_path.clear()
	var pathway_key := _get_pathway_key(_current_district, _target_district)
	if _pathway_points.has(pathway_key):
		var pts: Array = _pathway_points[pathway_key]
		# Determine direction
		if _needs_reverse(pathway_key, _current_district):
			for i in range(pts.size() - 1, -1, -1):
				_current_path.append(pts[i] as Vector2)
		else:
			for p: Vector2 in pts:
				_current_path.append(p)

	# End at random point in target district
	var target_pos: Vector2 = _district_positions.get(_target_district, Vector2(2400, 1600))
	_current_path.append(target_pos + Vector2(
		randf_range(200, _district_size.x - 200),
		randf_range(200, _district_size.y - 200)
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

func _apply_race_visuals(race: int) -> void:
	if body_sprite == null:
		return
	var bank: Bank = GameManager.bank_registry.get_bank(race)
	if bank == null:
		return
	body_sprite.modulate = bank.primary_color

func _apply_race_pulse() -> void:
	if _day_unit == null or body_sprite == null:
		return
	var pulse := sin(_pulse_phase) * 0.08
	var base_c := body_sprite.modulate
	match _day_unit.race_type:
		Bank.BankType.IVORAI:
			body_sprite.modulate = Color(base_c.r, base_c.g, base_c.b + pulse * 0.3, 1.0)
		Bank.BankType.GLYFFINS:
			var shimmer := absf(pulse)
			body_sprite.modulate = Color(base_c.r + shimmer, base_c.g + shimmer, base_c.b + shimmer, 1.0)
		Bank.BankType.ZORAQIANS:
			body_sprite.modulate = Color(base_c.r + pulse * 0.5, base_c.g, base_c.b + pulse * 0.2, 1.0)
		Bank.BankType.YAGARI:
			var flicker := 0.3 if randf() > 0.97 else 0.0
			body_sprite.modulate = Color(base_c.r, base_c.g, base_c.b + flicker, 1.0)

func _update_morph_visuals() -> void:
	if shoes_sprite:
		shoes_sprite.visible = _displayed_stage >= DayUnit.MorphStage.SHOES
	if gloves_sprite:
		gloves_sprite.visible = _displayed_stage >= DayUnit.MorphStage.GLOVES
	if chest_sprite:
		chest_sprite.visible = _displayed_stage >= DayUnit.MorphStage.CHEST
	if helm_sprite:
		helm_sprite.visible = _displayed_stage >= DayUnit.MorphStage.HELM

func _apply_morph_transition(t: float) -> void:
	var scale_pop := 1.0 + sin(t * PI) * 0.2
	scale = Vector2.ONE * scale_pop
	if body_sprite:
		body_sprite.modulate = body_sprite.modulate.lerp(Color.WHITE, sin(t * PI) * 0.5)

func _update_accent_visuals() -> void:
	if _day_unit == null:
		return
	var secondary := _day_unit.get_secondary_race()
	var count := _day_unit.get_accent_count()
	var accent_color := Color.WHITE
	if secondary >= 0:
		var sec_bank: Bank = GameManager.bank_registry.get_bank(secondary)
		if sec_bank:
			accent_color = sec_bank.secondary_color
	for i: int in range(accent_sprites.size()):
		if accent_sprites[i] == null:
			continue
		accent_sprites[i].visible = i < count and secondary >= 0
		if accent_sprites[i].visible:
			accent_sprites[i].modulate = accent_color

# --- Selection / Inspect ---

func set_selected(sel: bool) -> void:
	_selected = sel

func get_info() -> Dictionary:
	if _day_unit == null:
		return {}
	
	# Format birthday
	var unix_time: float = _day_unit.date_unix
	var date_dict: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_time))
	var birthday_str: String = "%02d/%02d/%d" % [date_dict["month"], date_dict["day"], date_dict["year"]]
	
	# Get thoughts from bank snippets
	var thoughts_text: String = ""
	var br: Node = GameManager.bank_registry
	if br:
		var snippets: Array = br.get_today_snippets_for_day_unit(_day_unit.id)
		if snippets.size() > 0:
			for i in range(min(snippets.size(), 5)):
				var snippet: Dictionary = snippets[i]
				thoughts_text += "• %s\n" % snippet.get("content", "").left(40)
	
	return {
		"type": "day_unit",
		"name": "Day Unit #%s" % _day_unit.id.substr(0, 6),
		"race": RACE_NAMES[_day_unit.race_type] if _day_unit.race_type < RACE_NAMES.size() else "Unknown",
		"race_type": _day_unit.race_type,
		"stage": STAGE_NAMES[_day_unit.stage] if _day_unit.stage < STAGE_NAMES.size() else "?",
		"stage_idx": _day_unit.stage,
		"snippet_count": _day_unit.snippet_count,
		"active_minutes": _day_unit.active_minutes,
		"energy": _day_unit.attributes.get("energy", 50.0),
		"focus": _day_unit.attributes.get("focus", 50.0),
		"avg_mood": _day_unit.attributes.get("avg_mood", 0.0),
		"current_district": _current_district,
		"birthday": birthday_str,
		"thoughts_text": thoughts_text.strip_edges(),
		"bio": _get_race_bio(_day_unit.race_type),
	}

func _get_race_bio(race: int) -> String:
	match race:
		0: return "Ivorai — Creatures of warm light and introspection. They thrive in golden groves."
		1: return "Glyffins — Geometric beings of logic and craft. Precision is their nature."
		2: return "Zoraqians — Enigmatic entities from the deep. They feed on raw emotion."
		3: return "Yagari — Shadow-dwellers who find strength in darkness and quiet reflection."
	return "Unknown origin."

func spawn_thought_bubble(content: String, bank_type: int) -> void:
	if thought_anchor == null:
		return
	var bubble := preload("res://scenes/entities/thought_bubble.tscn").instantiate()
	thought_anchor.add_child(bubble)
	var bank: Bank = GameManager.bank_registry.get_bank(bank_type)
	if bank:
		bubble.initialize(content, 3.0, bank.primary_color, bank_type)

func _on_morphed(new_stage: int, day_unit_id: String) -> void:
	if _day_unit and day_unit_id == _day_unit.id:
		_morph_timer = 0.0

func _on_snippet_added(content: String, bank_type: int, _mood: float) -> void:
	if _day_unit:
		spawn_thought_bubble(content, bank_type)
		_update_accent_visuals()
