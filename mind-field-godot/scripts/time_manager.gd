## TimeManager — Day/night cycle, snippet timing, ambient lighting, sun/moon.
extends Node

signal day_started()
signal day_ended_signal()
signal night_started()
signal time_progressed(hours: float)
signal sun_moon_updated(sun_pos: Vector2, moon_pos: Vector2, is_day: bool)

var game_time_hours := 12.0
var current_day := 1
var day_start_hour := 6.0
var night_start_hour := 20.0
var day_duration_real_minutes := 24.0  # 24 real minutes = 1 game day

var _start_date: Dictionary
var _was_day := true
var _real_seconds_per_game_hour := 60.0
var _last_snippet_time := -1.0  # unix time

# Sun/Moon configuration
const SUN_ORBIT_RADIUS := 800.0
const MOON_ORBIT_RADIUS := 700.0
const SKY_CENTER := Vector2(960, 360)  # Top center of sky

func initialize() -> void:
	_start_date = Time.get_date_dict_from_system()
	_real_seconds_per_game_hour = (day_duration_real_minutes * 60.0) / 24.0
	var now := Time.get_time_dict_from_system()
	game_time_hours = float(now["hour"]) + float(now["minute"]) / 60.0
	_was_day = is_day()
	_last_snippet_time = -1.0

func _process(delta: float) -> void:
	var hours_per_second := 1.0 / _real_seconds_per_game_hour
	game_time_hours += delta * hours_per_second

	if game_time_hours >= 24.0:
		game_time_hours -= 24.0
		current_day += 1
		day_ended_signal.emit()
		day_started.emit()

	var now_day := is_day()
	if now_day and not _was_day:
		day_started.emit()
		_emit_sun_moon_update(true)
	if not now_day and _was_day:
		night_started.emit()
		_emit_sun_moon_update(false)
	_was_day = now_day

	time_progressed.emit(game_time_hours)

	# Update sun/moon positions continuously
	_emit_sun_moon_update(now_day)

func _emit_sun_moon_update(is_daytime: bool) -> void:
	var sun_angle := _get_sun_angle()
	var moon_angle := sun_angle + PI  # Opposite side
	
	var sun_pos := SKY_CENTER + Vector2(cos(sun_angle), sin(sun_angle)) * SUN_ORBIT_RADIUS
	var moon_pos := SKY_CENTER + Vector2(cos(moon_angle), sin(moon_angle)) * MOON_ORBIT_RADIUS
	
	sun_moon_updated.emit(sun_pos, moon_pos, is_daytime)

func _get_sun_angle() -> float:
	# Map 6am-6am (24h cycle) to angle
	# 6am = -PI/2 (bottom), 12pm = 0 (top), 6pm = PI/2 (bottom)
	var hour_angle := (game_time_hours - 6.0) / 12.0 * PI
	return -PI/2 + hour_angle

func is_day() -> bool:
	return game_time_hours >= day_start_hour and game_time_hours < night_start_hour

func get_day_progress() -> float:
	return clampf((game_time_hours - day_start_hour) / (night_start_hour - day_start_hour), 0.0, 1.0)

func get_snippet_spacing_minutes() -> float:
	if _last_snippet_time < 0.0:
		return 999999.0
	var now := Time.get_unix_time_from_system()
	return (now - _last_snippet_time) / 60.0

func record_snippet_time() -> void:
	_last_snippet_time = Time.get_unix_time_from_system()

func set_game_time_hours(hours: float) -> void:
	game_time_hours = hours

func reset_time() -> void:
	var now := Time.get_time_dict_from_system()
	game_time_hours = float(now["hour"]) + float(now["minute"]) / 60.0
	current_day = 1
	_start_date = Time.get_date_dict_from_system()
	_last_snippet_time = -1.0

func get_ambient_color() -> Color:
	# Brighter overall - no more dark overlays
	if game_time_hours < 5.0:
		return Color(0.15, 0.15, 0.35)  # Pre-dawn blue
	elif game_time_hours < 7.0:
		return Color(1.0, 0.7, 0.5).lerp(Color(1.0, 0.85, 0.6), (game_time_hours - 5.0) / 2.0)  # Sunrise
	elif game_time_hours < 17.0:
		return Color(1.0, 1.0, 0.95)  # Day - bright warm white
	elif game_time_hours < 19.0:
		return Color(1.0, 0.9, 0.7).lerp(Color(1.0, 0.6, 0.4), (game_time_hours - 17.0) / 2.0)  # Sunset
	elif game_time_hours < 22.0:
		return Color(0.4, 0.4, 0.6)  # Evening blue
	else:
		return Color(0.2, 0.2, 0.35)  # Night - dim blue, not dark

func get_sky_gradient() -> Dictionary:
	# Return colors for sky gradient
	if game_time_hours < 5.0:
		return {"top": Color(0.1, 0.1, 0.25), "bottom": Color(0.2, 0.2, 0.4)}
	elif game_time_hours < 7.0:
		return {"top": Color(1.0, 0.6, 0.3), "bottom": Color(1.0, 0.85, 0.6)}
	elif game_time_hours < 17.0:
		return {"top": Color(0.5, 0.7, 1.0), "bottom": Color(0.8, 0.9, 1.0)}
	elif game_time_hours < 19.0:
		return {"top": Color(0.6, 0.4, 0.5), "bottom": Color(1.0, 0.6, 0.4)}
	elif game_time_hours < 22.0:
		return {"top": Color(0.2, 0.2, 0.4), "bottom": Color(0.4, 0.4, 0.6)}
	else:
		return {"top": Color(0.05, 0.05, 0.15), "bottom": Color(0.15, 0.15, 0.3)}
