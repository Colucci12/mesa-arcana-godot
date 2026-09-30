extends Carta_Base
class_name Carta_Coringa

func _init(p_valor: String) -> void:
	super._init(p_valor, Cores.PRETO)

func aplicar_efeito(api_efeitos: Efeitos_Api) -> void:
	api_efeitos.solicitar_escolha_cor()
