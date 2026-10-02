class_name GeneradorLaberinto
extends RefCounted
## Crea la estructura del laberinto (solo datos, sin nodos 3D).

var columnas: int
var filas: int
var tam_celda: float
var pared_der := []     # pared_der[c][r]: pared entre (c,r) y (c+1,r)
var pared_abajo := []   # pared_abajo[c][r]: pared entre (c,r) y (c,r+1)
var celda_inicio := Vector2i.ZERO
var celda_meta := Vector2i.ZERO


func _init(cols: int, fils: int, tam: float):
	columnas = cols
	filas = fils
	tam_celda = tam

func agregar_atajos(cantidad: int, rng: RandomNumberGenerator):
	var abiertas := 0
	var intentos := 0
	while abiertas < cantidad and intentos < cantidad * 20:
		intentos += 1
		var c := rng.randi_range(0, columnas - 1)
		var r := rng.randi_range(0, filas - 1)
		match rng.randi() % 4:
			0:  # derecha
				if c < columnas - 1 and pared_der[c][r]:
					pared_der[c][r] = false
					abiertas += 1
			1:  # izquierda
				if c > 0 and pared_der[c - 1][r]:
					pared_der[c - 1][r] = false
					abiertas += 1
			2:  # abajo
				if r < filas - 1 and pared_abajo[c][r]:
					pared_abajo[c][r] = false
					abiertas += 1
			3:  # arriba
				if r > 0 and pared_abajo[c][r - 1]:
					pared_abajo[c][r - 1] = false
					abiertas += 1

func generar(rng: RandomNumberGenerator):
	var visitada := []
	for c in columnas:
		pared_der.append([])
		pared_abajo.append([])
		visitada.append([])
		for r in filas:
			pared_der[c].append(true)
			pared_abajo[c].append(true)
			visitada[c].append(false)

	celda_inicio = Vector2i(int(columnas / 2.0), filas - 1)
	celda_meta = celda_inicio
	var prof_max := 1
	var pila: Array[Vector2i] = [celda_inicio]
	visitada[celda_inicio.x][celda_inicio.y] = true

	while not pila.is_empty():
		var actual: Vector2i = pila.back()
		var vecinos: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = actual + d
			if n.x >= 0 and n.x < columnas and n.y >= 0 and n.y < filas and not visitada[n.x][n.y]:
				vecinos.append(n)

		if vecinos.is_empty():
			pila.pop_back()
		else:
			var sig: Vector2i = vecinos[rng.randi() % vecinos.size()]
			if sig.x > actual.x:
				pared_der[actual.x][actual.y] = false
			elif sig.x < actual.x:
				pared_der[sig.x][sig.y] = false
			elif sig.y > actual.y:
				pared_abajo[actual.x][actual.y] = false
			else:
				pared_abajo[sig.x][sig.y] = false
			visitada[sig.x][sig.y] = true
			pila.append(sig)
			# La celda más profunda del recorrido es la más lejana: la meta
			if pila.size() > prof_max:
				prof_max = pila.size()
				celda_meta = sig


func centro_celda(c: int, r: int) -> Vector3:
	return Vector3(
		(c + 0.5 - columnas / 2.0) * tam_celda,
		0.0,
		(r + 0.5 - filas / 2.0) * tam_celda)


func vecinos_abiertos(c: Vector2i) -> Array[Vector2i]:
	var v: Array[Vector2i] = []
	if c.x < columnas - 1 and not pared_der[c.x][c.y]:
		v.append(Vector2i(c.x + 1, c.y))
	if c.x > 0 and not pared_der[c.x - 1][c.y]:
		v.append(Vector2i(c.x - 1, c.y))
	if c.y < filas - 1 and not pared_abajo[c.x][c.y]:
		v.append(Vector2i(c.x, c.y + 1))
	if c.y > 0 and not pared_abajo[c.x][c.y - 1]:
		v.append(Vector2i(c.x, c.y - 1))
	return v


func siguiente_celda(c: Vector2i, previa: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var v := vecinos_abiertos(c)
	if v.size() > 1:
		v.erase(previa)  # no se devuelve, salvo en callejones sin salida
	return v[rng.randi() % v.size()]
