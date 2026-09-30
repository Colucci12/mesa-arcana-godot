extends Carta_Especial
class_name Carta_Inverte

func _init(p_cor:Cores) -> void:
	super._init("INVERTE", p_cor)
	
func aplicar_efeito(api_efeitos: Efeitos_Api) -> void:
	api_efeitos.inverter_ordem()
