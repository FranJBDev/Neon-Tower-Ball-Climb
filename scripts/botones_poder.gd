class_name BotonesPoder
extends Control
## Botones de acción para los poderes guardados (fantasma y ahuyentar).

signal presionado(tipo: int)

@export var alto_banner_dp := 100.0   # un banner estándar mide 50 dp; el adaptativo puede ser más alto

const NOMBRES := {
	GestorPowerUps.Tipo.FANTASMA: "FANTASMA",
	GestorPowerUps.Tipo.AHUYENTAR: "AHUYENTAR",
}

var _botones := {}
var _caja: HBoxContainer
var alto_banner_px := 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_caja = HBoxContainer.new()
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja.alignment = BoxContainer.ALIGNMENT_CENTER
	_caja.add_theme_constant_override("separation", 24)
	add_child(_caja)

	for tipo in NOMBRES:
		var color: Color = GestorPowerUps.COLORES[tipo]
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 100)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)
		for estado in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(estado, _estilo(color, false))
		b.add_theme_stylebox_override("disabled", _estilo(color, true))
		for nombre in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			b.add_theme_color_override(nombre, color)
		b.pressed.connect(_on_presionado.bind(tipo))
		b.visible = false
		_caja.add_child(b)
		_botones[tipo] = b


func _process(_delta):
	var pantalla := get_viewport_rect().size
	_caja.position = Vector2(0, pantalla.y - 150 - _alto_banner())
	_caja.size = Vector2(pantalla.x, 110)


func _estilo(color: Color, activo: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.4 if activo else 0.15)
	s.border_color = color
	s.set_border_width_all(3)
	s.set_corner_radius_all(18)
	return s


func _on_presionado(tipo: int):
	presionado.emit(tipo)


## restante > 0 significa que el poder está activo en este momento.
func actualizar(tipo: int, cantidad: int, restante: float):
	var b: Button = _botones[tipo]
	var activo := restante > 0.0
	b.visible = cantidad > 0 or activo
	b.disabled = activo
	if activo:
		b.text = "%s\n%.1f s" % [NOMBRES[tipo], restante]
	else:
		b.text = "%s\nx%d" % [NOMBRES[tipo], cantidad]

func _alto_banner() -> float:
	var escala := float(DisplayServer.window_get_size().y) / get_viewport_rect().size.y
	if alto_banner_px > 0.0:
		return alto_banner_px / escala
	var px_fisicos := alto_banner_dp * DisplayServer.screen_get_dpi() / 160.0
	return px_fisicos / escala
