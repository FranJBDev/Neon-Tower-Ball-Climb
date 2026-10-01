extends Node3D

@export var columnas := 5
@export var filas := 9
@export var tam_celda := 2.0
@export var grosor := 0.3
@export var alto := 1.0
@export var semilla := 0  # 0 = laberinto distinto cada vez
@export var material_pared: Material
@export var bola: RigidBody3D

@export_group("Vida")
@export var vida_max := 100.0
@export var dano_por_impacto := 3.0   # daño por cada m/s de impacto
@export var escalado_dano := 0.2      # +20% de daño por nivel
@export var curacion_por_nivel := 0.4 # recupera 40% al pasar de nivel

var _contenedor: Node3D
var _mat: Material
var _mat_meta: Material
var _rng := RandomNumberGenerator.new()
var _celda_inicio := Vector2i.ZERO

var _nivel := 1
var _tiempo := 0.0
var _mejor := -1.0
var _vida := 100.0

var _etiqueta: Label
var _barra: ProgressBar
var _estilo_barra: StyleBoxFlat

var _menu: CanvasLayer
var _menu_titulo: Label
var _menu_detalle: Label
var _menu_boton: Button


func _ready():
	if bola == null:
		for hijo in get_children():
			if hijo is RigidBody3D:
				bola = hijo as RigidBody3D
	_vida = vida_max
	_crear_hud()
	_crear_menu()
	generar()
	_mostrar_menu("NEON TOWER", "Inclina el celular\npara llegar a la meta", "JUGAR")


func _process(delta):
	_tiempo += delta
	_actualizar_hud()


# ---------- Flujo del juego ----------

func _iniciar_partida():
	_nivel = 1
	_tiempo = 0.0
	_vida = vida_max
	generar()
	_colocar_bola()
	_actualizar_hud()
	_menu.visible = false
	get_tree().paused = false


func recibir_golpe(impacto: float):
	if get_tree().paused or _vida <= 0.0:
		return
	var mult := 1.0 + escalado_dano * (_nivel - 1)
	_vida = maxf(0.0, _vida - impacto * dano_por_impacto * mult)
	if _vida <= 0.0:
		call_deferred("_fin_del_juego")


func _fin_del_juego():
	var detalle := "Llegaste al nivel %d" % _nivel
	if _mejor >= 0.0:
		detalle += "\nMejor tiempo: %.1f s" % _mejor
	_mostrar_menu("FIN DEL JUEGO", detalle, "REINTENTAR")


func _on_meta_alcanzada(body: Node3D):
	if body is RigidBody3D:
		call_deferred("_nuevo_nivel")


func _nuevo_nivel():
	if _mejor < 0.0 or _tiempo < _mejor:
		_mejor = _tiempo
	_nivel += 1
	_tiempo = 0.0
	_vida = minf(vida_max, _vida + vida_max * curacion_por_nivel)
	if semilla != 0:
		semilla += 1
	generar()
	_colocar_bola()
	_actualizar_hud()


func _colocar_bola():
	if bola:
		var p := _centro_celda(_celda_inicio.x, _celda_inicio.y)
		bola.global_position = to_global(p + Vector3(0, 0.6, 0))
		bola.linear_velocity = Vector3.ZERO
		bola.angular_velocity = Vector3.ZERO


# ---------- Interfaz ----------

func _crear_hud():
	var capa := CanvasLayer.new()
	add_child(capa)

	# Barra de vida: delgada, arriba y de lado a lado
	_barra = ProgressBar.new()
	_barra.show_percentage = false
	_barra.max_value = vida_max
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
	capa.add_child(_barra)
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
	capa.add_child(_etiqueta)
	_etiqueta.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_etiqueta.offset_left = 40
	_etiqueta.offset_right = -40
	_etiqueta.offset_top = 82

	_actualizar_hud()


func _actualizar_hud():
	var texto := "Nivel %d  |  %.1f s" % [_nivel, _tiempo]
	if _mejor >= 0.0:
		texto += "  |  Mejor %.1f s" % _mejor
	_etiqueta.text = texto
	_barra.value = _vida
	_estilo_barra.bg_color = Color(1, 0, 0.3).lerp(Color(0, 1, 1), _vida / vida_max)

func _crear_menu():
	var cian := Color(0, 1, 1)

	_menu = CanvasLayer.new()
	_menu.layer = 10
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu)

	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.7)
	_menu.add_child(velo)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	_menu.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 50)
	centro.add_child(caja)

	_menu_titulo = Label.new()
	_menu_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_titulo.add_theme_font_size_override("font_size", 96)
	_menu_titulo.add_theme_color_override("font_color", cian)
	caja.add_child(_menu_titulo)

	_menu_detalle = Label.new()
	_menu_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_detalle.add_theme_font_size_override("font_size", 40)
	caja.add_child(_menu_detalle)

	_menu_boton = Button.new()
	_menu_boton.custom_minimum_size = Vector2(500, 140)
	_menu_boton.add_theme_font_size_override("font_size", 64)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.03, 0.12, 0.14)
	estilo.border_color = cian
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(20)
	for nombre in ["normal", "hover", "pressed", "focus"]:
		_menu_boton.add_theme_stylebox_override(nombre, estilo)
	for nombre in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_menu_boton.add_theme_color_override(nombre, cian)
	_menu_boton.pressed.connect(_iniciar_partida)
	caja.add_child(_menu_boton)


func _mostrar_menu(titulo: String, detalle: String, boton: String):
	_menu_titulo.text = titulo
	_menu_detalle.text = detalle
	_menu_boton.text = boton
	_menu.visible = true
	get_tree().paused = true


# ---------- Laberinto ----------

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
