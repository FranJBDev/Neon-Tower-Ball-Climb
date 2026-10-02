class_name Enemigo
extends Area3D
## Un enemigo: vaga de celda en celda y avisa si toca la esfera.

var gestor  # el GestorEnemigos que lo creó
var celda := Vector2i.ZERO
var destino := Vector2i.ZERO
var velocidad := 1.2
var _malla: MeshInstance3D


func _ready():
	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = 0.35
	col.shape = forma
	add_child(col)

	_malla = MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.6, 0.6, 0.6)
	_malla.mesh = caja
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.15, 0.1)
	m.emission_enabled = true
	m.emission = Color(1, 0.15, 0.1)
	m.emission_energy_multiplier = 3.0
	_malla.material_override = m
	add_child(_malla)


func _physics_process(delta):
	_malla.rotate_y(3.0 * delta)
	_malla.rotate_x(2.0 * delta)

	var objetivo: Vector3 = gestor.posicion_celda(destino)
	position = position.move_toward(objetivo, velocidad * delta)
	if position.distance_to(objetivo) < 0.01:
		var previa := celda
		celda = destino
		destino = gestor.siguiente_celda(celda, previa)

	for cuerpo in get_overlapping_bodies():
		if cuerpo is RigidBody3D:
			gestor.golpe(self, cuerpo)
