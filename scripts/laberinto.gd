extends Node3D
## Coordinador del juego: nivel, tiempo, vida y flujo (inicio / fin de partida).

@export var columnas := 25
@export var filas := 35

@export var camara: Camera3D
@export var atajos_porcentaje := 0.12   # 12% de celdas con pared abierta extra

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

@export_group("Enemigos")
@export var max_enemigos := 6
@export var velocidad_enemigo := 1.2
@export var impacto_enemigo := 5.0    # equivale a unos 15 de daño en el nivel 1
@export var cancion: AudioStream  # opcional: tu propia música

@export_group("Power-ups")
@export var powerups_por_nivel := 5
@export var curacion_powerup := 30.0
@export var duracion_fantasma := 5.0
@export var duracion_ahuyentar := 6.0

@export var max_cargas := 3

@export_group("Ovni")
@export var ovni_espera_inicial := 75.0   # segundos en un nivel antes del primer ovni
#@export var ovni_espera_inicial := 6.0   # segundos en un nivel antes del primer ovni
@export var ovni_factor := 0.8            # cada aparición acorta la espera (x0.8)
@export var ovni_espera_min := 20.0

@export_group("Monedas")
@export var monedas_por_nivel := 16

const OFFSET_CAMARA := Vector3(0, 6, 3)
var _powerups: GestorPowerUps
var _fantasma := 0.0

var _musica: Musica
var _minimapa: Minimapa
var _rng := RandomNumberGenerator.new()
var _gen: GeneradorLaberinto

var _efectos: Efectos

var _nivel := 1
var _tiempo := 0.0
var _mejor := -1.0
var _vida := 100.0
var _inv_enemigo := 0.0

var _constructor: ConstructorLaberinto
var _enemigos: GestorEnemigos
var _hud: Hud
var _menu: MenuInicio
var _anuncios: Anuncios
var _mejor_nivel := 1

var _botones: BotonesPoder
var _cargas := {
	GestorPowerUps.Tipo.FANTASMA: 0,
	GestorPowerUps.Tipo.AHUYENTAR: 0,
}

var _sonidos: Sonidos
var _consulta: PhysicsShapeQueryParameters3D
var _dentro_pared := false
var _ultimo_pared := 0

var _ovni: Ovni
var _t_ovni := 0.0
var _apariciones := 0

var _monedas: GestorMonedas
var _tienda: Tienda
var _monedas_partida := 0
var _base := {}

func _ready():
	_base = {
		"vida": vida_max,
		"fantasma": duracion_fantasma,
		"ahuyentar": duracion_ahuyentar,
		"cargas": max_cargas,
	}
	
	if bola == null:
		for hijo in get_children():
			if hijo is RigidBody3D:
				bola = hijo as RigidBody3D
				
	if bola:
		_texturizar_bola()
		
	_mejor_nivel = Ajustes.leer("juego", "mejor_nivel", 1)
	_mejor = Ajustes.leer("juego", "mejor_tiempo", -1.0)
	_vida = vida_max

	_anuncios = Anuncios.new()
	add_child(_anuncios)
	
	_musica = Musica.new()
	_musica.cancion = cancion
	add_child(_musica)
	
	_sonidos = Sonidos.new()
	add_child(_sonidos)
	_sonidos.silenciado = _musica.silenciada	
	_sonidos.process_mode = Node.PROCESS_MODE_ALWAYS   # para que suene en el menú y la tienda

	var forma := SphereShape3D.new()
	forma.radius = 0.45
	_consulta = PhysicsShapeQueryParameters3D.new()
	_consulta.shape = forma
	_consulta.collision_mask = 2

	_constructor = ConstructorLaberinto.new()
	add_child(_constructor)
	_constructor.meta_alcanzada.connect(_on_meta_alcanzada)

	_enemigos = GestorEnemigos.new()
	add_child(_enemigos)
	_enemigos.enemigo_toco.connect(_on_enemigo_toco)
	
	_powerups = GestorPowerUps.new()
	add_child(_powerups)
	_powerups.recogido.connect(_on_powerup, CONNECT_DEFERRED)
	
	_monedas = GestorMonedas.new()
	add_child(_monedas)
	_monedas.recogida.connect(_on_moneda, CONNECT_DEFERRED)
	
	if bola:
		bola.set_collision_mask_value(2, true)  # la bola choca con las paredes (capa 2)

	_hud = Hud.new()
	add_child(_hud)
	var capa := CanvasLayer.new()
	add_child(capa)
	_minimapa = Minimapa.new()
	capa.add_child(_minimapa)
	
	var capa_botones := CanvasLayer.new()
	capa_botones.layer = 50   # por encima del HUD y del menú
	add_child(capa_botones)
	_botones = BotonesPoder.new()
	capa_botones.add_child(_botones)
	_botones.presionado.connect(_on_boton_poder)
	
	_tienda = Tienda.new()
	add_child(_tienda)
	_tienda.fuente_margen = _botones._alto_banner
	_tienda.comprada.connect(func(): _sonidos.reproducir("curar"))
	
	_anuncios.banner_listo.connect(func(px): _botones.alto_banner_px = px)
	
	_hud.boton_musica_presionado.connect(_on_boton_musica)
	_hud.set_musica_silenciada(_musica.silenciada)
	
	_efectos = Efectos.new()
	add_child(_efectos)

	_menu = MenuInicio.new()
	add_child(_menu)
	_menu.jugar_presionado.connect(_iniciar_partida)

	if camara == null:
		camara = get_viewport().get_camera_3d()
	camara.top_level = true   # ignora el movimiento o giro de su nodo padre
	camara.rotation_degrees = Vector3(-rad_to_deg(atan2(OFFSET_CAMARA.y, OFFSET_CAMARA.z)), 0, 0)

	_configurar_niebla()
	generar()
	_colocar_bola()
	
	var texto_inicio := "Inclina el celular\npara llegar a la meta"
	if _mejor_nivel > 1:
		texto_inicio += "\nRécord: nivel %d" % _mejor_nivel
	_menu.mostrar("NEON TOWER", texto_inicio, "JUGAR")
	#_menu.mostrar("NEON TOWER", "Inclina el celular\npara llegar a la meta", "JUGAR")
	_tienda.mostrar_boton(true)
	_hud.set_monedas(_tienda.monedas)
	get_tree().paused = true

