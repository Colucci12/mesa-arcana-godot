extends Carta_Base
class_name Carta_Especial

func _init(p_valor: String, p_cor: Cores) -> void:
	if p_cor == Cores.PRETO:
		assert(false, "ERRO: PRETO não é uma cor válida para cartas especiais")
	super._init(p_valor, p_cor)
