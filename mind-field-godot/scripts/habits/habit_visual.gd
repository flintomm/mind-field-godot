## HabitVisual — Visual representation of a habit structure in the park.
extends Node2D

@onready var foundation_sprite: Sprite2D = $FoundationSprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel
@onready var level_label: Label = $LevelLabel
@onready var module_slots: Node2D = $ModuleSlots

var _habit_id: String
var _foundation: int
var _pulse_phase: float = 0.0

const FOUNDATION_SPRITES := {
	0: "res://assets/sprites/habits/station.svg",
	1: "res://assets/sprites/habits/workshop.svg",
	2: "res://assets/sprites/habits/sanctuary.svg",
	3: "res://assets/sprites/habits/forge.svg",
	4: "res://assets/sprites/habits/market.svg",
}

const MODULE_POSITIONS := {
	0: Vector2(-25, 0),   # LEFT
	1: Vector2(25, 0),    # RIGHT
	2: Vector2(0, -25),   # TOP
	3: Vector2(0, 15),    # FRONT
	4: Vector2(0, -15),   # BACK
}

func setup(habit: Habit) -> void:
	_habit_id = habit.id
	_foundation = habit.foundation

	# Load foundation sprite
	if foundation_sprite:
		var tex_path: String = FOUNDATION_SPRITES.get(habit.foundation, FOUNDATION_SPRITES[0])
		var tex := load(tex_path) as Texture2D
		if tex:
			foundation_sprite.texture = tex
			foundation_sprite.scale = Vector2(0.4, 0.4)
		foundation_sprite.modulate = Habit.FOUNDATION_COLORS.get(habit.foundation, Color.WHITE)

	refresh(habit)

func refresh(habit: Habit) -> void:
	# Health bar
	if health_bar:
		health_bar.value = habit.health
		health_bar.modulate = habit.get_health_color()

	# Name
	if name_label:
		name_label.text = habit.habit_name
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color.WHITE)

	# Level
	if level_label:
		level_label.text = "Lv.%d" % habit.level
		level_label.add_theme_font_size_override("font_size", 9)

	# Modules
	_update_modules(habit)

	# Dead habits look ghostly
	if habit.is_dead():
		modulate = Color(0.5, 0.5, 0.5, 0.4)
	elif habit.is_decaying():
		modulate = Color(1, 0.8, 0.6, 0.8)
	else:
		modulate = Color.WHITE

func _update_modules(habit: Habit) -> void:
	if module_slots == null:
		return
	# Clear old
	for child: Node in module_slots.get_children():
		child.queue_free()
	# Add module indicators
	for m: Dictionary in habit.get_modules():
		var slot: int = m.get("slot", 0)
		var indicator := ColorRect.new()
		indicator.size = Vector2(8, 8)
		indicator.position = MODULE_POSITIONS.get(slot, Vector2.ZERO) - Vector2(4, 4)
		match m.get("type", 0):
			Habit.ModuleType.STRUCTURAL:
				indicator.color = Color(0.3, 0.7, 1.0, 0.8)
			Habit.ModuleType.UTILITY:
				indicator.color = Color(0.3, 1.0, 0.3, 0.8)
			Habit.ModuleType.COSMETIC:
				indicator.color = Color(1.0, 0.8, 0.2, 0.8)
		module_slots.add_child(indicator)

func _process(delta: float) -> void:
	# Gentle bob for alive habits
	_pulse_phase += delta * 1.0
	var bob := sin(_pulse_phase) * 1.5
	if foundation_sprite:
		foundation_sprite.position.y = bob
