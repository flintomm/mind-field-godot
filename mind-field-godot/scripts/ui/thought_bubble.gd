## ThoughtBubble — Floats upward and fades out. Bank-specific visual styles.
extends Node2D

var _lifetime: float = 4.0
var _elapsed: float = 0.0
var _color: Color = Color.WHITE
var _bank_type: int = 0
var _sway_phase: float = 0.0

func _ready() -> void:
	var sprite: Sprite2D = $Sprite
	if sprite:
		var tex := load("res://assets/sprites/ui/thought_bubble.svg") as Texture2D
		if tex:
			sprite.texture = tex
			sprite.scale = Vector2(0.4, 0.4)
	_sway_phase = randf() * TAU

func initialize(content: String, lifetime: float, color: Color = Color.WHITE, bank_type: int = 0) -> void:
	_lifetime = lifetime
	_color = color
	_bank_type = bank_type
	modulate = color
	modulate.a = 0.9

	var lbl: Label = $Label
	if lbl:
		# Show more of the thought
		var display_text := content.substr(0, 30)
		if content.length() > 30:
			display_text += "..."
		lbl.text = display_text
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color.WHITE)

	# Bank-specific bubble style
	var sprite: Sprite2D = $Sprite
	if sprite:
		match bank_type:
			0:  # Ivorai - warm glow
				sprite.modulate = Color(1.0, 0.9, 0.6, 0.85)
			1:  # Glyffins - cool metallic
				sprite.modulate = Color(0.8, 0.85, 1.0, 0.85)
			2:  # Zoraqians - purple mist
				sprite.modulate = Color(0.7, 0.4, 0.9, 0.85)
			3:  # Yagari - dark ethereal
				sprite.modulate = Color(0.4, 0.5, 0.7, 0.85)

func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / _lifetime
	_sway_phase += delta * 2.0

	# Float upward with gentle sway
	var sway := sin(_sway_phase) * 15.0
	position += Vector2(sway * delta, -delta * 30.0)

	# Scale down gently
	scale = Vector2.ONE * (1.0 - t * 0.2)

	# Fade out in last 40%
	if t > 0.6:
		modulate.a = (1.0 - t) / 0.4 * 0.9
	
	# Bank-specific animations
	match _bank_type:
		0:  # Ivorai - gentle pulse
			var pulse := sin(_elapsed * 3.0) * 0.05
			scale += Vector2(pulse, pulse)
		2:  # Zoraqians - slight wobble
			rotation = sin(_elapsed * 4.0) * 0.05
		3:  # Yagari - flicker
			if randf() > 0.95:
				modulate.a *= 0.5

	if _elapsed >= _lifetime:
		queue_free()
