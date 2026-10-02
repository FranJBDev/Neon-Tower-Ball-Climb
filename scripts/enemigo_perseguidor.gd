class_name EnemigoPerseguidor
extends Node3D
## Patrulla; si la bola está cerca por el camino del laberinto, la persigue.

const COLOR := Color(0.749, 0.0, 0.059, 1.0)   # naranja: cámbialo si se parece a tus otros enemigos
const VISION_PASOS := 6      # a cuántas celdas de camino "te ve"
const SOLTAR_PASOS := 10     # a cuántas celdas de camino te pierde
const VEL_PERSECUCION := 1.4 # multiplicador de velocidad al perseguir

var gestor: GestorEnemigos
var celda := Vector2i.ZERO
var velocidad := 1.2

var _previa := Vector2i(-1, -1)
var _meta := Vector3.ZERO
var _persiguiendo := false
var _malla: Node3D
var _mat: StandardMaterial3D
var _area: Area3D


func _ready():
	_meta = position

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR
	_mat.emission_enabled = true
	_mat.emission = COLOR
	_mat.emission_energy_multiplier = 1.5

	# Diamante: dos conos pegados por la base
	_malla = Node3D.new()
	add_child(_malla)
	for arriba in [true, false]:
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.38
		cono.height = 0.45
		var mi := MeshInstance3D.new()
		mi.mesh = cono
		mi.material_override = _mat
		mi.position.y = 0.225 if arriba else -0.225
		if not arriba:
			mi.rotation_degrees.x = 180
		_malla.add_child(mi)

	_area = Area3D.new()
	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = 0.45
	col.shape = forma
	_area.add_child(col)
	add_child(_area)


func _process(delta):
	if gestor == null or gestor.objetivo == null:
		return

	# Aspecto: gira más rápido y brilla más al perseguir
	_malla.rotate_y(delta * (6.0 if _persiguiendo else 2.0))
	if _persiguiendo:
		_mat.emission_energy_multiplier = 3.5 + sin(Time.get_ticks_msec() / 80.0)
	else:
		_mat.emission_energy_multiplier = 1.5

	# Contacto con la bola (el daño tiene su propio tiempo de espera en laberinto.gd)
	for b in _area.get_overlapping_bodies():
		if b is RigidBody3D:
			gestor.golpe(self, b as RigidBody3D)
			break

	# Si está en la misma celda que la bola, va directo hacia ella
	if _persiguiendo and not gestor.huyendo() \
			and gestor.celda_de(gestor.objetivo.global_position) == celda:
		_meta = gestor.posicion_objetivo()

	var falta := _meta - position
	if falta.length() < 0.05:
		_elegir_meta()
		return
	var vel := velocidad * (VEL_PERSECUCION if _persiguiendo else 1.0)
	position += falta.normalized() * minf(vel * delta, falta.length())


func _elegir_meta():
	if gestor.huyendo():
		_persiguiendo = false
		_ir_a(gestor.siguiente_celda(celda, _previa))
		return

	var c_bola := gestor.celda_de(gestor.objetivo.global_position)
	if c_bola == celda:
		_persiguiendo = true
		_meta = gestor.posicion_objetivo()
		return

	var camino := gestor.camino_hacia(celda, c_bola, SOLTAR_PASOS if _persiguiendo else VISION_PASOS)
	if camino.is_empty():
		_persiguiendo = false
		_ir_a(gestor.siguiente_celda(celda, _previa))
	else:
		_persiguiendo = true
		_ir_a(camino[0])


func _ir_a(destino: Vector2i):
	_previa = celda
	celda = destino
	_meta = gestor.posicion_celda(destino)
