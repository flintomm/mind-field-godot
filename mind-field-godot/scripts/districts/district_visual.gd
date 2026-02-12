## DistrictVisual — Large organic district terrain with distinct visual identity.
extends Node2D

@onready var terrain: Polygon2D = $Terrain
@onready var name_label: Label = $NameLabel
@onready var traffic_label: Label = $TrafficLabel
@onready var grid_overlay: Node2D = $GridOverlay
@onready var particles: GPUParticles2D = $AmbientParticles

var _border_lines: Node2D
var _district: District
var _size: Vector2
var _pulse_phase: float = 0.0
var _corner_points: Array[Vector2] = []
var _random_seed: int = 0

func setup(district: District, size: Vector2) -> void:
	_district = district
	_size = size
	_random_seed = hash(district.district_name) & 0x7FFFFFFF
	_border_lines = get_node_or_null("BorderLines")

	_generate_organic_shape()

	if terrain:
		terrain.polygon = PackedVector2Array(_corner_points)
		terrain.color = district.terrain_color

	_draw_border()

	if name_label:
		name_label.text = district.district_name
		name_label.position = Vector2(_size.x / 2.0 - 100, 30)
		name_label.size = Vector2(200, 40)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", district.ambient_color.lerp(Color.WHITE, 0.6))
		name_label.add_theme_font_size_override("font_size", 22)

	if traffic_label:
		traffic_label.position = Vector2(_size.x / 2.0 - 80, _size.y - 50)
		traffic_label.size = Vector2(160, 30)
		traffic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		traffic_label.add_theme_font_size_override("font_size", 13)

	_draw_terrain_details()
	_setup_particles()

func _generate_organic_shape() -> void:
	_corner_points.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _random_seed

	# Create organic blob shape using perturbed ellipse
	var center := _size / 2.0
	var rx := _size.x * 0.45
	var ry := _size.y * 0.45
	var num_points := 24

	for i in range(num_points):
		var angle := float(i) / float(num_points) * TAU
		var noise := rng.randf_range(-0.08, 0.08)
		var r_x := rx * (1.0 + noise + sin(angle * 3.0) * 0.06)
		var r_y := ry * (1.0 + noise + cos(angle * 2.0) * 0.05)
		var point := center + Vector2(cos(angle) * r_x, sin(angle) * r_y)
		_corner_points.append(point)

func _draw_border() -> void:
	if _border_lines == null:
		return
	for child in _border_lines.get_children():
		child.queue_free()

	# Main border
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = _district.ambient_color.lerp(Color.WHITE, 0.3)
	line.default_color.a = 0.6
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	for p: Vector2 in _corner_points:
		line.add_point(p)
	line.add_point(_corner_points[0])  # Close
	_border_lines.add_child(line)

	# Outer glow border
	var glow := Line2D.new()
	glow.width = 8.0
	glow.default_color = _district.ambient_color
	glow.default_color.a = 0.15
	for p: Vector2 in _corner_points:
		glow.add_point(p)
	glow.add_point(_corner_points[0])
	glow.z_index = -1
	_border_lines.add_child(glow)

func _draw_terrain_details() -> void:
	if grid_overlay == null:
		return
	for child in grid_overlay.get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = _random_seed + 10

	# Scatter terrain detail dots instead of grid lines for organic feel
	var num_details := 30
	var center := _size / 2.0
	for i in range(num_details):
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(50, minf(_size.x, _size.y) * 0.4)
		var pos := center + Vector2(cos(angle), sin(angle)) * dist

		var dot := ColorRect.new()
		dot.size = Vector2(rng.randf_range(3, 8), rng.randf_range(3, 8))
		dot.position = pos - dot.size / 2.0
		dot.color = _district.terrain_color.lightened(rng.randf_range(0.1, 0.25))
		dot.color.a = 0.3
		grid_overlay.add_child(dot)

func update_visual(district: District) -> void:
	_district = district
	if traffic_label:
		traffic_label.text = "Traffic: %.0f | Lv.%d" % [district.traffic_score, district.level]
		traffic_label.add_theme_color_override("font_color", district.ambient_color.lerp(Color.WHITE, 0.5))

func _process(delta: float) -> void:
	if _district == null:
		return
	_pulse_phase += delta * 0.3
	if terrain:
		var pulse: float = sin(_pulse_phase) * 0.015
		terrain.color = _district.terrain_color.lightened(pulse)

func _setup_particles() -> void:
	if particles == null or _district == null:
		return
	particles.emitting = true
	particles.amount = 15
	particles.lifetime = 4.0
	particles.position = _size / 2.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(_size.x * 0.35, _size.y * 0.35, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 3.0

	match _district.bank_type:
		Bank.BankType.IVORAI:
			mat.color = Color(1.0, 0.85, 0.4, 0.2)
		Bank.BankType.GLYFFINS:
			mat.color = Color(0.7, 0.8, 1.0, 0.15)
		Bank.BankType.ZORAQIANS:
			mat.color = Color(0.5, 0.2, 0.8, 0.12)
		Bank.BankType.YAGARI:
			mat.color = Color(0.2, 0.2, 0.5, 0.08)

	particles.process_material = mat
