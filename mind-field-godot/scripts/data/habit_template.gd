## HabitTemplate — Resource definition for habit template configuration.
class_name HabitTemplate
extends Resource

@export var template_name: String = ""
@export var foundation: int = 0
@export var description: String = ""
@export var theme_color: Color = Color.WHITE
@export var default_decay_rate: float = 0.95
@export var default_completion_boost: float = 20.0
@export var time_window_start: float = 0.0
@export var time_window_end: float = 24.0
@export var streak_milestone: int = 7
@export var duration_bucket: float = 30.0
@export var max_module_slots: int = 5
@export var silhouette_description: String = ""
