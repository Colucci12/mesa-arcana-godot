extends Resource
class_name Mesa_Logica

enum Fase { AGUARDANDO_JOGADORES, EM_ANDAMENTO, ENCERRADA }

var _baralho: Baralho_Logico
var _descarte: Descarte_Logico
var _lista_jogadores: ListaDuplamenteLigadaCircular
var _fase: Fase = Fase.AGUARDANDO_JOGADORES
var _compra_acumulada: int = 0
var _comprou_neste_turno: bool = false
var _carta_comprada_jogavel_id: int = -1
var _jogador_escolhendo_cor_id: int = -1
var _carta_aguardando_cor_id: int = -1
var _jogador_escolhendo_alvo_id: int = -1

func _init() -> void:
	_baralho = Baralho_Logico.new()
	_descarte = Descarte_Logico.new()
	_lista_jogadores = ListaDuplamenteLigadaCircular.new()

func consultar_jogador(nome: String) -> Jogador_Logico:
	for jogador in _lista_jogadores.obter_elementos():
		if jogador.get_nome() == nome:
			return jogador
	return null

func consultar_jogador_por_id(id_jogador: int) -> Jogador_Logico:
	for jogador in _lista_jogadores.obter_elementos():
		if jogador.get_id() == id_jogador:
			return jogador
	return null

func obter_jogadores() -> Array[Jogador_Logico]:
	var jogadores: Array[Jogador_Logico] = []
	for jogador in _lista_jogadores.obter_elementos():
		jogadores.append(jogador)
	return jogadores

func adicionar_jogador(id: int, nome: String) -> bool:
	if _fase == Fase.EM_ANDAMENTO or id <= 0 or nome.strip_edges().is_empty():
		return false
	if consultar_jogador_por_id(id):
		return false
	_lista_jogadores.adicionar(Jogador_Logico.new(id, nome.strip_edges()))
	return true

func remover_jogador(nome: String) -> void:
	if _fase == Fase.EM_ANDAMENTO:
		return
	var jogador := consultar_jogador(nome)
	if jogador:
		_lista_jogadores.remover(jogador)

func printar_jogadores() -> void:
	_lista_jogadores.imprimir_lista()

func printar_mao_jogadores() -> void:
	for jogador in _lista_jogadores.obter_elementos():
		jogador.printar_mao_cartas()

func obter_fase() -> Fase:
	return _fase

func obter_jogador_atual() -> Jogador_Logico:
	return _lista_jogadores.obter_atual()

func avancar_turno() -> Jogador_Logico:
	_limpar_compra_no_turno()
	return _lista_jogadores.obter_proximo()

func iniciar_estado_partida() -> void:
	_fase = Fase.EM_ANDAMENTO
	_limpar_compra_no_turno()
	_lista_jogadores.reiniciar_atual()

func encerrar_partida() -> void:
	_fase = Fase.ENCERRADA
	_limpar_compra_no_turno()

func preparar_nova_partida() -> void:
	for jogador in _lista_jogadores.obter_elementos():
		jogador.limpar_mao()
	_baralho.criar_baralho()
	_descarte.limpar()
	_compra_acumulada = 0
	_jogador_escolhendo_cor_id = -1
	_carta_aguardando_cor_id = -1
	_jogador_escolhendo_alvo_id = -1
	_limpar_compra_no_turno()
	_fase = Fase.AGUARDANDO_JOGADORES
	_lista_jogadores.reiniciar_atual()

func descartar_carta_inicial() -> Carta_Base:
	var carta := _baralho.retirar_carta_numerica()
	if carta:
		_descarte.adicionar_carta(carta)
	return carta

func consultar_carta_descarte() -> Carta_Base:
	return _descarte.consultar_carta()

func solicitar_escolha_cor() -> Jogador_Logico:
	var jogador := obter_jogador_atual()
	if jogador:
		_jogador_escolhendo_cor_id = jogador.get_id()
		_carta_aguardando_cor_id = _descarte.consultar_carta().get_id()
	return jogador

func obter_jogador_escolhendo_cor_id() -> int:
	return _jogador_escolhendo_cor_id

func solicitar_escolha_alvo() -> void:
	_jogador_escolhendo_alvo_id = obter_jogador_atual().get_id()

func obter_jogador_escolhendo_alvo_id() -> int:
	return _jogador_escolhendo_alvo_id

func concluir_escolha_alvo() -> void:
	_jogador_escolhendo_alvo_id = -1

func tem_escolha_pendente() -> bool:
	return _jogador_escolhendo_cor_id > 0 or _jogador_escolhendo_alvo_id > 0

func obter_carta_aguardando_cor_id() -> int:
	return _carta_aguardando_cor_id

func concluir_escolha_cor() -> void:
	_jogador_escolhendo_cor_id = -1
	_carta_aguardando_cor_id = -1

