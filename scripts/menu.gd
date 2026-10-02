class_name MenuInicio
extends CanvasLayer
## Pantalla de inicio / fin de partida.

signal jugar_presionado

var _titulo: Label
var _detalle: Label
var _boton: Button


func _ready():
	var cian := Color(0, 1, 1)
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # funciona aunque el juego esté en pausa

	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.7)
	add_child(velo)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 50)
	centro.add_child(caja)

	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 96)
	_titulo.add_theme_color_override("font_color", cian)
	caja.add_child(_titulo)

	_detalle = Label.new()
	_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detalle.add_theme_font_size_override("font_size", 40)
	caja.add_child(_detalle)

	_boton = Button.new()
	_boton.custom_minimum_size = Vector2(500, 140)
	_boton.add_theme_font_size_override("font_size", 64)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.03, 0.12, 0.14)
	estilo.border_color = cian
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(20)
	for nombre in ["normal", "hover", "pressed", "focus"]:
		_boton.add_theme_stylebox_override(nombre, estilo)
	for nombre in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_boton.add_theme_color_override(nombre, cian)
	_boton.pressed.connect(_on_boton)
	caja.add_child(_boton)


func mostrar(titulo: String, detalle: String, texto_boton: String):
	_titulo.text = titulo
	_detalle.text = detalle
	_boton.text = texto_boton
	visible = true


func ocultar():
	visible = false


func _on_boton():
	jugar_presionado.emit()
