## Main — Root scene script. RTS-style park with large map, pathways, click-to-inspect.
extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var ambient_overlay: CanvasModulate = $AmbientOverlay
@onready var park_bg: ColorRect = $ParkBackground
@onready var district_layer: Node2D = $DistrictLayer
@onready var pathway_layer: Node2D = $PathwayLayer
@onready var habit_layer: Node2D = $HabitLayer
@onready var unit_layer: Node2D = $UnitLayer
@onready var bubble_layer: Node2D = $BubbleLayer
@onready var day_unit_spawn: Marker2D = $DayUnitSpawn
@onready var ui: Control = $UILayer/MainUI
@onready var sun_sprite: Sprite2D = $SkyLayer/Sun
@onready var moon_sprite: Sprite2D = $SkyLayer/Moon
@onready var sky_gradient: ColorRect = $SkyLayer/SkyGradient

const CAMERA_PAN_SPEED := 600.0
const CAMERA_ZOOM_SPEED := 0.08
const CAMERA_ZOOM_MIN := 0.2
const CAMERA_ZOOM_MAX := 2.0
const MAP_SIZE := Vector2(4800, 3200)
const MAP_BOUNDS := Rect2(0, 0, 4800, 3200)

# Organic district layout - larger districts with space between
const DISTRICT_POSITIONS := {
	0: Vector2(300, 200),     # Ivorai - top left
	1: Vector2(2600, 150),    # Glyffins - top right
	2: Vector2(200, 1800),    # Zoraqians - bottom left
	3: Vector2(2700, 1900),   # Yagari - bottom right
}
const DISTRICT_SIZE := Vector2(1800, 1100)

# Pathway waypoints connecting districts (center points)
const PATHWAY_POINTS := {
	"ivorai_glyffins": [Vector2(1200, 600), Vector2(1800, 500), Vector2(2600, 550)],
	"ivorai_zoraqians": [Vector2(600, 900), Vector2(500, 1400), Vector2(500, 1900)],
	"glyffins_yagari": [Vector2(3500, 800), Vector2(3600, 1400), Vector2(3500, 1900)],
	"zoraqians_yagari": [Vector2(1200, 2400), Vector2(1900, 2500), Vector2(2700, 2400)],
	"ivorai_yagari": [Vector2(1500, 800), Vector2(2200, 1500), Vector2(3000, 2100)],
	"glyffins_zoraqians": [Vector2(2200, 600), Vector2(1500, 1400), Vector2(800, 2100)],
}

var _day_unit_controller: Node2D
var _district_visuals: Dictionary = {}
var _habit_visuals: Dictionary = {}
var _attendee_visuals: Array[Node2D] = []
var _camera_drag := false
var _camera_drag_start := Vector2.ZERO
var _selected_unit: Node2D = null

func _ready() -> void:
	_draw_pathways()
	_spawn_districts()
	_spawn_existing_habits()
	_spawn_existing_attendees()

	if GameManager.time_manager:
		GameManager.time_manager.sun_moon_updated.connect(_on_sun_moon_updated)
		GameManager.time_manager.time_progressed.connect(_on_time_progressed)
		_on_sun_moon_updated(Vector2.ZERO, Vector2.ZERO, GameManager.time_manager.is_day())

	EventBus.snippet_added.connect(_on_snippet_added)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.attendee_created.connect(_on_attendee_created)

	GameManager.habit_system.habit_created.connect(_on_habit_created)
	GameManager.habit_system.habit_removed.connect(_on_habit_removed)
	GameManager.habit_system.habit_completed_signal.connect(_on_habit_updated)
	GameManager.habit_system.habit_decayed_signal.connect(_on_habit_decayed)

func _on_sun_moon_updated(sun_pos: Vector2, moon_pos: Vector2, is_daytime: bool) -> void:
	if sun_sprite:
		sun_sprite.position = sun_pos
		sun_sprite.visible = is_daytime
	if moon_sprite:
		moon_sprite.position = moon_pos
		moon_sprite.visible = not is_daytime

