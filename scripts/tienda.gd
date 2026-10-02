class_name Tienda
extends CanvasLayer
## Tienda: poderes de un solo uso y mejoras permanentes, pagados con monedas.

signal comprada

const CONSUMIBLES := {
	"c_fantasma": {"nombre": "Fantasma (1 uso)", "desc": "lo activas con el botón", "precio": 25, "tipo": GestorPowerUps.Tipo.FANTASMA},
	"c_ahuyentar": {"nombre": "Ahuyentar (1 uso)", "desc": "lo activas con el botón", "precio": 25, "tipo": GestorPowerUps.Tipo.AHUYENTAR},
}
const MEJORAS := {
	"vida": {"nombre": "Vida máxima", "desc": "+10% de vida", "max": 5, "precio": 40},
	"fantasma": {"nombre": "Modo fantasma", "desc": "+1 s de duración", "max": 4, "precio": 60},
	"ahuyentar": {"nombre": "Ahuyentar", "desc": "+1 s de duración", "max": 4, "precio": 60},
	"cargas": {"nombre": "Mochila", "desc": "+1 carga máxima de poderes", "max": 3, "precio": 80},
	"iman": {"nombre": "Imán", "desc": "+8 s de imán al empezar cada nivel", "max": 4, "precio": 50},
}
const ORO := Color(1.0, 0.72, 0.08)
const CIAN := Color(0.0, 1.0, 1.0)
const CRECIMIENTO := 1.7

var monedas := 0
var tope_cargas := 3
var margen_inferior := 0.0
var fuente_margen: Callable      # de dónde sacar el alto del banner
var ajuste_escala := 1.0         # súbelo (1.2, 1.5...) si aún lo ves pequeño; bájalo si lo ves grande
var cargas := {
	GestorPowerUps.Tipo.FANTASMA: 0,
	GestorPowerUps.Tipo.AHUYENTAR: 0,
}

var _niveles := {}
var _sucio := false
var _escala := 1.0
var _ultimo_ancho := -1.0
var _botones_item := {}
var _secciones: Array[Label] = []
var _boton: Button
var _panel: Control
var _fondo: ColorRect
var _cabecera: VBoxContainer
var _titulo: Label
var _etiqueta_monedas: Label
var _scroll: ScrollContainer
var _lista: VBoxContainer
var _cerrar: Button


func _ready():
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	monedas = Ajustes.leer("tienda", "monedas", 0)
	for id in MEJORAS:
		_niveles[id] = Ajustes.leer("tienda", "n_" + id, 0)
	for tipo in cargas:
		cargas[tipo] = Ajustes.leer("tienda", "carga_%d" % tipo, 0)

	_boton = Button.new()
	_boton.focus_mode = Control.FOCUS_NONE
	_estilar(_boton, ORO)
	_boton.pressed.connect(abrir)
	_boton.visible = false
	add_child(_boton)

	_crear_panel()
	_panel.visible = false
	_refrescar()
	#debug monedas
	monedas = 500


func _crear_panel():
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP   # bloquea los toques hacia abajo
	add_child(_panel)

	_fondo = ColorRect.new()
	_fondo.color = Color(0.02, 0.03, 0.08, 0.97)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_fondo)

	_cabecera = VBoxContainer.new()
	_cabecera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_cabecera)
	_titulo = Label.new()
	_titulo.text = "TIENDA"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_color_override("font_color", CIAN)
	_cabecera.add_child(_titulo)
	_etiqueta_monedas = Label.new()
	_etiqueta_monedas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_monedas.add_theme_color_override("font_color", ORO)
	_cabecera.add_child(_etiqueta_monedas)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_lista)

	_seccion("PODERES DE UN USO")
	for id in CONSUMIBLES:
		_crear_item(id)
	_seccion("MEJORAS PERMANENTES")
	for id in MEJORAS:
		_crear_item(id)

	_cerrar = Button.new()
	_cerrar.text = "CERRAR"
	_cerrar.focus_mode = Control.FOCUS_NONE
	_estilar(_cerrar, CIAN)
	_cerrar.pressed.connect(cerrar)
	_panel.add_child(_cerrar)


func _seccion(texto: String):
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", ORO)
	_lista.add_child(l)
	_secciones.append(l)


func _crear_item(id: String):
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_estilar(b, CIAN)
	b.pressed.connect(comprar.bind(id))
	_lista.add_child(b)
	_botones_item[id] = b


# Tamaños de letra y botones según el ancho de la pantalla
func _aplicar_escala():
	var e := _escala
	_boton.add_theme_font_size_override("font_size", int(34 * e))
	_cerrar.add_theme_font_size_override("font_size", int(34 * e))
	_titulo.add_theme_font_size_override("font_size", int(58 * e))
	_etiqueta_monedas.add_theme_font_size_override("font_size", int(38 * e))
	for l in _secciones:
		l.add_theme_font_size_override("font_size", int(28 * e))
	for id in _botones_item:
		var b: Button = _botones_item[id]
		b.add_theme_font_size_override("font_size", int(30 * e))
		b.custom_minimum_size = Vector2(0, 130.0 * e)
	_lista.add_theme_constant_override("separation", int(16 * e))


