extends Carta_Especial
class_name Carta_Compra_Dois

func _init(p_cor:Cores) -> void:
	super._init("+2", p_cor)
	
func aplicar_efeito(api_efeitos: Efeitos_Api) -> void:
	api_efeitos.acumular_compra(2)
