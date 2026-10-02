class_name Musica
extends AudioStreamPlayer
## Música de fondo en bucle. Usa tu archivo si lo asignas; si no, genera una melodía.

const ARCHIVO_AJUSTES := "user://ajustes.cfg"

var silenciada := false
var cancion: AudioStream  # la asigna laberinto.gd
var volumen := -12.0      # bajo, para que se oigan los golpes
var velocidad_max := 1.25  # velocidad cuando el enemigo está muy cerca
var _objetivo := 1.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue sonando en la pantalla de inicio
	stream = cancion if cancion else _crear_cancion()
	volume_db = volumen
	finished.connect(play)  # por si tu archivo no tiene el bucle activado
	
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_AJUSTES) == OK:
		silenciada = cfg.get_value("audio", "musica_silenciada", false)
	play()
	stream_paused = silenciada


func _crear_cancion() -> AudioStreamWAV:
	var tasa := 11025
	var paso := 0.25  # una corchea (120 BPM)
	var pasos := 32   # 4 compases de 8 corcheas = 8 segundos
	var n := int(tasa * paso * pasos)
	var datos := PackedByteArray()
	datos.resize(n * 2)

	# Progresión: La menor - Fa - Do - Sol
	var bajos := [220.0, 174.5, 131.0, 196.0]
	var acordes := [
		[440.0, 523.25, 659.25],
		[349.23, 440.0, 523.25],
		[523.25, 659.25, 783.99],
		[392.0, 493.88, 587.33],
	]
	var patron := [0, 1, 2, 1, 2, 1, 2, 1]

	for i in n:
		var t := float(i) / tasa
		var p := int(t / paso)
		var compas := int(p / 8.0)
		var tn := t - p * paso         # tiempo dentro de la corchea
		var tb := fmod(t, paso * 2.0)  # tiempo dentro del pulso

		# Arpegio
		var fa: float = acordes[compas][patron[p % 8]]
		var wa := TAU * fa * tn
		var arp := (sin(wa) + 0.4 * sin(2.0 * wa) + 0.2 * sin(3.0 * wa)) * exp(-tn * 9.0)

		# Bajo
		var wb := TAU * float(bajos[compas]) * t
		var bajo := (sin(wb) + 0.3 * sin(2.0 * wb)) * (0.35 + 0.65 * exp(-tb * 4.0))

		# Bombo en cada pulso
		var bombo := sin(TAU * (50.0 * tb + 3.333 * (1.0 - exp(-30.0 * tb)))) * exp(-tb * 18.0)

		# Platillo en las corcheas de contratiempo
		var plat := 0.0
		if p % 2 == 1:
			plat = randf_range(-1.0, 1.0) * exp(-tn * 60.0)

		var v := arp * 0.22 + bajo * 0.25 + bombo * 0.45 + plat * 0.12
		datos.encode_s16(i * 2, int(tanh(v) * 32767 * 0.9))

	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = tasa
	s.stereo = false
	s.data = datos
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s

# tension va de 0.0 (sin peligro) a 1.0 (enemigo encima)
func set_tension(t: float):
	_objetivo = lerpf(1.0, velocidad_max, clampf(t, 0.0, 1.0))


func _process(delta):
	var ritmo := 1.0 if _objetivo > pitch_scale else 0.4  # sube rápido, baja despacio
	pitch_scale = move_toward(pitch_scale, _objetivo, ritmo * delta)

# Silencia o reactiva la música. Devuelve el nuevo estado.
func alternar_silencio() -> bool:
	silenciada = not silenciada
	stream_paused = silenciada
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO_AJUSTES)  # conserva otros ajustes si ya existen
	cfg.set_value("audio", "musica_silenciada", silenciada)
	cfg.save(ARCHIVO_AJUSTES)
	return silenciada
