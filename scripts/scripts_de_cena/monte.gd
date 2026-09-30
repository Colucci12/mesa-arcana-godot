extends Control
class_name MonteVisual

const CARTA = preload("res://scenes/carta.tscn")

func criar_carta(dados_carta: Variant = null) -> Carta:
	var carta := CARTA.instantiate() as Carta
	if dados_carta is Carta_Base:
		carta.setup(dados_carta)
	elif dados_carta is Dictionary:
		carta.setup_dados(dados_carta)
		
	add_child(carta)
	carta.teleportar(Vector2(20,20), 0.0)
	
	return carta
