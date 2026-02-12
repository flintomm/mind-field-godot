## ThoughtBubble — Floats upward and fades out over its lifetime.
extends Node2D

var _lifetime: float = 3.0
var _elapsed: float = 0.0
var _color: Color = Color.WHITE

func _ready() -> void:
	# Load bubble sprite
	var sprite: Sprite2D = $Sprite
	if sprite:
		var tex := load("res://assets/sprites/ui/thought_bubble.svg") as Texture2D
		if tex:
			sprite.texture = tex
			sprite.scale = Vector2(0.3, 0.3)

func initialize(content: String, lifetime: float, color: Color = Color.WHITE) -> void:
	_lifetime = lifetime
	_color = color
	modulate = color
	var lbl: Label = $Label
	if lbl:
		lbl.text = content.substr(0, 20)
		lbl.add_theme_font_size_override("font_size", 9)

func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / _lifetime
	position += Vector2(0, -delta * 20.0)
	scale = Vector2.ONE * (1.0 - t * 0.3)
	modulate.a = 1.0 - t
	if _elapsed >= _lifetime:
		queue_free()
