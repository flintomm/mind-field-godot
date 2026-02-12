## DayUnitController — Visual controller for a DayUnit entity in the scene.
## Handles animation, morph transitions, race-specific visuals, thought bubbles, walking.
extends Node2D

@export var bob_speed: float = 1.5
@export var bob_height: float = 3.0
@export var morph_transition_time: float = 0.5
@export var pulse_speed: float = 2.0
@export var walk_speed: float = 30.0

@onready var body_sprite: Sprite2D = $BodySprite
@onready var shoes_sprite: Sprite2D = $ShoesSprite
@onready var gloves_sprite: Sprite2D = $GlovesSprite
@onready var chest_sprite: Sprite2D = $ChestSprite
@onready var helm_sprite: Sprite2D = $HelmSprite
@onready var accent_sprites: Array[Sprite2D] = [$Accent0, $Accent1, $Accent2]
@onready var thought_anchor: Marker2D = $ThoughtAnchor
@onready var shadow: Sprite2D = $Shadow

var _day_unit: DayUnit
var _base_position: Vector2
var _morph_timer: float = 0.0
var _displayed_stage: int = DayUnit.MorphStage.BASE
var _pulse_phase: float = 0.0

# Walking
var _walk_target: Vector2
var _walk_area_origin: Vector2
var _walk_area_size: Vector2 = Vector2(480, 270)
var _walk_timer: float = 0.0
var _walk_pause: float = 2.0
var _is_walking: bool = false
var _has_walk_area: bool = false

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

func bind(day_unit: DayUnit) -> void:
	_day_unit = day_unit
	_base_position = position
	_displayed_stage = DayUnit.MorphStage.BASE
	_load_race_sprite(day_unit.race_type)
	_load_morph_sprites()
	_apply_race_visuals(day_unit.race_type)
	_update_morph_visuals()
	_update_accent_visuals()
	EventBus.day_unit_morphed.connect(_on_morphed)
	EventBus.snippet_added.connect(_on_snippet_added)

func _load_race_sprite(race: int) -> void:
	if body_sprite == null:
		return
	var tex_path: String = RACE_SPRITES.get(race, RACE_SPRITES[0])
	var tex := load(tex_path) as Texture2D
	if tex:
		body_sprite.texture = tex

	# Load shadow (use same texture, dark)
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

func set_walk_area(origin: Vector2, size: Vector2) -> void:
	_walk_area_origin = origin
	_walk_area_size = size
	_has_walk_area = true
	_pick_walk_target()

func _pick_walk_target() -> void:
	if not _has_walk_area:
		return
	_walk_target = Vector2(
		randf_range(_walk_area_origin.x + 40, _walk_area_origin.x + _walk_area_size.x - 40),
		randf_range(_walk_area_origin.y + 40, _walk_area_origin.y + _walk_area_size.y - 40)
	)
	_is_walking = true

func _exit_tree() -> void:
	if EventBus.day_unit_morphed.is_connected(_on_morphed):
		EventBus.day_unit_morphed.disconnect(_on_morphed)
	if EventBus.snippet_added.is_connected(_on_snippet_added):
		EventBus.snippet_added.disconnect(_on_snippet_added)

func _process(delta: float) -> void:
	if _day_unit == null:
		return

	# Walking
	if _has_walk_area:
		if _is_walking:
			var dir := (_walk_target - position).normalized()
			var dist := position.distance_to(_walk_target)
			if dist < 3.0:
				_is_walking = false
				_walk_timer = 0.0
				_walk_pause = randf_range(1.5, 4.0)
				_base_position = position
			else:
				position += dir * walk_speed * delta
				_base_position = position
				# Flip sprite based on direction
				if body_sprite and dir.x != 0:
					body_sprite.flip_h = dir.x < 0
		else:
			_walk_timer += delta
			if _walk_timer >= _walk_pause:
				_pick_walk_target()

	# Idle bob
	var bob := sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
	if not _is_walking:
		position = _base_position + Vector2(0, -bob)

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

func _apply_race_visuals(race: int) -> void:
	if body_sprite == null:
		return
	var bank: Bank = GameManager.bank_registry.get_bank(race)
	if bank == null:
		return
	body_sprite.modulate = bank.primary_color
	match race:
		Bank.BankType.IVORAI:
			scale = Vector2(1.2, 1.0)
		Bank.BankType.GLYFFINS:
			scale = Vector2(0.95, 1.1)
		Bank.BankType.ZORAQIANS:
			scale = Vector2(1.1, 0.95)
		Bank.BankType.YAGARI:
			scale = Vector2(0.85, 1.25)

func _apply_race_pulse() -> void:
	if _day_unit == null or body_sprite == null:
		return
	var pulse := sin(_pulse_phase) * 0.1
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
			var flicker := 0.3 if randf() > 0.95 else 0.0
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
	scale = scale * scale_pop
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

func spawn_thought_bubble(content: String, bank_type: int) -> void:
	if thought_anchor == null:
		return
	var bubble := preload("res://scenes/entities/thought_bubble.tscn").instantiate()
	thought_anchor.add_child(bubble)
	var bank: Bank = GameManager.bank_registry.get_bank(bank_type)
	if bank:
		bubble.initialize(content, 3.0, bank.primary_color)

func set_base_position(pos: Vector2) -> void:
	_base_position = pos

func _on_morphed(new_stage: int, day_unit_id: String) -> void:
	if _day_unit and day_unit_id == _day_unit.id:
		_morph_timer = 0.0

func _on_snippet_added(content: String, bank_type: int, _mood: float) -> void:
	if _day_unit:
		spawn_thought_bubble(content, bank_type)
		_update_accent_visuals()
