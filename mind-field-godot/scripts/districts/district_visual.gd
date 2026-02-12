## DistrictVisual — Visual representation of a district in the park map.
## Features organic/irregular borders instead of perfect squares.
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

const DISTRICT_NAMES := ["Ivorai Grove", "Glyffinworks", "Zoraqian Depths", "Yagari Sanctum"]

func setup(district: District, size: Vector2) -> void:
	_district = district
	_size = size
	_random_seed = hash(district.district_name) & 0x7FFFFFFF
	_border_lines = get_node_or_null("BorderLines")

	# Generate organic border points
	_generate_border_points()

	# Terrain with organic shape
	if terrain:
		terrain.polygon = PackedVector2Array(_corner_points)
		terrain.color = district.terrain_color

	# Border lines
	_draw_irregular_border()

	# Name
	if name_label:
		name_label.text = district.district_name
		name_label.position = Vector2(_size.x / 2.0, -20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", district.ambient_color)
		name_label.add_theme_font_size_override("font_size", 16)

	# Traffic
	if traffic_label:
		traffic_label.position = Vector2(_size.x / 2.0, _size.y - 20)
		traffic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		traffic_label.add_theme_font_size_override("font_size", 12)

	# Grid overlay
	_draw_grid()

	# Ambient particles
	_setup_particles()

func _generate_border_points() -> void:
	_corner_points.clear()
	var local_seed: int = _random_seed
	
	# Base rectangle corners
	var corners_array: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(_size.x, 0),
		Vector2(_size.x, _size.y),
		Vector2(0, _size.y)
	]
	
	# Add intermediate points with random offset for irregularity
	var steps_per_side: int = 3
	var random := RandomNumberGenerator.new()
	random.seed = local_seed
	
	for i: int in range(4):
		var start: Vector2 = corners_array[i]
		var end: Vector2 = corners_array[(i + 1) % 4]
		
		_corner_points.append(start)
		
		for j: int in range(1, steps_per_side):
			var t: float = float(j) / float(steps_per_side)
			var base: Vector2 = start.lerp(end, t)
			
			# Add organic irregularity - more at corners
			var corner_factor: float = 1.0 if j == steps_per_side - 1 else 0.3
			var offset: float = random.randf_range(-15, 15) * corner_factor
			
			var is_horizontal: bool = (i == 0 or i == 2)
			if is_horizontal:
				base.y += offset
			else:
				base.x += offset
			
			_corner_points.append(base)
	_corner_points.append(corners_array[0])  # Close the polygon

func _draw_irregular_border() -> void:
	if _border_lines:
		for child in _border_lines.get_children():
			child.queue_free()
	
	var line_color: Color = _district.ambient_color
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = line_color
	
	# Create points along the border with slight organic wobble
	var random := RandomNumberGenerator.new()
	random.seed = _random_seed + 1
	
	var corner_array: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(_size.x, 0),
		Vector2(_size.x, _size.y),
		Vector2(0, _size.y)
	]
	
	for i: int in range(_corner_points.size() - 1):
		var p1: Vector2 = _corner_points[i]
		var p2: Vector2 = _corner_points[i + 1]
		
		# Add intermediate points for organic feel
		var segments: int = 3
		for j: int in range(segments):
			var t: float = float(j) / float(segments)
			var base: Vector2 = p1.lerp(p2, t)
			
			# Small random wobble
			var wobble: float = random.randf_range(-2, 2)
			if i % 2 == 0:
				base += Vector2(wobble, wobble * 0.5)
			else:
				base += Vector2(-wobble, -wobble * 0.5)
			
			line.add_point(base)
	
	_border_lines.add_child(line)
	
	# Add corner decorations
	for i: int in range(4):
		var corner: Vector2 = corner_array[i]
		var decor: Sprite2D = _create_corner_decor(_district.bank_type)
		decor.position = corner
		_border_lines.add_child(decor)

