extends Control

@export var font_size: int = 20
@export var rect_size: float = 50.0

var spell_cast_inputs: PackedByteArray
var cur_idx: int = 0
var correct_inputs: Array[KeyState] = []

var is_displaying: bool = false
var is_wrong: bool = false
var wrong_timer: SceneTreeTimer

enum KeyState { Correct, Incorrect, None }

func _ready() -> void:
	SignalBus.spell_cast_inputs.connect(_on_spell_cast_inputs)
	SignalBus.spell_input.connect(_on_spell_input)
	SignalBus.spell_uncast.connect(_on_spell_uncast)

func _on_spell_cast_inputs(inputs: PackedByteArray) -> void:
	print("CAST SPELL")
	spell_cast_inputs = PackedByteArray(inputs)
	cur_idx = 0
	is_displaying = true
	is_wrong = false

	correct_inputs.resize(spell_cast_inputs.size())
	correct_inputs.fill(KeyState.None)
	
	queue_redraw()

func _on_spell_input(inp: int) -> void:
	# Prevent out-of-bounds input registration
	if cur_idx >= spell_cast_inputs.size():
		return

	var is_correct := (inp == spell_cast_inputs[cur_idx])
	correct_inputs[cur_idx] = KeyState.Correct if is_correct else KeyState.Incorrect
	
	if not is_correct:
		_trigger_wrong_feedback()

	cur_idx += 1
	queue_redraw()

func _on_spell_uncast() -> void:
	spell_cast_inputs.clear()
	correct_inputs.clear()
	cur_idx = 0
	is_displaying = false
	is_wrong = false
	queue_redraw()

func _trigger_wrong_feedback() -> void:
	is_wrong = true
	queue_redraw()
	
	wrong_timer = get_tree().create_timer(0.5)
	await wrong_timer.timeout
	
	is_displaying = false
	queue_redraw()

func _draw() -> void:
	if not is_displaying:
		return

	var font := ThemeDB.fallback_font
	var font_ascent := font.get_ascent(font_size)

	for i in range(spell_cast_inputs.size()):
		var ch := spell_cast_inputs[i]
		var key_state = correct_inputs[i]
		var base_x := i * rect_size
		var color : Color
		match key_state:
			KeyState.Correct:
				color = Color.SEA_GREEN
			KeyState.Incorrect:
				color = Color.RED
			KeyState.Correct:
				color = Color.GRAY
		draw_rect(Rect2(base_x, 0, rect_size, rect_size), color)
		var char_sz := font.get_char_size(ch, font_size)
		var x_pos := base_x + (rect_size / 2.0) - (char_sz.x / 2.0)
		
		var y_pos := (rect_size / 2.0) + (font_ascent / 2.0) - (char_sz.y / 4.0)
		draw_char(font, Vector2(x_pos, y_pos), char(ch), font_size, Color.WHITE)
