## RaceData — Resource definition for race visual identity.
class_name RaceData
extends Resource

@export var race_type: int = 0
@export var race_name: String = ""
@export var race_tagline: String = ""

@export_group("Visual Identity")
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.GRAY
@export var accent_color_1: Color = Color.WHITE
@export var accent_color_2: Color = Color.WHITE

@export_group("Body Proportions")
@export var base_scale: Vector2 = Vector2.ONE
@export var head_ratio: float = 0.3
@export var limb_width: float = 0.15

@export_group("Animation")
@export var idle_bob_speed: float = 1.5
@export var idle_bob_height: float = 0.1
@export var pulse_speed: float = 2.0
@export var pulse_intensity: float = 0.1

@export_group("Race Flavor")
@export_multiline var visual_description: String = ""
@export_multiline var animation_notes: String = ""
