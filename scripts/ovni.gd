class_name Ovni
extends Node3D
## OVNI que cruza la pantalla formando una Z; si la bola está cerca, le dispara.

signal cargando
signal disparo
signal terminado

const ALTURA := 1.6
const ESCALA := 0.5    # tamaño del platillo
const RANGO := 4.5          # distancia (en el suelo) a la que empieza a apuntar
const RANGO_FALLO := 6.5    # si durante la carga te alejas más que esto, falla
const TIEMPO_CARGA := 0.8
const MAX_INTENTOS := 2
const COLOR := Color(0.65, 0.2, 1.0)

# Esquinas de la Z en coordenadas de pantalla (0 a 1), un poco fuera de ella
const PUNTOS := [Vector2(-0.2, 0.2), Vector2(1.2, 0.2), Vector2(-0.2, 0.8), Vector2(1.2, 0.8)]
const DURACIONES := [2.0, 1.6, 2.0]  # segundos de cada tramo
const SIN_DISPARO := false   # ponlo en true para ver la Z completa sin que dispare

var _ruta: Array[Vector3] = []
var camara: Camera3D
var bola: Node3D

var _tramo := 0
var _t := 0.0
var _carga := -1.0       # menor que 0: no está cargando
var _intentos := 0
var _espera := 0.0
var _flash := 0.0
var _ya_disparo := false
var _terminando := false
var _luces: Node3D
var _mat_luces: StandardMaterial3D
var _rayo: MeshInstance3D
var _rayo_mesh: CylinderMesh


func _ready():
	top_level = true
	scale = Vector3.ONE * ESCALA

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.emission_enabled = true
	mat.emission = COLOR
	mat.emission_energy_multiplier = 1.2
	mat.disable_fog = true

	# Cuerpo (disco aplastado)
	var cuerpo := MeshInstance3D.new()
	var disco := SphereMesh.new()
	disco.radius = 0.9
	disco.height = 1.8
	cuerpo.mesh = disco
	cuerpo.scale = Vector3(1.0, 0.3, 1.0)
	cuerpo.material_override = mat
	add_child(cuerpo)

	# Cúpula
	var domo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.4
	esfera.height = 0.8
	domo.mesh = esfera
	domo.position.y = 0.15
	var mat_domo := StandardMaterial3D.new()
	mat_domo.albedo_color = Color(0.7, 1.0, 1.0)
	mat_domo.emission_enabled = true
	mat_domo.emission = Color(0.6, 1.0, 1.0)
	mat_domo.disable_fog = true
	domo.material_override = mat_domo
	add_child(domo)

	# Luces giratorias
	_luces = Node3D.new()
	add_child(_luces)
	_mat_luces = StandardMaterial3D.new()
	_mat_luces.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_luces.albedo_color = Color(1.0, 1.0, 0.5)
	_mat_luces.disable_fog = true
	for i in 6:
		var luz := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.09
		s.height = 0.18
		luz.mesh = s
		luz.material_override = _mat_luces
		var ang := TAU * i / 6.0
		luz.position = Vector3(cos(ang) * 0.78, -0.02, sin(ang) * 0.78)
		_luces.add_child(luz)

	# Rayo
	_rayo_mesh = CylinderMesh.new()
	_rayo_mesh.radial_segments = 8
	_rayo_mesh.height = 1.0
	var mat_rayo := StandardMaterial3D.new()
	mat_rayo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_rayo.albedo_color = Color(1.0, 0.1, 0.2)
	mat_rayo.disable_fog = true
	_rayo_mesh.material = mat_rayo
	_rayo = MeshInstance3D.new()
	_rayo.mesh = _rayo_mesh
	_rayo.visible = false
	add_child(_rayo)
	
	# Estela que dibuja la Z
	var estela := CPUParticles3D.new()
	estela.amount = 100
	estela.lifetime = 2.5
	estela.local_coords = false          # las partículas se quedan donde se emitieron
	estela.gravity = Vector3.ZERO
	estela.initial_velocity_min = 0.0
	estela.initial_velocity_max = 0.0
	var punto := SphereMesh.new()
	punto.radius = 0.1
	punto.height = 0.4
	var mat_estela := StandardMaterial3D.new()
	mat_estela.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_estela.albedo_color = COLOR
	mat_estela.disable_fog = true
	punto.material = mat_estela
	estela.mesh = punto
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	estela.scale_amount_curve = curva    # los puntos se encogen hasta desaparecer
	add_child(estela)
	estela.emitting = true

	if camara:
		_ruta = _calcular_ruta()
		global_position = _ruta[0]

