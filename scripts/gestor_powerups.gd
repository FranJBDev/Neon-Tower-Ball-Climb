class_name GestorPowerUps
extends Node3D
## Crea los power-ups de cada nivel y avisa cuando la bola recoge uno.

signal recogido(tipo: int)

enum Tipo { CURAR, FANTASMA, AHUYENTAR }

const COLORES := {
	Tipo.CURAR: Color(0.1, 1.0, 0.25),      # verde
	Tipo.FANTASMA: Color(0.15, 0.4, 1.0),   # azul
	Tipo.AHUYENTAR: Color(1.0, 0.8, 0.0),   # amarillo
}


func _process(delta):
	var t := Time.get_ticks_msec() / 1000.0
	for h in get_children():
		if h is Area3D and not h.is_queued_for_deletion():
			h.rotate_y(delta * 1.8)
			h.position.y = float(h.get_meta("y0")) + sin(t * 2.5 + h.position.x) * 0.1


func crear(gen: GeneradorLaberinto, rng: RandomNumberGenerator, cantidad: int):
	limpiar()
	var libres: Array[Vector2i] = []
	for c in gen.columnas:
		for r in gen.filas:
			var dist := absi(c - gen.celda_inicio.x) + absi(r - gen.celda_inicio.y)
			if dist >= 5 and Vector2i(c, r) != gen.celda_meta:
				libres.append(Vector2i(c, r))

	for i in cantidad:
		if libres.is_empty():
			break
		var celda: Vector2i = libres.pop_at(rng.randi() % libres.size())
		# 50% curar, 30% ahuyentar, 20% fantasma
		var t := rng.randf()
		var tipo: int = Tipo.CURAR if t < 0.5 else (Tipo.AHUYENTAR if t < 0.8 else Tipo.FANTASMA)
		_crear_item(gen.centro_celda(celda.x, celda.y) + Vector3(0, 0.6, 0), tipo)

func limpiar():
	for hijo in get_children():
		if hijo is Area3D:
			hijo.queue_free()


func _on_toco(cuerpo: Node3D, area: Area3D, tipo: int):
	if cuerpo is RigidBody3D and not area.is_queued_for_deletion():
		explosion(area.global_position, COLORES[tipo], 28)
		onda(area.global_position, COLORES[tipo], 2.5)
		area.queue_free()
		recogido.emit(tipo)


## Ráfaga de chispas de colores.
func explosion(pos: Vector3, color: Color, cantidad := 24):
	var p := CPUParticles3D.new()
	p.amount = cantidad
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -4, 0)
	var esfera := SphereMesh.new()
	esfera.radius = 0.07
	esfera.height = 0.14
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	esfera.material = m
	p.mesh = esfera
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


## Anillo que se expande y se desvanece.
func onda(pos: Vector3, color: Color, radio: float):
	var anillo := TorusMesh.new()
	anillo.inner_radius = 0.9
	anillo.outer_radius = 1.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = anillo
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.3, 1.0, 0.3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radio, 1.0, radio), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(mi.queue_free)

func _crear_item(pos: Vector3, tipo: int):
	var area := Area3D.new()
	area.position = pos
	area.set_meta("y0", pos.y)

	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = 0.5
	col.shape = forma
	area.add_child(col)

	area.add_child(_crear_malla(tipo))
	area.body_entered.connect(_on_toco.bind(area, tipo))
	add_child(area)


func _crear_malla(tipo: int) -> Node3D:
	var raiz := Node3D.new()
	var mat := _material(COLORES[tipo])
	match tipo:
		Tipo.CURAR:
			for tam in [Vector3(0.5, 0.16, 0.16), Vector3(0.16, 0.5, 0.16)]:
				var caja := BoxMesh.new()
				caja.size = tam
				raiz.add_child(_instancia(caja, mat))
		Tipo.FANTASMA:
			var anillo := TorusMesh.new()
			anillo.inner_radius = 0.17
			anillo.outer_radius = 0.3
			var mi := _instancia(anillo, mat)
			mi.rotation_degrees.x = 90
			raiz.add_child(mi)
		Tipo.AHUYENTAR:
			var prisma := PrismMesh.new()
			prisma.size = Vector3(0.5, 0.5, 0.16)
			raiz.add_child(_instancia(prisma, mat))
	return raiz


func _instancia(malla: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	return mi


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.5
	return m
