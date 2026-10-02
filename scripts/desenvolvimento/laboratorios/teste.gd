extends Node

var CENA_CARTA = preload("res://scenes/main/componentes/carta.tscn")

@onready var MONTE = $Control/monte

@onready var MAO_BAIXO = $Control/mao_baixo
@onready var MAO_CIMA = $Control/mao_cima
#@onready var MAO_DIREITA = $Control/mao_direita
#@onready var MAO_ESQUERDA = $Control/mao_esquerda

var baralho:Baralho_Logico

func _ready() -> void:
	baralho = Baralho_Logico.new()
	
	#testando_lista_ligada_circular()
	
	var mesa = Mesa_Logica.new()
	
	mesa.adicionar_jogador(1, "Teste")
	mesa.adicionar_jogador(2, "Colucci")
	mesa.adicionar_jogador(3, "Sheki")
	mesa.remover_jogador("Teste")
	mesa.printar_jogadores()
	
	mesa.distribuir_carta_do_monte("Colucci")
	mesa.distribuir_carta_do_monte("Colucci")
	mesa.printar_mao_jogadores()

#FUNÇÕES RELACIONADAS À CRIAÇÃO DAS CARTAS
func testando_cartas(p_dados_carta: Carta_Base, mao: MaoVisual):
	var carta = CENA_CARTA.instantiate()
	carta.setup(p_dados_carta)	
	
	mao.receber_carta(carta)

#FUNÇÕES RELACIONADAS À LISTA CIRCULAR
func testando_lista_ligada_circular():
	var jogadores = ListaDuplamenteLigadaCircular.new()
	
	print(jogadores.esta_vazia())
	print(jogadores.obter_elementos())
	
	jogadores.adicionar("Colucci")
	jogadores.adicionar("Shark")
	jogadores.adicionar("Sheki")
	
	print(jogadores.esta_vazia())
	print(jogadores.obter_elementos())
	
	jogadores.imprimir_lista()
	print(jogadores.obter_proximo())
	jogadores.imprimir_lista()
	print(jogadores.obter_atual())
	
	jogadores.inverter()
	jogadores.imprimir_lista()
	
	jogadores.remover("Corote")
	jogadores.imprimir_lista()
	
	jogadores.remover("Shark")
	jogadores.imprimir_lista()

# FUNÇÕES RELACIONADAS AO BARALHO
func _on_compra_button_down() -> void:
	testando_cartas(baralho.comprar_carta(), MAO_BAIXO)
	testando_cartas(baralho.comprar_carta(), MAO_CIMA)

func _on_descarta_button_down() -> void:
	if MAO_BAIXO.get_child_count() < 1: return
	MAO_BAIXO.get_child(-1).queue_free()
	
	if MAO_CIMA.get_child_count() < 1: return
	MAO_CIMA.get_child(-1).queue_free()
	
	#MAO_CIMA.descartar()
	#MAO_ESQUERDA.descartar()
	#MAO_DIREITA.descartar()

func _on_button_button_down() -> void:	
	if MAO_BAIXO.get_child_count() < 1: return
	if MAO_CIMA.get_child_count() < 1: return
	
	MAO_BAIXO.get_child(0).reparent(MAO_CIMA)
	MAO_CIMA.get_child(0).reparent(MAO_BAIXO)


func _on_monte_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("M1"):
		var carta_temp = MONTE.criar_carta(baralho.comprar_carta())
		carta_temp.reparent(MAO_BAIXO)
		
	if event.is_action_pressed("M2"):
		var carta_temp = MONTE.criar_carta()
		carta_temp.reparent(MAO_CIMA)