func _margen() -> float:
	if fuente_margen.is_valid():
		return float(fuente_margen.call())
	return margen_inferior


func _process(_delta):
	var p := get_viewport().get_visible_rect().size
	if absf(p.x - _ultimo_ancho) > 1.0:
		_ultimo_ancho = p.x
		_escala = clampf(p.x / 600.0, 1.0, 2.5) * ajuste_escala
		_aplicar_escala()

	var alto_btn := 90.0 * _escala
	var ancho_btn := 280.0 * _escala
	var y_botones := p.y - _margen() - alto_btn - 50.0
	if _boton.visible:
		_boton.size = Vector2(ancho_btn, alto_btn)
		_boton.position = Vector2((p.x - ancho_btn) / 2.0, y_botones)
	if _panel.visible:
		_panel.size = p
		_fondo.size = p
		var ancho := p.x * 0.92
		var x := (p.x - ancho) / 2.0
		_cabecera.position = Vector2(x, 60)
		_cabecera.size = Vector2(ancho, 0)
		var y_lista := 60.0 + _cabecera.get_combined_minimum_size().y + 16.0
		_scroll.position = Vector2(x, y_lista)
		_scroll.size = Vector2(ancho, maxf(100.0, y_botones - 16.0 - y_lista))
		_cerrar.size = Vector2(ancho_btn, alto_btn)
		_cerrar.position = Vector2((p.x - ancho_btn) / 2.0, y_botones)


func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar()


# ---------- API ----------

func nivel(id: String) -> int:
	return _niveles.get(id, 0)


func precio_de(id: String) -> int:
	var d: Dictionary = MEJORAS[id]
	return int(round(float(d["precio"]) * pow(CRECIMIENTO, _niveles[id])))


func agregar_monedas(n: int):
	monedas += n
	_sucio = true


## Guarda monedas (si cambiaron) y el inventario de poderes.
func guardar():
	if _sucio:
		Ajustes.guardar("tienda", "monedas", monedas)
		_sucio = false
	for tipo in cargas:
		Ajustes.guardar("tienda", "carga_%d" % tipo, cargas[tipo])


func mostrar_boton(v: bool):
	_boton.visible = v
	if not v:
		_panel.visible = false
	_refrescar()


func abrir():
	_refrescar()
	_panel.visible = true


func cerrar():
	_panel.visible = false


func comprar(id: String):
	if CONSUMIBLES.has(id):
		var c: Dictionary = CONSUMIBLES[id]
		var tipo: int = c["tipo"]
		var precio_c := int(c["precio"])
		if cargas[tipo] >= tope_cargas or monedas < precio_c:
			return
		monedas -= precio_c
		cargas[tipo] += 1
	else:
		var d: Dictionary = MEJORAS[id]
		var n: int = _niveles[id]
		if n >= int(d["max"]):
			return
		var precio := precio_de(id)
		if monedas < precio:
			return
		monedas -= precio
		_niveles[id] = n + 1
		Ajustes.guardar("tienda", "n_" + id, n + 1)
	_sucio = true
	guardar()
	_refrescar()
	comprada.emit()


# ---------- Interno ----------

func _refrescar():
	_boton.text = "TIENDA   %d" % monedas
	_etiqueta_monedas.text = "Monedas: %d" % monedas

	for id in CONSUMIBLES:
		var c: Dictionary = CONSUMIBLES[id]
		var tipo: int = c["tipo"]
		var b: Button = _botones_item[id]
		var cabeza := "%s  ·  tienes %d/%d" % [c["nombre"], cargas[tipo], tope_cargas]
		if cargas[tipo] >= tope_cargas:
			b.text = "%s\nLLENO" % cabeza
			b.disabled = true
		else:
			b.text = "%s\n%s  ·  %d monedas" % [cabeza, c["desc"], int(c["precio"])]
			b.disabled = monedas < int(c["precio"])

	for id in MEJORAS:
		var d: Dictionary = MEJORAS[id]
		var n: int = _niveles[id]
		var b: Button = _botones_item[id]
		var cabeza := "%s  ·  Nv %d/%d" % [d["nombre"], n, d["max"]]
		if n >= int(d["max"]):
			b.text = "%s\n%s  ·  MÁXIMO" % [cabeza, d["desc"]]
			b.disabled = true
		else:
			var precio := precio_de(id)
			b.text = "%s\n%s  ·  %d monedas" % [cabeza, d["desc"], precio]
			b.disabled = monedas < precio


func _estilar(b: Button, color: Color):
	for estado in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(estado, _estilo(color, 0.15))
	b.add_theme_stylebox_override("disabled", _estilo(color.darkened(0.55), 0.06))
	for nombre in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(nombre, color)
	b.add_theme_color_override("font_disabled_color", color.darkened(0.4))


func _estilo(color: Color, alfa: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, alfa)
	s.border_color = color
	s.set_border_width_all(3)
	s.set_corner_radius_all(16)
	s.content_margin_left = 20
	s.content_margin_right = 20
	return s