func _process(delta):
	if bola == null or camara == null:
		return

	# Temporizador del fantasma
	if _fantasma > 0.0:
		_fantasma -= delta
		if _fantasma <= 0.0:
			_terminar_fantasma()
		else:
			_revisar_atravesar()
	if _ovni == null:
		_t_ovni -= delta
		if _t_ovni <= 0.0:
			_lanzar_ovni()

	_botones.actualizar(GestorPowerUps.Tipo.FANTASMA,
		_cargas[GestorPowerUps.Tipo.FANTASMA], maxf(_fantasma, 0.0))
	_botones.actualizar(GestorPowerUps.Tipo.AHUYENTAR,
		_cargas[GestorPowerUps.Tipo.AHUYENTAR], _enemigos.huida_restante())

	if bola.global_position.y < -5.0:
		_colocar_bola()
	var objetivo = bola.global_position + OFFSET_CAMARA
	camara.global_position = camara.global_position.lerp(objetivo, 5.0 * delta)
	_tiempo += delta
	_inv_enemigo = maxf(0.0, _inv_enemigo - delta)
	_hud.actualizar(_nivel, _tiempo, _mejor, _vida, vida_max)
	var dist := _enemigos.distancia_minima(bola.global_position)
	_musica.set_tension(inverse_lerp(6.0, 1.5, dist))
	
# ---------- Laberinto ----------
func generar():
	if semilla == 0:
		_rng.randomize()
	else:
		_rng.seed = semilla

	_gen = GeneradorLaberinto.new(columnas, filas, tam_celda)
	_gen.generar(_rng)
	_gen.agregar_atajos(int(columnas * filas * atajos_porcentaje), _rng)

	_constructor.grosor = grosor
	_constructor.alto = alto
	_constructor.material_pared = material_pared
	_constructor.construir(_gen)

	_enemigos.max_enemigos = max_enemigos
	_enemigos.velocidad_base = velocidad_enemigo	
	_enemigos.objetivo = bola	
	_enemigos.crear(_gen, _nivel, _rng)
	_minimapa.configurar(_gen, self, bola)
	_powerups.crear(_gen, _rng, powerups_por_nivel)
	
	_monedas.objetivo = bola
	_monedas.crear(_gen, _rng, monedas_por_nivel)
	
	if is_instance_valid(_ovni):
		_ovni.queue_free()
	_ovni = null
	_programar_ovni()

func _colocar_bola():
	if bola:
		bola.linear_velocity = Vector3.ZERO
		bola.angular_velocity = Vector3.ZERO
		var p := _gen.centro_celda(_gen.celda_inicio.x, _gen.celda_inicio.y)
		bola.global_position = to_global(p + Vector3(0, 0.6, 0))
		_fantasma = 0.0
		_dentro_pared = false
		bola.set_collision_mask_value(2, true)
		_transparencia_bola(0.0)
		if camara:
			camara.global_position = bola.global_position + OFFSET_CAMARA

