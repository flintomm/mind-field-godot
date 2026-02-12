## SnippetPanel — Text input + bank selector + mood slider for submitting snippets.
extends VBoxContainer

@onready var snippet_input: TextEdit = %SnippetInput
@onready var mood_slider: HSlider = %MoodSlider
@onready var mood_label: Label = %MoodLabel
@onready var submit_button: Button = %SubmitButton
@onready var bank_buttons: Array[Button] = [%BankBtn0, %BankBtn1, %BankBtn2, %BankBtn3]

var _selected_bank: int = Bank.BankType.IVORAI

const BANK_COLORS := [
	Color(0.96, 0.91, 0.78),  # Ivorai
	Color(0.75, 0.75, 0.75),  # Glyffins
	Color(0.30, 0.15, 0.35),  # Zoraqians
	Color(0.12, 0.12, 0.18),  # Yagari
]

const BANK_NAMES := ["Ivorai", "Glyffins", "Zoraqians", "Yagari"]

func _ready() -> void:
	submit_button.pressed.connect(_on_submit)

	for i: int in range(4):
		var idx := i
		bank_buttons[i].pressed.connect(func() -> void: _select_bank(idx))
		bank_buttons[i].modulate = BANK_COLORS[i]
		bank_buttons[i].text = BANK_NAMES[i]

	mood_slider.min_value = -1.0
	mood_slider.max_value = 1.0
	mood_slider.value = 0.0
	mood_slider.step = 0.1
	mood_slider.value_changed.connect(_on_mood_changed)

	_select_bank(0)
	_on_mood_changed(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("submit_snippet"):
		_on_submit()

func _select_bank(index: int) -> void:
	_selected_bank = index
	for i: int in range(4):
		bank_buttons[i].flat = (i != index)
		if i == index:
			bank_buttons[i].add_theme_stylebox_override("normal", _create_selected_style(BANK_COLORS[i]))
		else:
			bank_buttons[i].remove_theme_stylebox_override("normal")

func _create_selected_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_bottom = 3
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color.WHITE
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _on_submit() -> void:
	var content := snippet_input.text.strip_edges()
	if content.is_empty():
		return
	var mood: float = mood_slider.value
	GameManager.bank_registry.submit_snippet(content, _selected_bank, mood)
	snippet_input.text = ""
	mood_slider.value = 0.0
	snippet_input.grab_focus()

func _on_mood_changed(value: float) -> void:
	if mood_label == null:
		return
	if value > 0.3:
		mood_label.text = "Positive"
	elif value < -0.3:
		mood_label.text = "Negative"
	else:
		mood_label.text = "Neutral"
