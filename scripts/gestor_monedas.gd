class_name GestorMonedas
extends Node3D
## Monedas repartidas por el laberinto, con imán opcional.

signal recogida(pos: Vector3)

const COLOR := Color(1.0, 0.72, 0.08)

var objetivo: Node3D        # la bola
var iman_radio := 0.0       # 0 = sin imán

var _mat: StandardMaterial3D


func crear(gen: GeneradorLaberinto, rng: RandomNumberGenerator, cantidad: int):
	limpiar()
	var libres: Array[Vector2i] = []
	for c in gen.columnas:
		for r in gen.filas:
			var dist := absi(c - gen.celda_inicio.x) + absi(r - gen.celda_inicio.y)
			if dist >= 3 and Vector2i(c, r) != gen.celda_meta:
				libres.append(Vector2i(c, r))
	for i in cantidad:
		if libres.is_empty():
			break
		var celda: Vector2i = libres.pop_at(rng.randi() % libres.size())
		_crear_moneda(gen.centro_celda(celda.x, celda.y) + Vector3(0, 1.1, 0))


func limpiar():
	for hijo in get_children():
		if hijo is Area3D:
			hijo.queue_free()


func _process(delta):
	for h in get_children():
		if not (h is Area3D) or h.is_queued_for_deletion():
			continue
		h.rotate_y(delta * 3.0)
		if objetivo and iman_radio > 0.0:
			var hacia: Vector3 = objetivo.global_position - h.global_position
			hacia.y = 0.0
			var d := hacia.length()
			if d < iman_radio and d > 0.01:
				h.global_position += hacia.normalized() * minf(7.0 * delta, d)


func _crear_moneda(pos: Vector3):
	var area := Area3D.new()
	area.position = pos

	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = 0.6
	col.shape = forma
	area.add_child(col)

	var disco := CylinderMesh.new()
	disco.top_radius = 0.3
	disco.bottom_radius = 0.3
	disco.height = 0.06
	var malla := MeshInstance3D.new()
	malla.mesh = disco
	malla.rotation_degrees.x = 90     # de canto, como una moneda en pie
	malla.material_override = _material()
	area.add_child(malla)

	area.body_entered.connect(_on_toco.bind(area))
	add_child(area)


func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = COLOR
		_mat.emission_enabled = true
		_mat.emission = COLOR
		_mat.emission_energy_multiplier = 1.3
		_mat.disable_fog = true
	return _mat


func _on_toco(cuerpo: Node3D, area: Area3D):
	if cuerpo is RigidBody3D and not area.is_queued_for_deletion():
		area.queue_free()
		recogida.emit(area.global_position)
