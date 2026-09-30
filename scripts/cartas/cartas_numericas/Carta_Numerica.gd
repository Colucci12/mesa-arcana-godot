extends Carta_Base
class_name Carta_Numerica

func _init(p_valor: String, p_cor: Cores) -> void:
	if p_cor == Cores.PRETO:
		assert(false, "ERRO: PRETO não é uma cor válida para carta numérica")
	
	if p_valor not in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		assert(false, "ERRO: VALOR não contém um valor válido para carta numérica")
	
	super._init(p_valor, p_cor)
