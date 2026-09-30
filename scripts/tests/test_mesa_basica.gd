extends Node

var _falhas: Array[String] = []

func _ready() -> void:
	_executar()

func _executar() -> void:
	_testar_validacao_de_inicio()
	_testar_comandos_e_eventos()
	_testar_fim_de_partida()
	if _falhas.is_empty():
		print("PASSOU: testes da lógica básica da mesa")
		get_tree().quit(0)
	else:
		for falha in _falhas:
			push_error(falha)
		get_tree().quit(1)

func _testar_validacao_de_inicio() -> void:
	var mesa := Mesa_Logica.new()
	var api := Mesa_Api.new(mesa)
	mesa.adicionar_jogador(1, "Ana")
	var resultado := api.iniciar_partida()
	_verificar(not resultado["sucesso"], "partida exige dois jogadores")
	_verificar(resultado["erro"] == "jogadores_insuficientes", "erro de início informa jogadores insuficientes")
	_verificar(resultado["eventos"].is_empty(), "início recusado não produz eventos")
	_verificar(mesa.obter_fase() == Mesa_Logica.Fase.AGUARDANDO_JOGADORES, "início recusado não altera fase")

func _testar_comandos_e_eventos() -> void:
	var jogo := _criar_jogo_com_mao_mista()
	_verificar(not jogo.is_empty(), "encontra uma partida com cartas jogáveis e incompatíveis")
	if jogo.is_empty():
		return
	var mesa: Mesa_Logica = jogo["mesa"]
	var api: Mesa_Api = jogo["api"]
	var jogador1: Jogador_Logico = mesa.consultar_jogador_por_id(1)
	var jogador2: Jogador_Logico = mesa.consultar_jogador_por_id(2)
	var inicio: Dictionary = jogo["inicio"]
	var eventos_inicio: Array = inicio["eventos"]

	_verificar(mesa.obter_fase() == Mesa_Logica.Fase.EM_ANDAMENTO, "partida começa na fase correta")
	_verificar(mesa.obter_jogador_atual().get_id() == 1, "primeiro jogador cadastrado inicia")
	_verificar(jogador1.retorna_quantidade_cartas() == 7 and jogador2.retorna_quantidade_cartas() == 7, "cada jogador recebe sete cartas")
	_verificar(mesa.consultar_carta_descarte() is Carta_Numerica, "descarte inicial é numérico")
	_verificar(mesa.obter_quantidade_monte() == 55, "monte inicia com as cartas restantes")
	_verificar(eventos_inicio.size() == 16 and eventos_inicio[0]["tipo"] == "PartidaIniciada", "início produz resumo público e entregas individuais")
	_verificar(eventos_inicio[15]["tipo"] == "DistribuicaoConcluida", "distribuição termina antes de liberar a vez")
	for indice in range(1, 15):
		var evento: Dictionary = eventos_inicio[indice]
		var id_esperado := 1 if indice % 2 == 1 else 2
		_verificar(evento["tipo"] == "CartaRecebida" and evento["publico"]["origem"] == "inicial", "cada entrega inicial gera um evento")
		_verificar(evento["publico"]["jogador_id"] == id_esperado, "entrega inicial alterna jogadores")
		_verificar(not evento["publico"].has("carta"), "carta inicial não aparece nos dados públicos")
		_verificar(evento["privado"].has("carta"), "dono recebe uma carta por evento")
		_verificar(evento["destinatario_id"] == evento["publico"]["jogador_id"], "carta inicial é endereçada ao jogador correto")

	var antes_falha := _capturar_estado(mesa)
	var resultado_fora_da_vez := api.jogar_carta(2, jogo["id_jogavel"])
	_verificar(resultado_fora_da_vez["erro"] == "fora_da_vez", "jogador fora da vez é recusado")
	_verificar(resultado_fora_da_vez["eventos"].is_empty() and _capturar_estado(mesa) == antes_falha, "jogada fora da vez não altera estado")
	var resultado_incompativel := api.jogar_carta(1, jogo["id_incompativel"])
	_verificar(resultado_incompativel["erro"] == "carta_nao_jogavel", "carta incompatível é recusada")
	_verificar(resultado_incompativel["eventos"].is_empty() and _capturar_estado(mesa) == antes_falha, "jogada incompatível não altera estado")
	var resultado_ausente := api.jogar_carta(1, 999999)
	_verificar(resultado_ausente["erro"] == "carta_nao_encontrada", "carta ausente é recusada")
	_verificar(resultado_ausente["eventos"].is_empty() and _capturar_estado(mesa) == antes_falha, "carta ausente não altera estado")

	var resultado_jogada := api.jogar_carta(1, jogo["id_jogavel"])
	_verificar(resultado_jogada["sucesso"], "jogada válida é aceita")
	_verificar(resultado_jogada["eventos"].size() == 2, "jogada válida gera dois eventos")
	_verificar(resultado_jogada["eventos"][0]["tipo"] == "CartaJogada", "carta jogada é publicada primeiro")
	_verificar(resultado_jogada["eventos"][1]["tipo"] == "TurnoAlterado", "mudança de turno vem depois da jogada")
	_verificar(jogador1.retorna_quantidade_cartas() == 6 and mesa.consultar_carta_descarte().get_id() == jogo["id_jogavel"], "jogada atualiza mão e descarte")
	_verificar(mesa.obter_jogador_atual().get_id() == 2, "jogada passa a vez")

	var compra := api.comprar_carta(2)
	_verificar(compra["sucesso"], "compra válida é aceita")
	_verificar(compra["eventos"].size() == 1 and compra["eventos"][0]["tipo"] == "CartaRecebida", "compra publica uma entrega sem mudar o turno")
	_verificar(jogador2.retorna_quantidade_cartas() == 8 and mesa.obter_jogador_atual().get_id() == 2, "compra adiciona carta e mantém a vez")
	_verificar(not compra["eventos"][0]["publico"].has("carta"), "carta comprada não aparece nos dados públicos")
	_verificar(compra["eventos"][0]["privado"].has("carta") and compra["eventos"][0]["destinatario_id"] == 2, "carta comprada só é enviada ao dono")
	while mesa.pode_comprar_carta() and mesa.obter_carta_comprada_jogavel_id() <= 0:
		var outra_compra := api.comprar_carta(2)
		_verificar(outra_compra["sucesso"], "compras continuam até encontrar carta jogável")
		if not outra_compra["sucesso"]:
			return
	var passagem := api.passar_vez(2)
	_verificar(passagem["sucesso"] and passagem["eventos"][0]["tipo"] == "TurnoPassado", "jogador passa após encontrar carta jogável")
	_verificar(mesa.obter_jogador_atual().get_id() == 1, "passagem avança o turno")

	mesa._baralho.limpar()
	var topo_antes_reposicao := mesa.consultar_carta_descarte().get_id()
	var compra_reposta := api.comprar_carta(1)
	_verificar(compra_reposta["sucesso"], "baralho é reposto quando o monte esgota")
	_verificar(mesa.consultar_carta_descarte().get_id() == topo_antes_reposicao, "reposição mantém o descarte inteiro")
	_verificar(mesa.obter_quantidade_monte() == 69, "reposição usa a composição atual da partida")

