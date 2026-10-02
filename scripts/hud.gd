class_name Hud
extends CanvasLayer
## Barra de vida, nivel y tiempo.

signal boton_musica_presionado

var _boton_musica: BotonSonido
var _etiqueta: Label
var _barra: ProgressBar
var _estilo_barra: StyleBoxFlat


func _ready():
	# Barra de vida: delgada, arriba y de lado a lado
	_barra = ProgressBar.new()
	_barra.show_percentage = false
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	fondo.border_color = Color(0, 1, 1)
	fondo.set_border_width_all(2)
	fondo.set_corner_radius_all(6)
	_estilo_barra = StyleBoxFlat.new()
	_estilo_barra.bg_color = Color(0, 1, 1)
	_estilo_barra.set_corner_radius_all(6)
	_barra.add_theme_stylebox_override("background", fondo)
	_barra.add_theme_stylebox_override("fill", _estilo_barra)
	add_child(_barra)
	_barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_barra.offset_left = 40
	_barra.offset_right = -40
	_barra.offset_top = 50
	_barra.offset_bottom = 74

	# Texto en una sola línea debajo de la barra
	_etiqueta = Label.new()
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.add_theme_font_size_override("font_size", 36)
	_etiqueta.add_theme_color_override("font_color", Color(0, 1, 1))
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 8)
	add_child(_etiqueta)
	_etiqueta.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_etiqueta.offset_left = 40
	_etiqueta.offset_right = -40
	_etiqueta.offset_top = 82
	# Botón de música (arriba a la derecha, debajo de la barra)
	layer = 20  # sobre el menú, para poder usarlo también en la pantalla de inicio
	process_mode = Node.PROCESS_MODE_ALWAYS

	_boton_musica = BotonSonido.new()
	_boton_musica.focus_mode = Control.FOCUS_NONE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.03, 0.12, 0.14, 0.75)
	estilo.border_color = Color(0, 1, 1)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(12)
	for nombre in ["normal", "hover", "pressed", "focus"]:
		_boton_musica.add_theme_stylebox_override(nombre, estilo)
	_boton_musica.pressed.connect(func(): boton_musica_presionado.emit())
	add_child(_boton_musica)
	_boton_musica.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_boton_musica.offset_left = -104
	_boton_musica.offset_right = -40
	_boton_musica.offset_top = 84
	_boton_musica.offset_bottom = 148


func actualizar(nivel: int, tiempo: float, mejor: float, vida: float, vida_max: float):
	var texto := "Nivel %d  |  %.1f s" % [nivel, tiempo]
	if mejor >= 0.0:
		texto += "  |  Mejor %.1f s" % mejor
	_etiqueta.text = texto
	_barra.max_value = vida_max
	_barra.value = vida
	_estilo_barra.bg_color = Color(1, 0, 0.3).lerp(Color(0, 1, 1), vida / vida_max)

func set_musica_silenciada(valor: bool):
	_boton_musica.silenciado = valor
	_boton_musica.queue_redraw()
	
class BotonSonido extends Button:
	var silenciado := false

	func _draw():
		var cian := Color(0, 1, 1)
		# Bocina
		draw_colored_polygon(PackedVector2Array([
			Vector2(14, 26), Vector2(24, 26), Vector2(36, 16),
			Vector2(36, 48), Vector2(24, 38), Vector2(14, 38)]), cian)
		if silenciado:
			var rojo := Color(1, 0.2, 0.4)
			draw_line(Vector2(42, 24), Vector2(56, 40), rojo, 4.0)
			draw_line(Vector2(56, 24), Vector2(42, 40), rojo, 4.0)
		else:
			draw_arc(Vector2(38, 32), 10.0, -0.9, 0.9, 12, cian, 3.0)
			draw_arc(Vector2(38, 32), 18.0, -0.9, 0.9, 12, cian, 3.0)
