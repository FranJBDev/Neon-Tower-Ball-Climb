class_name Tienda
extends CanvasLayer
## Tienda de mejoras permanentes que se pagan con monedas.

signal comprada

const MEJORAS := {
	"vida": {"nombre": "Vida máxima", "desc": "+10% de vida", "max": 5, "precio": 40},
	"fantasma": {"nombre": "Modo fantasma", "desc": "+1 s de duración", "max": 4, "precio": 60},
	"ahuyentar": {"nombre": "Ahuyentar", "desc": "+1 s de duración", "max": 4, "precio": 60},
	"cargas": {"nombre": "Mochila", "desc": "+1 carga máxima de poderes", "max": 3, "precio": 80},
	"iman": {"nombre": "Imán", "desc": "atrae monedas desde más lejos", "max": 4, "precio": 50},
}
const ORO := Color(1.0, 0.72, 0.08)
const CIAN := Color(0.0, 1.0, 1.0)
const CRECIMIENTO := 1.7

var monedas := 0
var margen_inferior := 0.0      # alto del banner de anuncios

var fuente_margen: Callable   # de dónde sacar el alto del banner

var _niveles := {}
var _sucio := false
var _botones_mejora := {}
var _boton: Button
var _panel: Control
var _fondo: ColorRect
var _cabecera: VBoxContainer
var _etiqueta_monedas: Label
var _scroll: ScrollContainer
var _cerrar: Button


func _ready():
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	monedas = Ajustes.leer("tienda", "monedas", 0)
	for id in MEJORAS:
		_niveles[id] = Ajustes.leer("tienda", "n_" + id, 0)

	_boton = Button.new()
	_boton.focus_mode = Control.FOCUS_NONE
	_boton.add_theme_font_size_override("font_size", 30)
	_estilar(_boton, ORO)
	_boton.pressed.connect(abrir)
	_boton.visible = false
	add_child(_boton)

	_crear_panel()
	_panel.visible = false
	_refrescar()
	
	#debug monedas
	monedas = 500

func _margen() -> float:
	if fuente_margen.is_valid():
		return float(fuente_margen.call())
	return margen_inferior

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
	var titulo := Label.new()
	titulo.text = "TIENDA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 52)
	titulo.add_theme_color_override("font_color", CIAN)
	_cabecera.add_child(titulo)
	_etiqueta_monedas = Label.new()
	_etiqueta_monedas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_monedas.add_theme_font_size_override("font_size", 34)
	_etiqueta_monedas.add_theme_color_override("font_color", ORO)
	_cabecera.add_child(_etiqueta_monedas)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 14)
	_scroll.add_child(lista)
	for id in MEJORAS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 100)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 26)
		_estilar(b, CIAN)
		b.pressed.connect(comprar.bind(id))
		lista.add_child(b)
		_botones_mejora[id] = b

	_cerrar = Button.new()
	_cerrar.text = "CERRAR"
	_cerrar.focus_mode = Control.FOCUS_NONE
	_cerrar.add_theme_font_size_override("font_size", 30)
	_estilar(_cerrar, CIAN)
	_cerrar.pressed.connect(cerrar)
	_panel.add_child(_cerrar)


func _process(_delta):
	var p := get_viewport().get_visible_rect().size
	var margen := _margen()
	if _boton.visible:
		_boton.size = Vector2(260, 90)
		_boton.position = Vector2((p.x - 260.0) / 2.0, p.y - 150.0 - margen)
	if _panel.visible:
		_panel.size = p
		_fondo.size = p
		var ancho := minf(p.x - 80.0, 680.0)
		var x := (p.x - ancho) / 2.0
		_cabecera.position = Vector2(x, 70)
		_cabecera.size = Vector2(ancho, 0)
		var y_lista := 70.0 + _cabecera.get_combined_minimum_size().y + 16.0
		var y_cerrar := p.y - 150.0 - margen
		_scroll.position = Vector2(x, y_lista)
		_scroll.size = Vector2(ancho, maxf(100.0, y_cerrar - 16.0 - y_lista))
		_cerrar.size = Vector2(260, 90)
		_cerrar.position = Vector2((p.x - 260.0) / 2.0, y_cerrar)
		
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


func guardar():
	if _sucio:
		Ajustes.guardar("tienda", "monedas", monedas)
		_sucio = false


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
	var d: Dictionary = MEJORAS[id]
	var n: int = _niveles[id]
	if n >= int(d["max"]):
		return
	var precio := precio_de(id)
	if monedas < precio:
		return
	monedas -= precio
	_niveles[id] = n + 1
	Ajustes.guardar("tienda", "monedas", monedas)
	Ajustes.guardar("tienda", "n_" + id, n + 1)
	_sucio = false
	_refrescar()
	comprada.emit()


# ---------- Interno ----------

func _refrescar():
	_boton.text = "TIENDA   %d" % monedas
	_etiqueta_monedas.text = "Monedas: %d" % monedas
	for id in MEJORAS:
		var d: Dictionary = MEJORAS[id]
		var n: int = _niveles[id]
		var b: Button = _botones_mejora[id]
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
