## SelectionRing — Draws a pulsing selection circle around a unit.
extends Node2D

var _phase: float = 0.0
var ring_color: Color = Color(0.2, 1.0, 0.3, 0.8)
var ring_radius: float = 20.0

func _process(delta: float) -> void:
	_phase += delta * 3.0
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(_phase) * 0.15
	var r := ring_radius * pulse
	var color := ring_color
	color.a = 0.6 + sin(_phase * 1.5) * 0.2
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, color, 2.0, true)
	# Inner ring
	var inner_color := color
	inner_color.a *= 0.4
	draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 24, inner_color, 1.0, true)
