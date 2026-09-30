extends Carta_Coringa
class_name Carta_Troca_Mao

func _init() -> void:
	super._init("TROCAMAO")

func aplicar_efeito(api_efeitos: Efeitos_Api) -> void:
	api_efeitos.solicitar_troca_de_mao()
	super.aplicar_efeito(api_efeitos)
