class_name Sonidos
extends Node
## Efectos de sonido generados por código (sin archivos de audio).

const FREQ := 22050

var silenciado := false
var _cache := {}
var _reproductores: Array[AudioStreamPlayer] = []


func _ready():
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_reproductores.append(p)

	# nombre: [freq_inicial, freq_final, duración, volumen, onda (0 seno, 1 cuadrada), ruido]
	var defs := {
		"curar": [520.0, 1040.0, 0.30, 0.5, 0, 0.0],
		"recoger": [700.0, 1200.0, 0.20, 0.5, 0, 0.0],
		"act_fantasma": [1200.0, 200.0, 0.55, 0.5, 0, 0.12],
		"act_ahuyentar": [140.0, 60.0, 0.50, 0.6, 1, 0.10],
		"fin_fantasma": [250.0, 900.0, 0.25, 0.4, 0, 0.0],
		"pared": [320.0, 140.0, 0.22, 0.35, 0, 0.35],
		"ovni_aparece": [300.0, 700.0, 0.6, 0.35, 1, 0.0],
		"ovni_carga": [200.0, 1500.0, 0.8, 0.35, 0, 0.05],
		"ovni_disparo": [1800.0, 80.0, 0.4, 0.6, 1, 0.2],
	}
	for nombre in defs:
		var d: Array = defs[nombre]
		_cache[nombre] = _generar(d[0], d[1], d[2], d[3], d[4], d[5])


func reproducir(nombre: String, volumen_db := 0.0):
	if silenciado or not _cache.has(nombre):
		return
	var libre: AudioStreamPlayer = _reproductores[0]
	for p in _reproductores:
		if not p.playing:
			libre = p
			break
	libre.stream = _cache[nombre]
	libre.volume_db = volumen_db
	libre.play()


func _generar(f0: float, f1: float, dur: float, vol: float, onda: int, ruido: float) -> AudioStreamWAV:
	var n := int(FREQ * dur)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	var fase := 0.0
	for i in n:
		var t := float(i) / n
		fase += TAU * lerpf(f0, f1, t) / FREQ
		var s := sin(fase)
		if onda == 1:
			s = signf(s) * 0.6
		s += (randf() * 2.0 - 1.0) * ruido
		var env := minf(t / 0.05, 1.0) * pow(1.0 - t, 2.0)   # ataque corto y caída suave
		datos.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = FREQ
	w.stereo = false
	w.data = datos
	return w