func _testar_fim_de_partida() -> void:
	var jogo := _criar_jogo_com_mao_mista()
	_verificar(not jogo.is_empty(), "prepara outra partida para testar vitória")
	if jogo.is_empty():
		return
	var mesa: Mesa_Logica = jogo["mesa"]
	var api: Mesa_Api = jogo["api"]
	var jogador := mesa.consultar_jogador_por_id(1)
	var id_carta: int = jogo["id_jogavel"]
	for dados_carta in jogador.serializar_mao():
		if dados_carta["id"] != id_carta:
			jogador.descarta_carta(dados_carta["id"])
	var resultado := api.jogar_carta(1, id_carta)
	_verificar(resultado["sucesso"], "última carta válida encerra a partida")
	_verificar(resultado["eventos"].size() == 2, "vitória emite carta jogada e encerramento")
	_verificar(resultado["eventos"][0]["tipo"] == "CartaJogada" and resultado["eventos"][1]["tipo"] == "PartidaEncerrada", "encerramento vem após a carta jogada")
	_verificar(mesa.obter_fase() == Mesa_Logica.Fase.ENCERRADA, "vitória altera fase da partida")
	var depois_da_vitoria := _capturar_estado(mesa)
	var comando_final := api.comprar_carta(2)
	_verificar(comando_final["erro"] == "partida_nao_em_andamento", "comandos são recusados após a vitória")
	_verificar(comando_final["eventos"].is_empty() and _capturar_estado(mesa) == depois_da_vitoria, "comando após vitória não altera estado")

func _criar_jogo_com_mao_mista() -> Dictionary:
	for valor_seed in range(1, 101):
		seed(valor_seed)
		var mesa := Mesa_Logica.new()
		var api := Mesa_Api.new(mesa)
		mesa.adicionar_jogador(1, "Ana")
		mesa.adicionar_jogador(2, "Bia")
		var inicio := api.iniciar_partida()
		if not inicio["sucesso"]:
			continue
		var id_jogavel := -1
		var id_incompativel := -1
		for dados_carta in mesa.consultar_jogador_por_id(1).serializar_mao():
			if not (mesa.obter_carta_do_jogador(1, dados_carta["id"]) is Carta_Numerica):
				continue
			if api.pode_jogar_carta(1, dados_carta["id"]):
				id_jogavel = dados_carta["id"]
			else:
				id_incompativel = dados_carta["id"]
		if id_jogavel > 0 and id_incompativel > 0:
			return {
				"mesa": mesa,
				"api": api,
				"inicio": inicio,
				"id_jogavel": id_jogavel,
				"id_incompativel": id_incompativel
			}
	return {}

func _capturar_estado(mesa: Mesa_Logica) -> Dictionary:
	var topo := mesa.consultar_carta_descarte()
	var jogador_atual := mesa.obter_jogador_atual()
	var contagens: Array[int] = []
	var maos: Array[Array] = []
	for jogador in mesa.obter_jogadores():
		contagens.append(jogador.retorna_quantidade_cartas())
		maos.append(jogador.serializar_mao())
	return {
		"fase": mesa.obter_fase(),
		"jogador_atual": jogador_atual.get_id() if jogador_atual else -1,
		"topo": topo.para_dados() if topo else {},
		"contagens": contagens,
		"maos": maos,
		"monte": mesa.obter_quantidade_monte()
	}

func _verificar(condicao: bool, descricao: String) -> void:
	if not condicao:
		_falhas.append(descricao)