func alterar_cor_carta(id_carta: int, cor: Carta_Base.Cores) -> Dictionary:
	var localizacao := localizar_carta_por_id(id_carta)
	if localizacao.is_empty():
		return {}
	var carta: Carta_Base = localizacao["carta"]
	localizacao["alterada"] = carta.alterar_cor(cor)
	return localizacao

func localizar_carta_por_id(id_carta: int) -> Dictionary:
	for jogador in obter_jogadores():
		var carta := jogador.consulta_carta(id_carta)
		if carta:
			return {"carta": carta, "local": "mao", "jogador_id": jogador.get_id()}
	var carta_descarte := _descarte.consultar_carta_por_id(id_carta)
	if carta_descarte:
		return {"carta": carta_descarte, "local": "descarte"}
	var carta_monte := _baralho.consultar_carta_por_id(id_carta)
	if carta_monte:
		return {"carta": carta_monte, "local": "monte"}
	return {}

func adicionar_compra_acumulada(quantidade: int) -> void:
	_compra_acumulada += quantidade

func obter_compra_acumulada() -> int:
	return _compra_acumulada

func zerar_compra_acumulada() -> void:
	_compra_acumulada = 0

func pular_proximo_jogador() -> Jogador_Logico:
	return _lista_jogadores.obter_proximo()

func inverter_ordem_jogadores() -> void:
	_lista_jogadores.inverter()

func obter_carta_do_jogador(id_jogador: int, id_carta: int) -> Carta_Base:
	var jogador := consultar_jogador_por_id(id_jogador)
	if not jogador:
		return null
	return jogador.consulta_carta(id_carta)

func descartar_carta_do_jogador_por_id(id_jogador: int, id_carta: int) -> Carta_Base:
	var jogador := consultar_jogador_por_id(id_jogador)
	if not jogador:
		return null
	var carta := jogador.descarta_carta(id_carta)
	if carta:
		_descarte.adicionar_carta(carta)
	return carta

func descartar_carta_do_jogador(nome_jogador: String, id_carta: int) -> Carta_Base:
	var jogador := consultar_jogador(nome_jogador)
	if not jogador:
		return null
	return descartar_carta_do_jogador_por_id(jogador.get_id(), id_carta)

func printar_descarte() -> void:
	var carta := _descarte.consultar_carta()
	if carta:
		print("Descarte (topo): %s" % carta)
	else:
		print("Descarte vazio")

func distribuir_carta_do_monte(nome: String) -> void:
	var jogador := consultar_jogador(nome)
	if jogador:
		comprar_carta_para_jogador(jogador.get_id())

func pode_comprar_carta() -> bool:
	return _baralho.pode_comprar_carta()

func comprar_carta_para_jogador(id_jogador: int) -> Carta_Base:
	var jogador := consultar_jogador_por_id(id_jogador)
	if not jogador:
		return null
	var carta := _baralho.comprar_carta()
	if carta:
		jogador.recebe_carta(carta)
	return carta

func obter_quantidade_monte() -> int:
	return _baralho.contar_numero_cartas()

func registrar_compra_no_turno(id_carta_jogavel: int) -> void:
	_comprou_neste_turno = true
	_carta_comprada_jogavel_id = id_carta_jogavel

func comprou_neste_turno() -> bool:
	return _comprou_neste_turno

func obter_carta_comprada_jogavel_id() -> int:
	return _carta_comprada_jogavel_id

func _limpar_compra_no_turno() -> void:
	_comprou_neste_turno = false
	_carta_comprada_jogavel_id = -1

func obter_estado_publico_jogadores() -> Array[Dictionary]:
	var resumo: Array[Dictionary] = []
	for jogador in _lista_jogadores.obter_elementos():
		resumo.append({
			"id": jogador.get_id(),
			"nome": jogador.get_nome(),
			"quantidade_cartas": jogador.retorna_quantidade_cartas()
		})
	return resumo

func obter_jogador_sem_cartas() -> Jogador_Logico:
	for jogador in _lista_jogadores.obter_elementos():
		if jogador.retorna_quantidade_cartas() == 0:
			return jogador
	return null

func reatribuir_carta_do_jogador(pid_carta: int, nome_p1: String, nome_p2: String) -> void:
	var jogador1 := consultar_jogador(nome_p1)
	var jogador2 := consultar_jogador(nome_p2)
	if not jogador1 or not jogador2:
		return
	var carta := jogador1.descarta_carta(pid_carta)
	if carta:
		jogador2.recebe_carta(carta)

func trocar_maos(id_jogador: int, id_alvo: int) -> bool:
	var j1 := consultar_jogador_por_id(id_jogador)
	var j2 := consultar_jogador_por_id(id_alvo)
	if not j1 or not j2 or j1 == j2:
		return false
	var mao1 := j1.entregar_mao()
	var mao2 := j2.entregar_mao()
	j1.receber_mao(mao2)
	j2.receber_mao(mao1)
	return true
