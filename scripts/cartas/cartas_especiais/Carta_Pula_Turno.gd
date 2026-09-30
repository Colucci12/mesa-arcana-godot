extends Carta_Especial
class_name Carta_Pula_Turno

func _init(p_cor:Cores) -> void:
	super._init("PULA", p_cor)
	
func aplicar_efeito(api_efeitos: Efeitos_Api) -> void:
	api_efeitos.pular_turno()
