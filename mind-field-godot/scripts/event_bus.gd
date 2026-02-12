## EventBus — Global signal hub for decoupled communication between systems.
extends Node

# Bank events
signal snippet_added(content: String, bank_type: int, mood_score: float)
signal bank_balance_changed(bank_type: int, new_balance: float)

# Day Unit events
signal day_unit_morphed(new_stage: int, day_unit_id: String)
signal day_ended(day: int, day_unit_id: String)
signal attendee_created(attendee_id: String, race_type: int)

# Habit events
signal habit_completed(habit_id: String, new_streak: int, major_reward: bool)
signal habit_decayed(habit_id: String, new_health: float)

# District events
signal district_traffic_changed(district_id: String, new_traffic: float)

# Simulation events
signal simulation_tick(delta_time: float, tick_number: int)

# Save/Load events
signal game_saved()
signal game_loaded()

# UI events
signal ui_panel_changed(panel_name: String)
signal snippet_submitted(content: String, bank_type: int, mood: float)

# Selection events (SC2-style click-to-inspect)
signal unit_selected(info: Dictionary)
signal unit_deselected()