# ---------- Flujo del juego ----------

func _iniciar_partida():
	_aplicar_mejoras()
	_monedas_partida = 0
	_tienda.mostrar_boton(false)
	_hud.set_monedas(_tienda.monedas)
	_apariciones = 0
	_cargas[GestorPowerUps.Tipo.FANTASMA] = 0
	_cargas[GestorPowerUps.Tipo.AHUYENTAR] = 0
	_botones.visible = true
	_nivel = 1
	_tiempo = 0.0
	_vida = vida_max
	generar()
	_colocar_bola()
	_menu.ocultar()
	get_tree().paused = false

func _on_meta_alcanzada(cuerpo: Node3D):
	if cuerpo is RigidBody3D:
		call_deferred("_nuevo_nivel")


func _nuevo_nivel():
	var bono := 5 + _nivel * 2 + int(clampf((60.0 - _tiempo) / 10.0, 0.0, 5.0))
	_tienda.agregar_monedas(bono)
	_monedas_partida += bono
	_tienda.guardar()
	_hud.set_monedas(_tienda.monedas)
	_hud.aviso("+%d monedas" % bono)
	
	if _mejor < 0.0 or _tiempo < _mejor:
		_mejor = _tiempo
	Ajustes.guardar("juego", "mejor_tiempo", _mejor)
	_nivel += 1
	_tiempo = 0.0
	_vida = minf(vida_max, _vida + vida_max * curacion_por_nivel)
	if semilla != 0:
		semilla += 1
	generar()
	_colocar_bola()

func golpe_pared(impacto: float, pos: Vector3):  # la llama la esfera al chocar con una pared
	if _fantasma > 0.0:
		return   # en modo fantasma no hay partículas ni daño por paredes
	_efectos.golpe_pared(pos, clampf(impacto / 6.0, 0.0, 1.0))
	recibir_golpe(impacto)

func recibir_golpe(impacto: float):  # lo llama la esfera al chocar con una pared
	if get_tree().paused or _vida <= 0.0:
		return
	var mult := 1.0 + escalado_dano * (_nivel - 1)
	_vida = maxf(0.0, _vida - impacto * dano_por_impacto * mult)
	if _vida <= 0.0:
		call_deferred("_fin_del_juego")


func _on_enemigo_toco(enemigo: Node3D, cuerpo: RigidBody3D):
	if _inv_enemigo > 0.0 or get_tree().paused:
		return
	_inv_enemigo = 1.0
	
	_inv_enemigo = 1.0
	#_efectos.golpe_enemigo((enemigo.global_position + cuerpo.global_position) / 2.0)
	_efectos.golpe_enemigo((enemigo.global_position + cuerpo.global_position) / 2.0)
	
	var dir := cuerpo.global_position - enemigo.global_position
	dir.y = 0.0
	cuerpo.apply_central_impulse(dir.normalized() * 4.0)
	Input.vibrate_handheld(120)
	recibir_golpe(impacto_enemigo)


func _fin_del_juego():
	var detalle := "Llegaste al nivel %d" % _nivel
	detalle += "\nMonedas ganadas: %d" % _monedas_partida
	_tienda.guardar()
	_tienda.mostrar_boton(true)
	_botones.visible = false
	if _mejor >= 0.0:
		detalle += "\nMejor tiempo: %.1f s" % _mejor
			
	_musica.set_tension(0.0)	
	if _nivel > _mejor_nivel:
		_mejor_nivel = _nivel
		Ajustes.guardar("juego", "mejor_nivel", _mejor_nivel)
	detalle += "\nRécord: nivel %d" % _mejor_nivel
	_menu.mostrar("FIN DEL JUEGO", detalle, "REINTENTAR")
	get_tree().paused = true

func _on_boton_musica():
	var silenciada: bool = _musica.alternar_silencio()
	_sonidos.silenciado = silenciada
	_hud.set_musica_silenciada(silenciada)

func _configurar_niebla():
	var we := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we == null:
		we = WorldEnvironment.new()
		we.environment = Environment.new()
		add_child(we)
	var env := we.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color.BLACK
	env.fog_depth_begin = 7.5
	env.fog_depth_end = 14.0

func _on_powerup(tipo: int):
	if tipo == GestorPowerUps.Tipo.CURAR:
		_vida = minf(vida_max, _vida + curacion_powerup)
		_sonidos.reproducir("curar")
	else:
		_cargas[tipo] = mini(_cargas[tipo] + 1, max_cargas)
		_sonidos.reproducir("recoger")
		
