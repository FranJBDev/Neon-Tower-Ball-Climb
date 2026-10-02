class_name ConstructorLaberinto
extends Node3D
## Crea las paredes y la meta (nodos 3D) a partir de los datos del generador.

signal meta_alcanzada(cuerpo: Node3D)

var grosor := 0.3
var alto := 1.0
var material_pared: Material

var _mat: Material
var _mat_meta: Material
var _mat_haz: Material


func construir(gen: GeneradorLaberinto):
	limpiar()
	var t := gen.tam_celda
	var y := alto / 2.0

	for c in gen.columnas - 1:
		for r in gen.filas:
			if gen.pared_der[c][r]:
				_crear_pared(
					gen.centro_celda(c, r) + Vector3(t / 2.0, y, 0),
					Vector3(grosor, alto, t + grosor))

	for c in gen.columnas:
		for r in gen.filas - 1:
			if gen.pared_abajo[c][r]:
				_crear_pared(
					gen.centro_celda(c, r) + Vector3(0, y, t / 2.0),
					Vector3(t + grosor, alto, grosor))

	_crear_meta(gen.centro_celda(gen.celda_meta.x, gen.celda_meta.y))


func limpiar():
	for hijo in get_children():
		hijo.queue_free()


func _crear_pared(pos: Vector3, tam: Vector3):
	var cuerpo := StaticBody3D.new()
	cuerpo.position = pos
	cuerpo.collision_layer = 2

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

	add_child(cuerpo)


func _crear_meta(pos: Vector3):
	var area := Area3D.new()
	area.position = pos

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

		# Haz de luz alto, visible a través de la niebla
	var haz := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.2
	cil.bottom_radius = 0.5
	cil.height = 1.0
	haz.mesh = cil
	haz.position.y = 2.0
	haz.material_override = _obtener_material_haz()
	area.add_child(haz)

	area.body_entered.connect(_on_meta_toco)
	add_child(area)


func _on_meta_toco(cuerpo: Node3D):
	meta_alcanzada.emit(cuerpo)


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
		m.disable_fog = true
		_mat_meta = m
	return _mat_meta

func _obtener_material_haz() -> Material:
	if _mat_haz == null:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 0, 0.8, 0.35)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.disable_fog = true
		_mat_haz = m
	return _mat_haz
