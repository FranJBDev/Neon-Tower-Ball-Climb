class_name GestorEnemigos
extends Node3D
## Crea los enemigos de cada nivel y avisa cuando tocan a la esfera.

signal enemigo_toco(enemigo: Node3D, cuerpo: RigidBody3D)

var objetivo: Node3D                 # la bola; la asigna laberinto.gd
var nivel_perseguidores := 4         # desde qué nivel aparecen

var max_enemigos := 15
var velocidad_base := 1.2

var _gen: GeneradorLaberinto
var _rng: RandomNumberGenerator

var objetivo_huida: Node3D
var _huida := 0.0

func crear(gen: GeneradorLaberinto, nivel: int, rng: RandomNumberGenerator):
	_huida = 0.0
	limpiar()
	_gen = gen
	_rng = rng
	# Base según el tamaño del laberinto (~8 en 25x35) y crece con el nivel
	var base := int(gen.columnas * gen.filas / 100.0)
	var cantidad := mini(base + int(nivel / 2.0), max_enemigos)
	var vel := minf(velocidad_base + 0.1 * (nivel - 1), 2.5)

	# Solo celdas lejos de la salida
	var libres: Array[Vector2i] = []
	for c in gen.columnas:
		for r in gen.filas:
			var dist := absi(c - gen.celda_inicio.x) + absi(r - gen.celda_inicio.y)
			if dist >= 8:
				libres.append(Vector2i(c, r))

	var colocados: Array[Vector2i] = []
	for i in cantidad:
		if libres.is_empty():
			break
		# Intenta que no nazcan amontonados (mínimo 5 celdas entre ellos)
		var celda := Vector2i.ZERO
		var elegida := false
		for intento in 15:
			var candidata: Vector2i = libres[rng.randi() % libres.size()]
			var lejos := true
			for o in colocados:
				if absi(candidata.x - o.x) + absi(candidata.y - o.y) < 5:
					lejos = false
					break
			if lejos:
				celda = candidata
				elegida = true
				break
		if not elegida:
			celda = libres[rng.randi() % libres.size()]
		libres.erase(celda)
		colocados.append(celda)

		var e := Enemigo.new()
		e.gestor = self
		e.celda = celda
		e.destino = siguiente_celda(celda, Vector2i(-1, -1))
		e.velocidad = vel
		e.position = posicion_celda(celda)
		add_child(e)
		
		# Perseguidores (niveles altos)
	var n_pers := 0
	if nivel >= nivel_perseguidores:
		n_pers = mini(1 + int((nivel - nivel_perseguidores) / 3.0), 4)
	for i in n_pers:
		var lejanas := libres.filter(func(c): return absi(c.x - gen.celda_inicio.x) + absi(c.y - gen.celda_inicio.y) >= 14)
		if lejanas.is_empty():
			break
		var celda: Vector2i = lejanas[rng.randi() % lejanas.size()]
		libres.erase(celda)
		var p := EnemigoPerseguidor.new()
		p.gestor = self
		p.celda = celda
		p.velocidad = vel
		p.position = posicion_celda(celda)
		add_child(p)

func limpiar():
	for hijo in get_children():
		hijo.queue_free()


# Los usan los enemigos
func posicion_celda(c: Vector2i) -> Vector3:
	return _gen.centro_celda(c.x, c.y) + Vector3(0, 0.55, 0)


func siguiente_celda(c: Vector2i, previa: Vector2i) -> Vector2i:
	if _huida > 0.0 and objetivo_huida:
		# Elige el vecino más lejos de la bola
		var pos_bola := to_local(objetivo_huida.global_position)
		var mejor := c
		var mejor_d := -1.0
		for v in _gen.vecinos_abiertos(c):
			var d := _gen.centro_celda(v.x, v.y).distance_to(pos_bola)
			if d > mejor_d:
				mejor_d = d
				mejor = v
		return mejor
	return _gen.siguiente_celda(c, previa, _rng)


func golpe(enemigo: Node3D, cuerpo: RigidBody3D):
	enemigo_toco.emit(enemigo, cuerpo)

func distancia_minima(pos: Vector3) -> float:
	var d := INF
	for hijo in get_children():
		if (hijo is Enemigo or hijo is EnemigoPerseguidor) and not hijo.is_queued_for_deletion():
			d = minf(d, hijo.global_position.distance_to(pos))
	return d

func ahuyentar(bola: Node3D, segundos: float):
	objetivo_huida = bola
	_huida = segundos

func _process(delta):
	_huida = maxf(0.0, _huida - delta)

func huida_restante() -> float:
	return _huida

func huyendo() -> bool:
	return _huida > 0.0


func celda_de(pos_global: Vector3) -> Vector2i:
	var p := to_local(pos_global)
	var c := clampi(int(floor(p.x / _gen.tam_celda + _gen.columnas / 2.0)), 0, _gen.columnas - 1)
	var r := clampi(int(floor(p.z / _gen.tam_celda + _gen.filas / 2.0)), 0, _gen.filas - 1)
	return Vector2i(c, r)


func posicion_objetivo() -> Vector3:
	var p := to_local(objetivo.global_position)
	p.y = 0.55
	return p


## Camino más corto por el laberinto (búsqueda en anchura).
## Devuelve las celdas a seguir; vacío si está a más de max_pasos o ya está en la misma celda.
func camino_hacia(desde: Vector2i, hasta: Vector2i, max_pasos: int) -> Array[Vector2i]:
	var vacio: Array[Vector2i] = []
	if desde == hasta:
		return vacio
	var prev := {desde: desde}
	var frente: Array[Vector2i] = [desde]
	var pasos := 0
	while not frente.is_empty() and pasos < max_pasos:
		pasos += 1
		var siguiente: Array[Vector2i] = []
		for c in frente:
			for v in _gen.vecinos_abiertos(c):
				if prev.has(v):
					continue
				prev[v] = c
				if v == hasta:
					var camino: Array[Vector2i] = [v]
					var a: Vector2i = c
					while a != desde:
						camino.push_front(a)
						a = prev[a]
					return camino
				siguiente.append(v)
		frente = siguiente
	return vacio
