extends Carta_Coringa
class_name Carta_Troca_Mao

func _init() -> void:
	super._init("TROCAMAO")

func aplicar_efeito(api_efeitos: Efeitos_Api) -> void:
	api_efeitos.trocar_maos()