func _on_time_progressed(_hours: float) -> void:
	if sky_gradient and GameManager.time_manager:
		var gradient_data: Dictionary = GameManager.time_manager.get_sky_gradient()
		var top_color: Color = gradient_data["top"]
		var bottom_color: Color = gradient_data["bottom"]
		sky_gradient.color = top_color.lerp(bottom_color, 0.5)

func _process(delta: float) -> void:
	_handle_camera(delta)

	if ambient_overlay and GameManager.time_manager:
		ambient_overlay.color = GameManager.time_manager.get_ambient_color()

	if _day_unit_controller == null and GameManager.simulation_manager.current_day_unit != null:
		_spawn_day_unit_visual()

	_update_district_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(CAMERA_ZOOM_SPEED)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(-CAMERA_ZOOM_SPEED)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_MIDDLE:
				_camera_drag = true
				_camera_drag_start = mb.position
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(mb)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_deselect_unit()
				get_viewport().set_input_as_handled()
		else:
			if mb.button_index == MOUSE_BUTTON_MIDDLE:
				_camera_drag = false
	elif event is InputEventMouseMotion and _camera_drag:
		var mm := event as InputEventMouseMotion
		camera.position -= mm.relative / camera.zoom
		_clamp_camera()

func _handle_left_click(mb: InputEventMouseButton) -> void:
	# Convert screen to world coords
	var world_pos := get_global_mouse_position()
	# Check units
	var closest_unit: Node2D = null
	var closest_dist := 40.0  # Click radius in world pixels
	for child in unit_layer.get_children():
		var dist := world_pos.distance_to(child.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_unit = child
	if closest_unit:
		_select_unit(closest_unit)
		get_viewport().set_input_as_handled()
	else:
		_deselect_unit()

func _select_unit(unit: Node2D) -> void:
	_selected_unit = unit
	if unit.has_method("set_selected"):
		unit.set_selected(true)
	# Tell UI to show info panel
	var info := _get_unit_info(unit)
	EventBus.unit_selected.emit(info)

func _deselect_unit() -> void:
	if _selected_unit and _selected_unit.has_method("set_selected"):
		_selected_unit.set_selected(false)
	_selected_unit = null
	EventBus.unit_deselected.emit()

func _get_unit_info(unit: Node2D) -> Dictionary:
	if unit.has_method("get_info"):
		return unit.get_info()
	return {}

func _handle_camera(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move.y += 1

	if move != Vector2.ZERO:
		camera.position += move.normalized() * CAMERA_PAN_SPEED * delta / camera.zoom.x
		_clamp_camera()

	# Edge scrolling
	var vp_size := get_viewport_rect().size
	var mouse_pos := get_viewport().get_mouse_position()
	var edge_margin := 15.0
	var edge_move := Vector2.ZERO
	if mouse_pos.x < edge_margin:
		edge_move.x = -1
	elif mouse_pos.x > vp_size.x - edge_margin:
		edge_move.x = 1
	if mouse_pos.y < edge_margin:
		edge_move.y = -1
	elif mouse_pos.y > vp_size.y - edge_margin:
		edge_move.y = 1
	if edge_move != Vector2.ZERO:
		camera.position += edge_move.normalized() * CAMERA_PAN_SPEED * 0.6 * delta / camera.zoom.x
		_clamp_camera()

func _zoom_camera(amount: float) -> void:
	var mouse_world_before := get_global_mouse_position()
	var new_zoom := clampf(camera.zoom.x + amount, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	camera.zoom = Vector2(new_zoom, new_zoom)
	# Zoom toward mouse position
	var mouse_world_after := get_global_mouse_position()
	camera.position += mouse_world_before - mouse_world_after
	_clamp_camera()

func _clamp_camera() -> void:
	camera.position.x = clampf(camera.position.x, 0, MAP_SIZE.x)
	camera.position.y = clampf(camera.position.y, 0, MAP_SIZE.y)

# --- Pathways ---

func _draw_pathways() -> void:
	for key: String in PATHWAY_POINTS:
		var points: Array = PATHWAY_POINTS[key]
		var line := Line2D.new()
		line.width = 24.0
		line.default_color = Color(0.45, 0.42, 0.32, 0.7)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		for p: Vector2 in points:
			line.add_point(p)
		pathway_layer.add_child(line)
		# Add border line
		var border := Line2D.new()
		border.width = 30.0
		border.default_color = Color(0.35, 0.32, 0.22, 0.4)
		border.begin_cap_mode = Line2D.LINE_CAP_ROUND
		border.end_cap_mode = Line2D.LINE_CAP_ROUND
		for p: Vector2 in points:
			border.add_point(p)
		pathway_layer.add_child(border)
		border.z_index = -1

# --- District Visuals ---

func _spawn_districts() -> void:
	var districts: Array = GameManager.district_manager.get_all_districts()
	for district: District in districts:
		_create_district_visual(district)

func _create_district_visual(district: District) -> void:
	var visual: Node2D = preload("res://scenes/districts/district_visual.tscn").instantiate()
	visual.position = DISTRICT_POSITIONS.get(district.bank_type, Vector2.ZERO)
	visual.setup(district, DISTRICT_SIZE)
	district_layer.add_child(visual)
	_district_visuals[district.bank_type] = visual

func _update_district_visuals() -> void:
	for bank_type: int in _district_visuals:
		var visual: Node2D = _district_visuals[bank_type]
		if visual.has_method("update_visual"):
			var district: District = GameManager.district_manager.get_district(bank_type)
			if district:
				visual.update_visual(district)

# --- Habit Visuals ---

func _spawn_existing_habits() -> void:
	var habits: Array = GameManager.habit_system.get_all_habits()
	for habit: Habit in habits:
		_create_habit_visual(habit)

func _create_habit_visual(habit: Habit) -> void:
	var habit_visual: Node2D = preload("res://scenes/habits/habit_visual.tscn").instantiate()
	var district_type: int = _habit_visuals.size() % 4
	var district_pos: Vector2 = DISTRICT_POSITIONS.get(district_type, Vector2.ZERO)
	var slot_index := _count_habits_in_district(district_type)
	var grid_x := (slot_index % 4) * 200 + 200
	var grid_y := (slot_index / 4) * 180 + 300
	habit_visual.position = district_pos + Vector2(grid_x, grid_y)
	habit_visual.setup(habit)
	habit_layer.add_child(habit_visual)
	_habit_visuals[habit.id] = habit_visual

func _count_habits_in_district(district_type: int) -> int:
	var count := 0
	var dist_pos: Vector2 = DISTRICT_POSITIONS.get(district_type, Vector2.ZERO)
	for v: Node2D in _habit_visuals.values():
		if v.position.x >= dist_pos.x and v.position.x < dist_pos.x + DISTRICT_SIZE.x:
			if v.position.y >= dist_pos.y and v.position.y < dist_pos.y + DISTRICT_SIZE.y:
				count += 1
	return count

func _on_habit_created(habit_data: Dictionary) -> void:
	var habit: Habit = GameManager.habit_system.get_habit(habit_data.get("id", ""))
	if habit:
		_create_habit_visual(habit)

func _on_habit_removed(habit_data: Dictionary) -> void:
	var hid: String = habit_data.get("id", "")
	if _habit_visuals.has(hid):
		_habit_visuals[hid].queue_free()
		_habit_visuals.erase(hid)

func _on_habit_updated(habit_data: Dictionary) -> void:
	var hid: String = habit_data.get("id", "")
	if _habit_visuals.has(hid) and _habit_visuals[hid].has_method("refresh"):
		var habit: Habit = GameManager.habit_system.get_habit(hid)
		if habit:
			_habit_visuals[hid].refresh(habit)

func _on_habit_decayed(habit_data: Dictionary, _new_health: float) -> void:
	_on_habit_updated(habit_data)

# --- Day Unit Visual ---

func _spawn_day_unit_visual() -> void:
	var scene: PackedScene = preload("res://scenes/entities/day_unit.tscn")
	_day_unit_controller = scene.instantiate()
	unit_layer.add_child(_day_unit_controller)
	var dominant: int = GameManager.bank_registry.get_dominant_bank()
	var dist_pos: Vector2 = DISTRICT_POSITIONS.get(dominant, Vector2(2400, 1600))
	_day_unit_controller.position = dist_pos + DISTRICT_SIZE / 2.0
	_day_unit_controller.bind(GameManager.simulation_manager.current_day_unit)

	# Give it the full map to roam with district waypoints
	if _day_unit_controller.has_method("set_roam_data"):
		_day_unit_controller.set_roam_data(DISTRICT_POSITIONS, DISTRICT_SIZE, PATHWAY_POINTS)

func _on_snippet_added(content: String, bank_type: int, mood: float) -> void:
	if _day_unit_controller == null and GameManager.simulation_manager.current_day_unit != null:
		_spawn_day_unit_visual()
	# Spawn thought bubble in world space
	_spawn_world_thought_bubble(content, bank_type)

func _spawn_world_thought_bubble(content: String, bank_type: int) -> void:
	if _day_unit_controller == null:
		return
	var bubble := preload("res://scenes/entities/thought_bubble.tscn").instantiate()
	bubble.position = _day_unit_controller.global_position + Vector2(0, -50)
	bubble_layer.add_child(bubble)
	var bank: Bank = GameManager.bank_registry.get_bank(bank_type)
	var color := bank.primary_color if bank else Color.WHITE
	bubble.initialize(content, 4.0, color, bank_type)

func _on_day_ended(_day: int, _day_unit_id: String) -> void:
	if _day_unit_controller:
		_spawn_attendee_from_day_unit(_day_unit_controller.position)
		_day_unit_controller.queue_free()
		_day_unit_controller = null

# --- Attendee Visuals ---

func _spawn_existing_attendees() -> void:
	var attendees: Array = GameManager.simulation_manager.get_attendees()
	for att: DayUnit in attendees:
		_spawn_attendee(att)

func _spawn_attendee(att: DayUnit) -> void:
	var attendee_visual: Node2D = preload("res://scenes/entities/attendee.tscn").instantiate()
	# Start in home district then wander entire park
	var dist_pos: Vector2 = DISTRICT_POSITIONS.get(att.race_type, Vector2(2400, 1600))
	attendee_visual.position = dist_pos + Vector2(randf_range(100, DISTRICT_SIZE.x - 100), randf_range(100, DISTRICT_SIZE.y - 100))
	attendee_visual.setup(att, DISTRICT_POSITIONS, DISTRICT_SIZE, PATHWAY_POINTS)
	unit_layer.add_child(attendee_visual)
	_attendee_visuals.append(attendee_visual)

func _spawn_attendee_from_day_unit(pos: Vector2) -> void:
	var attendees: Array = GameManager.simulation_manager.get_attendees()
	if attendees.size() > 0:
		var latest: DayUnit = attendees[attendees.size() - 1]
		var attendee_visual: Node2D = preload("res://scenes/entities/attendee.tscn").instantiate()
		attendee_visual.position = pos
		attendee_visual.setup(latest, DISTRICT_POSITIONS, DISTRICT_SIZE, PATHWAY_POINTS)
		unit_layer.add_child(attendee_visual)
		_attendee_visuals.append(attendee_visual)

func _on_attendee_created(_attendee_id: String, _race_type: int) -> void:
	pass

# --- Public API ---

func center_camera_on_district(bank_type: int) -> void:
	var pos: Vector2 = DISTRICT_POSITIONS.get(bank_type, Vector2(2400, 1600))
	camera.position = pos + DISTRICT_SIZE / 2.0

func get_district_positions() -> Dictionary:
	return DISTRICT_POSITIONS

func get_district_size() -> Vector2:
	return DISTRICT_SIZE
