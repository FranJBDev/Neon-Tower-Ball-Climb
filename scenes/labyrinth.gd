extends Node3D

@export var columnas := 5
@export var filas := 9
@export var tam_celda := 2.0
@export var grosor := 0.3
@export var alto := 1.0
@export var semilla := 0  # 0 = laberinto distinto cada vez
@export var material_pared: Material
@export var bola: RigidBody3D

var _nivel := 1
var _tiempo := 0.0
var _mejor := -1.0
var _etiqueta: Label

var _contenedor: Node3D
var _mat: Material
var _mat_meta: Material
var _rng := RandomNumberGenerator.new()
var _celda_inicio := Vector2i.ZERO


func _ready():
	if bola == null:
		bola = get_node_or_null("Ball") as RigidBody3D
	generar()
	_crear_hud()

func _process(delta):
	_tiempo += delta
	_actualizar_hud()

func generar():
	if semilla == 0:
		_rng.randomize()
	else:
		_rng.seed = semilla

	if _contenedor:
		_contenedor.queue_free()
	_contenedor = Node3D.new()
	_contenedor.name = "ParedesGeneradas"
	add_child(_contenedor)

	var pared_der := []
	var pared_abajo := []
	var visitada := []
	for c in columnas:
		pared_der.append([])
		pared_abajo.append([])
		visitada.append([])
		for r in filas:
			pared_der[c].append(true)
			pared_abajo[c].append(true)
			visitada[c].append(false)

	var inicio := Vector2i(int(columnas / 2.0), filas - 1)
	_celda_inicio = inicio
	var meta := inicio
	var prof_max := 1
	var pila: Array[Vector2i] = [inicio]
	visitada[inicio.x][inicio.y] = true

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
			var sig: Vector2i = vecinos[_rng.randi() % vecinos.size()]
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
			# La celda más profunda del recorrido es la más lejana
			if pila.size() > prof_max:
				prof_max = pila.size()
				meta = sig

	var x0 := -columnas * tam_celda / 2.0
	var z0 := -filas * tam_celda / 2.0
	var y := alto / 2.0

	for c in columnas - 1:
		for r in filas:
			if pared_der[c][r]:
				_crear_pared(
					Vector3(x0 + (c + 1) * tam_celda, y, z0 + (r + 0.5) * tam_celda),
					Vector3(grosor, alto, tam_celda + grosor))

	for c in columnas:
		for r in filas - 1:
			if pared_abajo[c][r]:
				_crear_pared(
					Vector3(x0 + (c + 0.5) * tam_celda, y, z0 + (r + 1) * tam_celda),
					Vector3(tam_celda + grosor, alto, grosor))

	_crear_meta(meta)


func _centro_celda(c: int, r: int) -> Vector3:
	return Vector3(
		(c + 0.5 - columnas / 2.0) * tam_celda,
		0.0,
		(r + 0.5 - filas / 2.0) * tam_celda)


func _crear_pared(pos: Vector3, tam: Vector3):
	var cuerpo := StaticBody3D.new()
	cuerpo.position = pos

	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	cuerpo.add_child(col)

	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	malla.mesh = caja
	malla.material_override = _obtener_material()
	cuerpo.add_child(malla)

	_contenedor.add_child(cuerpo)


func _crear_meta(celda: Vector2i):
	var area := Area3D.new()
	area.position = _centro_celda(celda.x, celda.y)

	var col := CollisionShape3D.new()
	var forma := CylinderShape3D.new()
	forma.radius = 0.6
	forma.height = 1.5
	col.shape = forma
	col.position.y = 0.9
	area.add_child(col)

	var malla := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.6
	disco.bottom_radius = 0.6
	disco.height = 0.02
	malla.mesh = disco
	malla.position.y = 0.26
	malla.material_override = _obtener_material_meta()
	area.add_child(malla)

	area.body_entered.connect(_on_meta_alcanzada)
	_contenedor.add_child(area)


func _on_meta_alcanzada(body: Node3D):
	if body == bola:
		call_deferred("_nuevo_nivel")


func _nuevo_nivel():
	if semilla != 0:
		semilla += 1
	if _mejor < 0.0 or _tiempo < _mejor:
		_mejor = _tiempo
	_nivel += 1
	_tiempo = 0.0
	generar()
	if bola:
		var p := _centro_celda(_celda_inicio.x, _celda_inicio.y)
		bola.global_position = to_global(p + Vector3(0, 0.6, 0))
		bola.linear_velocity = Vector3.ZERO
		bola.angular_velocity = Vector3.ZERO


func _obtener_material() -> Material:
	if material_pared:
		return material_pared
	if _mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0, 1, 1)
		m.emission_enabled = true
		m.emission = Color(0, 0.7, 0.7)
		m.emission_energy_multiplier = 4.0
		_mat = m
	return _mat


func _obtener_material_meta() -> Material:
	if _mat_meta == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0, 0.8)
		m.emission_enabled = true
		m.emission = Color(1, 0, 0.8)
		m.emission_energy_multiplier = 3.0
		_mat_meta = m
	return _mat_meta
	
func _crear_hud():
	var capa := CanvasLayer.new()
	add_child(capa)
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(40, 60)
	_etiqueta.add_theme_font_size_override("font_size", 48)
	_etiqueta.add_theme_color_override("font_color", Color(0, 1, 1))
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 10)
	capa.add_child(_etiqueta)


func _actualizar_hud():
	var texto := "Nivel %d\nTiempo %.1f s" % [_nivel, _tiempo]
	if _mejor >= 0.0:
		texto += "\nMejor %.1f s" % _mejor
	_etiqueta.text = texto
