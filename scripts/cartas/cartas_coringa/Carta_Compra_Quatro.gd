extends Carta_Coringa
class_name Carta_Compra_Quatro

func _init() -> void:
	super._init("+4")

func aplicar_efeito(api_efeitos: Efeitos_Api) -> void:
	api_efeitos.acumular_compra(4)
	super.aplicar_efeito(api_efeitos)
