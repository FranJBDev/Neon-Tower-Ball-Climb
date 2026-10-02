class_name Ajustes
extends RefCounted
## Lee y guarda datos en el teléfono (archivo ajustes.cfg).

const ARCHIVO := "user://ajustes.cfg"


static func leer(seccion: String, clave: String, defecto):
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) == OK:
		return cfg.get_value(seccion, clave, defecto)
	return defecto


static func guardar(seccion: String, clave: String, valor):
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO)  # conserva lo que ya estaba guardado (por ejemplo, la música)
	cfg.set_value(seccion, clave, valor)
	cfg.save(ARCHIVO)
