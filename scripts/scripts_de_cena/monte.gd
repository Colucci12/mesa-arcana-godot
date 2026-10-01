extends Control
class_name MonteVisual

const CARTA = preload("res://scenes/carta.tscn")

var _iluminacao: IluminacaoAmbiente

func definir_iluminacao(iluminacao: IluminacaoAmbiente) -> void:
	_iluminacao = iluminacao

func criar_carta(dados_carta: Variant = null) -> Carta:
	var carta := CARTA.instantiate() as Carta
	if dados_carta is Carta_Base:
		carta.setup(dados_carta)
	elif dados_carta is Dictionary:
		carta.setup_dados(dados_carta)
		
	add_child(carta)
	if is_instance_valid(_iluminacao):
		carta.definir_iluminacao(_iluminacao)
	carta.teleportar((size - Carta.SIZE) / 2.0, 0.0)
	
	return carta