func _process(delta):
	if camara == null or bola == null or _terminando:
		return

	# Destello del disparo (el OVNI sigue volando mientras dura)
	if _flash > 0.0:
		_flash -= delta
		_actualizar_rayo(0.2)
		if _flash <= 0.0:
			_rayo.visible = false

	# Avance por la Z
	_t += delta
	if _t >= DURACIONES[_tramo]:
		_t -= DURACIONES[_tramo]
		_tramo += 1
		if _tramo >= DURACIONES.size():
			_terminar()
			return
	global_position = _posicion_ruta()
	_luces.rotate_y(delta * 4.0)

	# Apuntar y disparar (una sola vez, y no durante el primer trazo)
	_espera = maxf(0.0, _espera - delta)
	var distancia := _dist_suelo()
	if _carga < 0.0:
		_mat_luces.albedo_color = Color(1.0, 1.0, 0.5)
		if distancia < RANGO and not _ya_disparo and _intentos < MAX_INTENTOS \
				and _espera <= 0.0 and _tramo >= 1 and not SIN_DISPARO:
			_carga = 0.0
			_intentos += 1
			_rayo.visible = true
			cargando.emit()
	else:
		_carga += delta
		_actualizar_rayo(0.03 + 0.02 * sin(_carga * 40.0))
		_mat_luces.albedo_color = Color(1.0, 0.1, 0.1) if int(_carga * 12.0) % 2 == 0 else Color(1.0, 1.0, 1.0)
		if _carga >= TIEMPO_CARGA:
			if distancia <= RANGO_FALLO:
				_disparar()
			else:
				_carga = -1.0
				_espera = 1.5
				_rayo.visible = false


func _disparar():
	_carga = -1.0
	_ya_disparo = true
	_flash = 0.2
	_rayo.visible = true
	_actualizar_rayo(0.2)
	disparo.emit()


func _terminar():
	if _terminando:
		return
	_terminando = true
	_rayo.visible = false
	terminado.emit()
	queue_free()

func _dist_suelo() -> float:
	return Vector2(global_position.x - bola.global_position.x,
		global_position.z - bola.global_position.z).length()


# Posición actual sobre la Z, proyectando la pantalla al plano de vuelo
# Las 4 esquinas de la Z, proyectadas desde la pantalla al plano de vuelo en el momento de aparecer
func _calcular_ruta() -> Array[Vector3]:
	var ruta: Array[Vector3] = []
	var tam := get_viewport().get_visible_rect().size
	for uv in PUNTOS:
		var punto := Vector2(uv.x * tam.x, uv.y * tam.y)
		var origen := camara.project_ray_origin(punto)
		var dir := camara.project_ray_normal(punto)
		var p = Plane(Vector3.UP, ALTURA).intersects_ray(origen, dir)
		ruta.append((p as Vector3) if p != null else bola.global_position + Vector3(0, ALTURA, 0))
	return ruta


func _posicion_ruta() -> Vector3:
	return _ruta[_tramo].lerp(_ruta[_tramo + 1], clampf(_t / DURACIONES[_tramo], 0.0, 1.0))
func _actualizar_rayo(radio: float):
	var a := global_position
	var b := bola.global_position
	var dir := b - a
	var largo := dir.length()
	if largo < 0.01:
		return
	var y := dir / largo
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	_rayo_mesh.height = largo
	_rayo_mesh.top_radius = radio
	_rayo_mesh.bottom_radius = radio
	_rayo.global_transform = Transform3D(Basis(x, y, z), (a + b) / 2.0)
