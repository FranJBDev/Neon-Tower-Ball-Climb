class_name Efectos
extends Node3D
## Efectos de golpes: sonido, chispas y texto de cómic.

var _capa: CanvasLayer
var _sonido := AudioStreamPlayer.new()

var _palabras := ["¡PUM!", "¡CAS!", "¡ZAP!", "¡BAM!", "¡POW!", "¡ZIP!", "¡PAF!", "¡CRASH!"]
var _colores: Array[Color] = [
	Color(1.0, 0.9, 0.1),   # amarillo
	Color(1.0, 0.45, 0.1),  # naranja
	Color(1.0, 0.1, 0.8),   # magenta
	Color(0.1, 0.9, 1.0),   # cian
]


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capa = CanvasLayer.new()
	_capa.layer = 5  # sobre el HUD, bajo el menú
	add_child(_capa)
	_sonido.stream = _crear_sonido_golpe()
	add_child(_sonido)


# Golpe de enemigo: sonido + chispas + texto de cómic
func golpe_enemigo(pos: Vector3):
	var color: Color = _colores.pick_random()
	_sonido.pitch_scale = randf_range(0.9, 1.15)
	_sonido.play()
	#_crear_particulas(pos, color, 36, 1.0, 0.1, 0.7)
	_crear_particulas(pos, color, 36, 1.0, 0.2, 0.7)
	_crear_texto(pos, color)


# Golpe contra una pared: chispas pequeñas. fuerza va de 0.0 a 1.0
func golpe_pared(pos: Vector3, fuerza: float):
	_crear_particulas(pos, Color(0.2, 0.95, 1.0), int(lerpf(8.0, 16.0, fuerza)), 0.6, 0.2, 0.4)
#	_crear_particulas(pos, Color(0.2, 0.95, 1.0), int(lerpf(8.0, 16.0, fuerza)), 0.6, 0.06, 0.4)


func _crear_particulas(pos: Vector3, color: Color, cantidad: int, velocidad: float, radio: float, duracion: float):
	var p := CPUParticles3D.new()

	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 6
	malla.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	malla.material = m
	p.mesh = malla

	var curva := Curve.new()  # las chispas se van encogiendo
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curva

	p.amount = cantidad
	p.lifetime = duracion
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 4.0 * velocidad
	p.initial_velocity_max = 9.0 * velocidad
	p.damping_min = 3.0
	p.damping_max = 5.0

	p.local_coords = true  # <-- nueva línea
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


func _crear_texto(pos: Vector3, color: Color):
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var pantalla := get_viewport().get_visible_rect().size
	var p2d := camara.unproject_position(pos)
	p2d.y -= 90.0  # un poco arriba del golpe, para no tapar las chispas
	p2d.x = clampf(p2d.x, 120.0, pantalla.x - 120.0)
	p2d.y = clampf(p2d.y, 220.0, pantalla.y - 260.0)

	var raiz := Node2D.new()
	raiz.position = p2d
	raiz.rotation = deg_to_rad(randf_range(-15.0, 15.0))
	_capa.add_child(raiz)

	# Estrella: una negra un poco más grande atrás hace de borde
	var puntos := _estrella(105.0, 65.0, 9)
	var borde := Polygon2D.new()
	borde.polygon = puntos
	borde.color = Color.BLACK
	borde.scale = Vector2(1.12, 1.12)
	raiz.add_child(borde)
	var relleno := Polygon2D.new()
	relleno.polygon = puntos
	relleno.color = color
	raiz.add_child(relleno)

	var palabra: String = _palabras.pick_random()
	var etiqueta := Label.new()
	etiqueta.text = palabra
	etiqueta.size = Vector2(300, 100)
	etiqueta.position = -etiqueta.size / 2.0
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 52)
	etiqueta.add_theme_color_override("font_color", Color.WHITE)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 12)
	raiz.add_child(etiqueta)

	# Aparece con rebote, sube un poco y se desvanece
	raiz.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(raiz, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(raiz, "position:y", p2d.y - 40.0, 0.8)
	tw.tween_property(raiz, "modulate:a", 0.0, 0.25).set_delay(0.55)
	tw.chain().tween_callback(raiz.queue_free)


func _estrella(radio_ext: float, radio_int: float, puntas: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in puntas * 2:
		var ang := TAU * i / (puntas * 2.0)
		var r := radio_ext if i % 2 == 0 else radio_int
		r *= randf_range(0.85, 1.1)  # irregular, como dibujada a mano
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	return pts


func _crear_sonido_golpe() -> AudioStreamWAV:
	var tasa := 22050
	var n := int(tasa * 0.22)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	var fase := 0.0
	for i in n:
		var t := float(i) / n
		fase += TAU * lerpf(900.0, 160.0, t) / tasa  # el tono baja rápido
		var env := pow(1.0 - t, 2.0)
		var v := (sin(fase) * 0.65 + randf_range(-1.0, 1.0) * 0.35 * (1.0 - t)) * env
		datos.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767 * 0.95))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = tasa
	s.stereo = false
	s.data = datos
	return s