func _create_corner_decor(bank_type: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	var tex: Texture2D = _get_bank_tex(bank_type)
	if tex:
		sprite.texture = tex
		sprite.scale = Vector2(0.15, 0.15)
	return sprite

func _get_bank_tex(bank_type: int) -> Texture2D:
	# Return appropriate texture based on bank type
	return null

func _draw_grid() -> void:
	if grid_overlay == null:
		return
	for child in grid_overlay.get_children():
		child.queue_free()
	
	var random := RandomNumberGenerator.new()
	random.seed = _random_seed + 2
	
	var grid_spacing: float = 100.0
	var line_color: Color = Color(1, 1, 1, 0.05)
	
	# Draw grid with slight organic offset
	var x: float = grid_spacing
	while x < _size.x:
		var line := Line2D.new()
		var points: Array[Vector2] = []
		
		# Find where this vertical line intersects the border
		for i: int in range(_corner_points.size() - 1):
			var p1: Vector2 = _corner_points[i]
			var p2: Vector2 = _corner_points[i + 1]
			
			# Simple check if within x range
			if (p1.x <= x and p2.x >= x) or (p2.x <= x and p1.x >= x):
				var t: float = (x - p1.x) / (p2.x - p1.x) if p2.x != p1.x else 0.5
				var y: float = lerp(p1.y, p2.y, t)
				points.append(Vector2(x, y))
		
		if points.size() >= 2:
			line.add_point(points[0])
			line.add_point(points[points.size() - 1])
			line.width = 1.0
			line.default_color = line_color
			grid_overlay.add_child(line)
		x += grid_spacing
	
	var y: float = grid_spacing
	while y < _size.y:
		var line := Line2D.new()
		var points: Array[Vector2] = []
		
		for i: int in range(_corner_points.size() - 1):
			var p1: Vector2 = _corner_points[i]
			var p2: Vector2 = _corner_points[i + 1]
			
			if (p1.y <= y and p2.y >= y) or (p2.y <= y and p1.y >= y):
				var t: float = (y - p1.y) / (p2.y - p1.y) if p2.y != p1.y else 0.5
				var x_pos: float = lerp(p1.x, p2.x, t)
				points.append(Vector2(x_pos, y))
		
		if points.size() >= 2:
			line.add_point(points[0])
			line.add_point(points[points.size() - 1])
			line.width = 1.0
			line.default_color = line_color
			grid_overlay.add_child(line)
		y += grid_spacing

func update_visual(district: District) -> void:
	_district = district
	if traffic_label:
		traffic_label.text = "Traffic: %.0f | Lv.%d" % [district.traffic_score, district.level]
		traffic_label.add_theme_color_override("font_color", district.ambient_color.lerp(Color.WHITE, 0.5))

func _process(delta: float) -> void:
	if _district == null:
		return
	# Subtle terrain pulse
	_pulse_phase += delta * 0.3
	if terrain:
		var pulse: float = sin(_pulse_phase) * 0.02
		terrain.color = _district.terrain_color.lightened(pulse)

func _setup_particles() -> void:
	if particles == null or _district == null:
		return
	particles.emitting = true
	particles.amount = 8
	particles.lifetime = 3.0
	particles.position = _size / 2.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(_size.x / 2.0 - 20, _size.y / 2.0 - 20, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.8
	mat.scale_max = 2.5

	match _district.bank_type:
		Bank.BankType.IVORAI:
				mat.color = Color(1.0, 0.85, 0.4, 0.25)  # Warm lantern glow
		Bank.BankType.GLYFFINS:
				mat.color = Color(0.7, 0.8, 1.0, 0.2)  # Cool geometric
		Bank.BankType.ZORAQIANS:
				mat.color = Color(0.5, 0.2, 0.8, 0.15)  # Alien spores
		Bank.BankType.YAGARI:
				mat.color = Color(0.2, 0.2, 0.5, 0.1)  # Dark mist

	particles.process_material = mat
