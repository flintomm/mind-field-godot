## AttendeeVisual — Retired Day Units wandering the park.
extends Node2D

@onready var body_sprite: Sprite2D = $BodySprite
@onready var stage_indicator: Sprite2D = $StageIndicator

var _race_type: int = 0
var _stage: int = 0
var _walk_target: Vector2
var _walk_timer: float = 0.0
var _walk_pause: float = 3.0
var _is_walking: bool = false
var _walk_speed: float = 15.0
var _bob_phase: float = 0.0

const RACE_SPRITES := {
	0: "res://assets/sprites/races/ivorai-base.svg",
	1: "res://assets/sprites/races/glyffins-base.svg",
	2: "res://assets/sprites/races/zoraqians-base.svg",
	3: "res://assets/sprites/races/yagari-base.svg",
}

const RACE_COLORS := {
	0: Color(0.96, 0.91, 0.78, 0.6),
	1: Color(0.75, 0.75, 0.75, 0.6),
	2: Color(0.30, 0.15, 0.35, 0.6),
	3: Color(0.12, 0.12, 0.18, 0.6),
}

func setup(day_unit: DayUnit) -> void:
	_race_type = day_unit.race_type
	_stage = day_unit.stage

	if body_sprite:
		var tex_path: String = RACE_SPRITES.get(_race_type, RACE_SPRITES[0])
		var tex := load(tex_path) as Texture2D
		if tex:
			body_sprite.texture = tex
		body_sprite.modulate = RACE_COLORS.get(_race_type, Color.WHITE)
		body_sprite.scale = Vector2(0.35, 0.35)

	# Stage indicator color
	if stage_indicator:
		stage_indicator.visible = _stage >= DayUnit.MorphStage.SHOES
		var stage_alpha := minf(float(_stage) / 4.0, 1.0) * 0.5
		stage_indicator.modulate = Color(1, 1, 1, stage_alpha)

	# Slightly transparent - they're memories
	modulate = Color(1, 1, 1, 0.7)
	scale = Vector2(0.8, 0.8)

	_walk_pause = randf_range(2.0, 6.0)
	_bob_phase = randf() * TAU

func _process(delta: float) -> void:
	_bob_phase += delta * 1.0
	var bob := sin(_bob_phase) * 2.0

	if _is_walking:
		var dir := (_walk_target - position).normalized()
		var dist := position.distance_to(_walk_target)
		if dist < 3.0:
			_is_walking = false
			_walk_timer = 0.0
			_walk_pause = randf_range(2.0, 6.0)
		else:
			position += dir * _walk_speed * delta
			if body_sprite and dir.x != 0:
				body_sprite.flip_h = dir.x < 0
	else:
		_walk_timer += delta
		if _walk_timer >= _walk_pause:
			_pick_walk_target()

	if body_sprite:
		body_sprite.position.y = bob

func _pick_walk_target() -> void:
	# Wander within 100px radius
	_walk_target = position + Vector2(randf_range(-80, 80), randf_range(-60, 60))
	_is_walking = true