func _on_boton_poder(tipo: int):
	if _cargas[tipo] <= 0 or get_tree().paused:
		return
	var color: Color = GestorPowerUps.COLORES[tipo]
	match tipo:
		GestorPowerUps.Tipo.FANTASMA:
			if _fantasma > 0.0:
				return
			_activar_fantasma(duracion_fantasma)
			_sonidos.reproducir("act_fantasma")
			_powerups.explosion(bola.global_position, color, 40)
		GestorPowerUps.Tipo.AHUYENTAR:
			if _enemigos.huida_restante() > 0.0:
				return
			_enemigos.ahuyentar(bola, duracion_ahuyentar)
			_sonidos.reproducir("act_ahuyentar")
			_powerups.onda(bola.global_position, color, 8.0)
	_cargas[tipo] -= 1
	
func _activar_fantasma(segundos: float):
	_fantasma = segundos
	_dentro_pared = false
	bola.set_collision_mask_value(2, false)
	_transparencia_bola(0.6)


func _terminar_fantasma():
	# Si la bola sigue dentro de una pared, espera a que salga
	if _bola_dentro_de_pared():
		_fantasma = 0.3
		return
	bola.set_collision_mask_value(2, true)
	_transparencia_bola(0.0)
	_dentro_pared = false
	_sonidos.reproducir("fin_fantasma")

func _transparencia_bola(valor: float):
	for h in bola.get_children():
		if h is MeshInstance3D:
			h.transparency = valor

func _bola_dentro_de_pared() -> bool:
	_consulta.transform = Transform3D(Basis.IDENTITY, bola.global_position)
	return not get_world_3d().direct_space_state.intersect_shape(_consulta, 1).is_empty()


func _revisar_atravesar():
	var dentro := _bola_dentro_de_pared()
	if dentro and not _dentro_pared and Time.get_ticks_msec() - _ultimo_pared > 250:
		_ultimo_pared = Time.get_ticks_msec()
		_sonidos.reproducir("pared")
	_dentro_pared = dentro

@warning_ignore("integer_division")
func _texturizar_bola():
	const ANCHO := 256
	const ALTO := 128
	const CELDA_X := 32   # 8 columnas
	const CELDA_Y := 32   # 4 filas

	var img := Image.create_empty(ANCHO, ALTO, true, Image.FORMAT_RGBA8)
	var base := Color(0.02, 0.08, 0.10)
	var celda := Color(0.0, 0.129, 0.6, 1.0)
	var linea := Color(0.7, 1.0, 1.0)
	for y in ALTO:
		for x in ANCHO:
			var col := base
			if (x / CELDA_X + y / CELDA_Y) % 2 == 0:
				col = celda
			if x % CELDA_X < 3 or y % CELDA_Y < 3:
				col = linea
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission_energy_multiplier = 1.2

	for h in bola.find_children("*", "MeshInstance3D", true, false):
		(h as MeshInstance3D).material_override = mat

func _programar_ovni():
	var base := maxf(ovni_espera_min, ovni_espera_inicial * pow(ovni_factor, _apariciones))
	_t_ovni = base * randf_range(0.75, 1.25)


func _lanzar_ovni():
	_apariciones += 1
	_ovni = Ovni.new()
	_ovni.camara = camara
	_ovni.bola = bola
	_ovni.cargando.connect(func(): _sonidos.reproducir("ovni_carga"))
	_ovni.disparo.connect(_on_ovni_disparo)
	_ovni.terminado.connect(_on_ovni_terminado)
	add_child(_ovni)
	_sonidos.reproducir("ovni_aparece")


func _on_ovni_disparo():
	if _vida <= 0.0:
		return
	_vida = minf(_vida, vida_max * 0.2)   # nunca te mata, y no te cura si ya tenías menos
	_efectos.golpe_enemigo(bola.global_position)
	Input.vibrate_handheld(300)
	_sonidos.reproducir("ovni_disparo")

func _on_ovni_terminado():
	_ovni = null
	_programar_ovni()
	
func _on_moneda(pos: Vector3):
	_tienda.agregar_monedas(1)
	_monedas_partida += 1
	_hud.set_monedas(_tienda.monedas)
	_powerups.explosion(pos, Color(1.0, 0.72, 0.08), 8)
	_sonidos.reproducir("moneda", -4.0)


func _aplicar_mejoras():
	vida_max = _base["vida"] * (1.0 + 0.10 * _tienda.nivel("vida"))
	duracion_fantasma = _base["fantasma"] + 1.0 * _tienda.nivel("fantasma")
	duracion_ahuyentar = _base["ahuyentar"] + 1.0 * _tienda.nivel("ahuyentar")
	max_cargas = _base["cargas"] + _tienda.nivel("cargas")
	_monedas.iman_radio = 1.5 * _tienda.nivel("iman")
