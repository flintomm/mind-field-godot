## BankData — Resource definition for bank configuration.
class_name BankData
extends Resource

@export var bank_type: int = 0
@export var race_name: String = ""
@export var race_description: String = ""
@export var default_capacity: int = 100
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.GRAY
@export var terrain_color: Color = Color.WHITE
@export var ambient_color: Color = Color.WHITE
@export var lighting_intensity: float = 1.0
@export var theme_keywords: PackedStringArray = []
@export var deposit_multiplier: float = 1.0
@export var decay_rate_multiplier: float = 1.0
