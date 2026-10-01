extends RigidBody3D

@export var fuerza := 25.0
@export var zona_muerta := 0.08
@export var velocidad_max := 6.0
@export var umbral_impacto := 1.0  # golpes más suaves que esto no suenan
@export var escala_impacto := 6.0  # velocidad que cuenta como golpe "fuerte"

var inicio: Vector3
var _vel_prev := Vector3.ZERO
var _cooldown := 0.0
var _sonido := AudioStreamPlayer.new()


func _ready():
	inicio = global_position
	contact_monitor = true
	max_contacts_reported = 4
	_sonido.stream = _crear_sonido_choque()
	add_child(_sonido)


func _physics_process(_delta):
	var entrada := Vector2.ZERO
	var acel := Input.get_accelerometer()
	if acel != Vector3.ZERO:
		entrada = Vector2(acel.x, -acel.y) / 9.8
	else:
		entrada = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	entrada = entrada.limit_length(1.0)
	if entrada.length() < zona_muerta:
		entrada = Vector2.ZERO

	apply_central_force(Vector3(entrada.x, 0, entrada.y) * fuerza)

	if linear_velocity.length() > velocidad_max:
		linear_velocity = linear_velocity.normalized() * velocidad_max

	if global_position.y < -3.0:
		global_position = inicio
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


func _integrate_forces(state: PhysicsDirectBodyState3D):
	_cooldown = maxf(0.0, _cooldown - state.step)
	for i in state.get_contact_count():
		var n := state.get_contact_local_normal(i)
		if absf(n.y) > 0.5:
			continue  # es el piso, no una pared
		var impacto := -_vel_prev.dot(n)
		if impacto > umbral_impacto and _cooldown <= 0.0:
			_cooldown = 0.12
			_golpe(impacto)
	_vel_prev = state.linear_velocity


func _golpe(impacto: float):
	var f := clampf(impacto / escala_impacto, 0.2, 1.0)
	_sonido.volume_db = linear_to_db(lerpf(0.6, 1.0, f))
	_sonido.pitch_scale = randf_range(0.9, 1.1)
	_sonido.play()
	Input.vibrate_handheld(int(lerpf(20.0, 60.0, f)), f)


func _crear_sonido_choque() -> AudioStreamWAV:
	var tasa := 22050
	var n := int(tasa * 0.09)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i in n:
		var t := float(i) / tasa
		var env := 1.0 - float(i) / n
		env = env * env  # cae rápido: suena más a golpe
		var v := (sin(TAU * 450.0 * t) * 0.7 + randf_range(-1.0, 1.0) * 0.3) * env
		datos.encode_s16(i * 2, int(v * 32767 * 0.95))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = tasa
	s.stereo = false
	s.data = datos
	return s
