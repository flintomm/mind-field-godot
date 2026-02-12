## Main — Root scene script. RTS-style park view with camera, districts, units, sun/moon.
extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var ambient_overlay: CanvasModulate = $AmbientOverlay
@onready var park_bg: ColorRect = $ParkBackground
@onready var district_layer: Node2D = $DistrictLayer
@onready var habit_layer: Node2D = $HabitLayer
@onready var unit_layer: Node2D = $UnitLayer
@onready var bubble_layer: Node2D = $BubbleLayer
@onready var day_unit_spawn: Marker2D = $DayUnitSpawn
@onready var ui: Control = $UILayer/MainUI
@onready var sun_sprite: Sprite2D = $SkyLayer/Sun
@onready var moon_sprite: Sprite2D = $SkyLayer/Moon
@onready var sky_gradient: ColorRect = $SkyLayer/SkyGradient

const CAMERA_PAN_SPEED := 400.0
const CAMERA_ZOOM_SPEED := 0.1
const CAMERA_ZOOM_MIN := 0.3
const CAMERA_ZOOM_MAX := 2.0
const MAP_BOUNDS := Rect2(0, 0, 1920, 1080)

# District layout: 2x2 grid, each district is 960x540
const DISTRICT_POSITIONS := {
	0: Vector2(240, 135),   # Ivorai - top left
	1: Vector2(720, 135),   # Glyffins - top right
	2: Vector2(240, 405),   # Zoraqians - bottom left
	3: Vector2(720, 405),   # Yagari - bottom right
}
const DISTRICT_SIZE := Vector2(480, 270)

var _day_unit_controller: Node2D
var _district_visuals: Dictionary = {}  # bank_type -> Node2D
var _habit_visuals: Dictionary = {}  # habit_id -> Node2D
var _attendee_visuals: Array[Node2D] = []
var _camera_drag := false
var _camera_drag_start := Vector2.ZERO

func _ready() -> void:
	# Brighter sky background
	if park_bg:
		park_bg.color = Color(0.4, 0.5, 0.35)  # Lighter green

	_spawn_districts()
	_spawn_existing_habits()
	_spawn_existing_attendees()
	
	# Connect sun/moon updates
	if GameManager.time_manager:
		GameManager.time_manager.sun_moon_updated.connect(_on_sun_moon_updated)
		GameManager.time_manager.time_progressed.connect(_on_time_progressed)
		# Initial sun/moon position
		_on_sun_moon_updated(Vector2.ZERO, Vector2.ZERO, GameManager.time_manager.is_day())

	EventBus.snippet_added.connect(_on_snippet_added)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.attendee_created.connect(_on_attendee_created)

	# Connect habit system signals
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
	# Update sky gradient based on time - simplified approach
	if sky_gradient and GameManager.time_manager:
		var gradient_data: Dictionary = GameManager.time_manager.get_sky_gradient()
		# Use solid color interpolation instead
		var top_color: Color = gradient_data["top"]
		var bottom_color: Color = gradient_data["bottom"]
		var avg_color := top_color.lerp(bottom_color, 0.5)
		sky_gradient.color = avg_color

func _process(delta: float) -> void:
	_handle_camera(delta)

	if ambient_overlay and GameManager.time_manager:
		ambient_overlay.color = GameManager.time_manager.get_ambient_color()

	if _day_unit_controller == null and GameManager.simulation_manager.current_day_unit != null:
		_spawn_day_unit_visual()

	_update_district_visuals()

func _unhandled_input(event: InputEvent) -> void:
	# Zoom with mouse wheel
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
		else:
			if mb.button_index == MOUSE_BUTTON_MIDDLE:
				_camera_drag = false
	elif event is InputEventMouseMotion and _camera_drag:
		var mm := event as InputEventMouseMotion
		camera.position -= mm.relative / camera.zoom
		_clamp_camera()

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
	var edge_margin := 20.0
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
		camera.position += edge_move.normalized() * CAMERA_PAN_SPEED * 0.5 * delta / camera.zoom.x
		_clamp_camera()

func _zoom_camera(amount: float) -> void:
	var new_zoom := clampf(camera.zoom.x + amount, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	camera.zoom = Vector2(new_zoom, new_zoom)

func _clamp_camera() -> void:
	camera.position.x = clampf(camera.position.x, MAP_BOUNDS.position.x, MAP_BOUNDS.end.x)
	camera.position.y = clampf(camera.position.y, MAP_BOUNDS.position.y, MAP_BOUNDS.end.y)

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
	# Place habit in its district based on foundation type -> bank mapping
	# Distribute habits across districts round-robin style
	var district_type: int = _habit_visuals.size() % 4
	var district_pos: Vector2 = DISTRICT_POSITIONS.get(district_type, Vector2.ZERO)
	var slot_index := _count_habits_in_district(district_type)
	var grid_x := (slot_index % 4) * 100 + 60
	var grid_y := (slot_index / 4) * 80 + 80
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
	# Place in center of dominant district
	var dominant: int = GameManager.bank_registry.get_dominant_bank()
	var dist_pos: Vector2 = DISTRICT_POSITIONS.get(dominant, Vector2(480, 270))
	_day_unit_controller.position = dist_pos + DISTRICT_SIZE / 2.0
	_day_unit_controller.bind(GameManager.simulation_manager.current_day_unit)

	# Give it walk targets
	if _day_unit_controller.has_method("set_walk_area"):
		_day_unit_controller.set_walk_area(dist_pos, DISTRICT_SIZE)

func _on_snippet_added(_content: String, _bank_type: int, _mood: float) -> void:
	if _day_unit_controller == null and GameManager.simulation_manager.current_day_unit != null:
		_spawn_day_unit_visual()

func _on_day_ended(_day: int, _day_unit_id: String) -> void:
	if _day_unit_controller:
		# Convert to attendee visual
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
	var dist_pos: Vector2 = DISTRICT_POSITIONS.get(att.race_type, Vector2(480, 270))
	attendee_visual.position = dist_pos + Vector2(randf_range(40, DISTRICT_SIZE.x - 40), randf_range(40, DISTRICT_SIZE.y - 40))
	attendee_visual.setup(att)
	unit_layer.add_child(attendee_visual)
	_attendee_visuals.append(attendee_visual)

func _spawn_attendee_from_day_unit(pos: Vector2) -> void:
	var attendees: Array = GameManager.simulation_manager.get_attendees()
	if attendees.size() > 0:
		var latest: DayUnit = attendees[attendees.size() - 1]
		var attendee_visual: Node2D = preload("res://scenes/entities/attendee.tscn").instantiate()
		attendee_visual.position = pos
		attendee_visual.setup(latest)
		unit_layer.add_child(attendee_visual)
		_attendee_visuals.append(attendee_visual)

func _on_attendee_created(_attendee_id: String, _race_type: int) -> void:
	pass  # Handled by _on_day_ended

# --- Public API for UI ---

func center_camera_on_district(bank_type: int) -> void:
	var pos: Vector2 = DISTRICT_POSITIONS.get(bank_type, Vector2(480, 270))
	camera.position = pos + DISTRICT_SIZE / 2.0
