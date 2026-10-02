class_name Minimapa
extends Control
## Minimapa sin paredes: solo muestra al jugador y la meta.

var tam_mapa := Vector2(100, 140)   # misma proporción que 25x35
var margen := Vector2(150, 90)       # separación del borde derecho y de arriba

var _gen: GeneradorLaberinto
var _origen: Node3D
var _bola: Node3D


func _ready():
	size = tam_mapa
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configurar(gen: GeneradorLaberinto, origen: Node3D, bola: Node3D):
	_gen = gen
	_origen = origen
	_bola = bola


func _process(_delta):
	var pantalla := get_viewport_rect().size
	position = Vector2(pantalla.x - tam_mapa.x - margen.x, margen.y)
	queue_redraw()


func _a_mapa(local: Vector3) -> Vector2:
	var ancho := _gen.columnas * _gen.tam_celda
	var alto := _gen.filas * _gen.tam_celda
	return Vector2(
		(local.x / ancho + 0.5) * tam_mapa.x,
		(local.z / alto + 0.5) * tam_mapa.y)


func _draw():
	if _gen == null or _bola == null:
		return
	# Fondo y borde
	draw_rect(Rect2(Vector2.ZERO, tam_mapa), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(Vector2.ZERO, tam_mapa), Color(0, 1, 1, 0.6), false, 2.0)

	# Meta (parpadea suave)
	var meta := _a_mapa(_gen.centro_celda(_gen.celda_meta.x, _gen.celda_meta.y))
	var pulso := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
	draw_circle(meta, 5.0 * pulso + 2.0, Color(1, 0, 0.8))

	# Jugador
	var yo := _a_mapa(_origen.to_local(_bola.global_position))
	yo = yo.clamp(Vector2.ZERO, tam_mapa)
	draw_circle(yo, 4.0, Color(0, 1, 1))
	draw_circle(yo, 2.0, Color.WHITE)
