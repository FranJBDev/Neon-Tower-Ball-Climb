class_name Anuncios
extends Node
## Banner de AdMob.

signal banner_listo(alto_px: float)

@export var banner_unit_id := "ca-app-pub-3940256099942544/6300978111"  # ID de PRUEBA
var _ad_view: AdView


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Pega aquí tu código de anuncios que ya funciona.
	#if OS.get_name() != "Android" and not OS.has_feature("editor"):
	if OS.get_name() != "Android":
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_ads_listos
	MobileAds.initialize(listener)
	
func _on_ads_listos(_estado):
	call_deferred("_cargar_banner")


func _cargar_banner():
	_ad_view = AdView.new(banner_unit_id, AdSize.BANNER, AdPosition.BOTTOM)
	_ad_view.load_ad(AdRequest.new())
	banner_listo.emit(float(_ad_view.get_height_in_pixels()))
