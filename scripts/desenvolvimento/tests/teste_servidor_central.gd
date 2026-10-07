extends Node

const CENTRAL = preload("res://scripts/rede/central_salas.gd")
var _clientes: Array[CentralSalas] = []
var _eventos: Array[Array] = [[], [], [], []]
var _chat: Array[Array] = [[], [], [], []]
var _erros: Array[Array] = [[], [], [], []]
var _interrupcoes: Array[int] = [0, 0, 0, 0]


func _ready() -> void:
	# Teste real através do proxy web, com quatro clientes e duas salas.
	for indice in range(4):
		var ramo := Node.new()
		ramo.name = "ClienteTeste%d" % indice
		add_child(ramo)
		var cliente: CentralSalas = CENTRAL.new()
		cliente.name = "CentralSalas"
		ramo.add_child(cliente)
		cliente.evento_partida.connect(func(evento: Dictionary): _eventos[indice].append(evento))
		cliente.mensagem_chat_recebida.connect(func(mensagem: Dictionary): _chat[indice].append(mensagem))
		cliente.erro_comando.connect(func(texto: String): _erros[indice].append(texto))
		cliente.partida_interrompida.connect(func(_texto: String): _interrupcoes[indice] += 1)
		_clientes.append(cliente)
		cliente.conectar("ws://127.0.0.1:8080/multiplayer")
	if not await _aguardar(func(): return _clientes.all(func(c: CentralSalas): return c.conectado()), "conexão dos quatro clientes"):
		return
	_clientes[0].criar_sala("Teste A")
	_clientes[2].criar_sala("Teste C")
	if not await _aguardar(func(): return _clientes[0].em_sala() and _clientes[2].em_sala(), "criação de duas salas"):
		return
	var codigo_a := str(_clientes[0].sala["codigo"])
	var codigo_b := str(_clientes[2].sala["codigo"])
	if not _verificar(codigo_a != codigo_b, "códigos distintos"):
		return
	_clientes[1].entrar_sala("Teste B", codigo_a)
	_clientes[3].entrar_sala("Teste D", codigo_b)
	if not await _aguardar(func(): return _clientes[0].pode_iniciar() and _clientes[2].pode_iniciar(), "dois participantes em cada sala"):
		return
	_clientes[0].enviar_chat("Mensagem restrita à sala A")
	if not await _aguardar(func(): return _chat[0].size() == 1 and _chat[1].size() == 1, "chat na sala A"):
		return
	if not _verificar(_chat[2].is_empty() and _chat[3].is_empty(), "chat isolado da sala B"):
		return
	# Contorna só a trava local para verificar a autorização no servidor.
	_clientes[3]._solicitar.rpc_id(1, "iniciar", {"codigo": codigo_b})
	if not await _aguardar(func(): return _erros[3].size() == 1, "recusa de início por convidado"):
		return
	_clientes[0].iniciar_partida()
	_clientes[2].iniciar_partida()
	if not await _aguardar(func(): return _eventos.all(func(lista: Array): return lista.any(func(e: Dictionary): return e["tipo"] == "DistribuicaoConcluida")), "distribuição nas duas salas"):
		return
	for indice in range(4):
		var cartas_privadas := 0
		for evento in _eventos[indice]:
			if evento["tipo"] != "CartaRecebida":
				continue
			var propria := int(evento["publico"]["jogador_id"]) == _clientes[indice].jogador_id
			if propria:
				cartas_privadas += 1
			if not _verificar(evento["privado"].has("carta") == propria, "privacidade das mãos"):
				return
		if not _verificar(cartas_privadas == 7, "sete cartas privadas por jogador"):
			return
	var total_b := _eventos[2].size()
	var total_d := _eventos[3].size()
	var total_a := _eventos[0].size()
	_clientes[0].enviar_comando(&"comprar_carta", {})
	if not await _aguardar(func(): return _eventos[0].size() > total_a, "compra confirmada na sala A"):
		return
	if not _verificar(_eventos[2].size() == total_b and _eventos[3].size() == total_d, "eventos isolados entre salas"):
		return
	_clientes[0].sair_sala()
	if not await _aguardar(func(): return _interrupcoes[1] == 1 and _clientes[1].eh_anfitriao(), "interrupção e transferência do organizador"):
		return
	if not _verificar(_interrupcoes[2] == 0 and _interrupcoes[3] == 0 and bool(_clientes[2].sala["em_partida"]), "outra sala continua em partida"):
		return
	for cliente in _clientes:
		cliente.sair_sala()
	await get_tree().create_timer(0.2).timeout
	print("JUNO CENTRAL OK: proxy, quatro clientes, duas salas, chat, autorização, cartas privadas, compra e desconexão isoladas.")
	get_tree().quit(0)


func _aguardar(condicao: Callable, descricao: String) -> bool:
	var prazo := Time.get_ticks_msec() + 12000
	while not condicao.call() and Time.get_ticks_msec() < prazo:
		await get_tree().create_timer(0.05).timeout
	return _verificar(bool(condicao.call()), descricao)


func _verificar(estado: bool, descricao: String) -> bool:
	if not estado:
		push_error("JUNO CENTRAL FALHOU: " + descricao)
		get_tree().quit(1)
	return estado
