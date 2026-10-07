extends Node
class_name CentralSalas

signal conexao_alterada
signal lista_alterada(salas: Array)
signal identidade_confirmada(id_jogador: int)
signal status_alterado(mensagem: String, permitir_nova_tentativa: bool)
signal sala_atualizada(jogadores: Array, pode_iniciar: bool)
signal partida_interrompida(motivo: String)
signal evento_partida(evento: Dictionary)
signal erro_comando(mensagem: String)
signal mensagem_chat_recebida(mensagem: Dictionary)
signal erro_chat(mensagem: String)

const CONFIG = preload("res://scripts/rede/configuracao_central.gd")
const PROTOCOLO := 1
const ALFABETO := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var url := ""
var estado_conexao := "Desconectado do servidor."
var salas: Array = []
var sala: Dictionary = {}
var jogador_id := -1
var pedido_pendente := false
var _api := SceneMultiplayer.new()
var _servidor := false
var _conectado := false
var _conectando := false
var _prazo := 0
var _salas: Dictionary = {}
var _sala_por_peer: Dictionary = {}
var _clientes: Dictionary = {}
var _sequencia_partida := 0
var _maximo_clientes := 128
var _maximo_salas := 32


func _ready() -> void:
	# Rede própria: não aciona endpoints/sinais do modo ENet legado.
	var raiz := get_parent().get_path()
	_api.root_path = raiz
	_api.server_relay = false
	_api.allow_object_decoding = false
	get_tree().set_multiplayer(_api, raiz)
	_api.connected_to_server.connect(_ao_conectar)
	_api.connection_failed.connect(_ao_falhar)
	_api.server_disconnected.connect(_ao_falhar)
	_api.peer_connected.connect(_ao_peer_conectar)
	_api.peer_disconnected.connect(_ao_peer_sair)


func iniciar_servidor() -> Dictionary:
	var porta := CONFIG.numero_servidor("porta", "JUNO_PORTA", 9080, 1, 65535)
	_maximo_clientes = CONFIG.numero_servidor("maximo_clientes", "JUNO_MAX_CLIENTES", 128, 2, 4096)
	_maximo_salas = CONFIG.numero_servidor("maximo_salas", "JUNO_MAX_SALAS", 32, 1, 1024)
	var peer := _novo_peer()
	var erro := peer.create_server(porta, CONFIG.endereco_servidor())
	if erro != OK:
		return SalaCentral.falha("Não foi possível abrir o servidor na porta %d (erro %d)." % [porta, erro])
	_servidor = true
	_api.multiplayer_peer = peer
	print("Mesa Arcana: servidor de salas WebSocket na porta %d; protocolo %d." % [porta, PROTOCOLO])
	return {"sucesso": true}


func conectar(endereco: String = "") -> Dictionary:
	if _servidor:
		return SalaCentral.falha("Esta instância é o servidor.")
	var destino := CONFIG.url_cliente() if endereco.strip_edges().is_empty() else endereco.strip_edges()
	if not (destino.begins_with("ws://") or destino.begins_with("wss://")):
		return SalaCentral.falha("O endereço do servidor deve começar com ws:// ou wss://.")
	if CONFIG.pagina_segura() and not destino.begins_with("wss://"):
		return SalaCentral.falha("Nesta página, use um servidor com conexão segura (wss://).")
	if destino == url and (_conectado or _conectando):
		return {"sucesso": true}
	if em_sala() or pedido_pendente:
		return SalaCentral.falha("Saia da sala antes de trocar de servidor.")
	_desconectar()
	url = destino
	var peer := _novo_peer()
	var erro := peer.create_client(url)
	if erro != OK:
		return SalaCentral.falha("Não foi possível iniciar a conexão ao servidor (erro %d)." % erro)
	_api.multiplayer_peer = peer
	_conectando = true
	_prazo = Time.get_ticks_msec() + 15000
	_estado("Conectando ao servidor…")
	return {"sucesso": true}


func _novo_peer() -> WebSocketMultiplayerPeer:
	var peer := WebSocketMultiplayerPeer.new()
	peer.handshake_timeout = 10.0
	peer.inbound_buffer_size = 16384
	peer.outbound_buffer_size = 131072
	peer.max_queued_packets = 128
	return peer


func conectado() -> bool:
	return _conectado


func em_sala() -> bool:
	return _conectado and not sala.is_empty()


func eh_anfitriao() -> bool:
	return em_sala() and jogador_id == int(sala.get("anfitriao_id", -1))


func pode_iniciar() -> bool:
	return eh_anfitriao() and not pedido_pendente and bool(sala.get("pode_iniciar", false))


func criar_sala(nome: String) -> Dictionary:
	return _pedir_entrada("criar", {"nome": nome})


func entrar_sala(nome: String, codigo: String) -> Dictionary:
	return _pedir_entrada("entrar", {"nome": nome, "codigo": codigo.strip_edges().to_upper()})


func _pedir_entrada(acao: String, dados: Dictionary) -> Dictionary:
	if not _conectado:
		return SalaCentral.falha("Aguarde a conexão ao servidor ou tente conectar novamente.")
	if em_sala() or pedido_pendente:
		return SalaCentral.falha("Uma entrada na sala já está em andamento.")
	var nome := str(dados["nome"]).strip_edges()
	if nome.is_empty() or nome.length() > 24:
		return SalaCentral.falha("Escolha um nome com até 24 caracteres.")
	pedido_pendente = true
	_prazo = Time.get_ticks_msec() + 15000
	_solicitar.rpc_id(1, acao, dados)
	return {"sucesso": true}


func atualizar_lista() -> void:
	if _conectado:
		_solicitar.rpc_id(1, "listar", {})


func iniciar_partida() -> void:
	if pode_iniciar():
		pedido_pendente = true
		_prazo = Time.get_ticks_msec() + 15000
		_solicitar.rpc_id(1, "iniciar", {"codigo": sala["codigo"]})


func enviar_comando(comando: StringName, dados: Dictionary) -> void:
	if em_sala():
		_solicitar.rpc_id(1, "comando", {"codigo": sala["codigo"], "partida": sala["id_partida"],
			"comando": str(comando), "dados": dados})


func enviar_chat(texto: String) -> void:
	if not em_sala():
		erro_chat.emit("Entre em uma sala para conversar.")
		return
	_solicitar.rpc_id(1, "chat", {"codigo": sala["codigo"], "texto": texto})


func sair_sala() -> void:
	if _conectado:
		_solicitar.rpc_id(1, "sair", {})
	else:
		pedido_pendente = false
		partida_interrompida.emit("Você saiu da sala.")
		status_alterado.emit("Você saiu da sala.", true)


func _process(_delta: float) -> void:
	if not _servidor and (_conectando or pedido_pendente) and Time.get_ticks_msec() >= _prazo:
		_ao_falhar()
	if _servidor:
		for peer in _clientes.keys():
			if not bool(_clientes[peer]["pronto"]) and Time.get_ticks_msec() - int(_clientes[peer]["entrada"]) > 15000:
				_api.disconnect_peer(int(peer))


func _ao_conectar() -> void:
	_solicitar.rpc_id(1, "apresentar", {"protocolo": PROTOCOLO})


func _ao_falhar() -> void:
	var estava_na_sala := em_sala()
	_desconectar()
	if estava_na_sala:
		partida_interrompida.emit("A conexão com o servidor foi perdida.")
	_estado("Não foi possível manter a conexão ao servidor.")
	status_alterado.emit(estado_conexao, true)


func _desconectar() -> void:
	if _api.multiplayer_peer:
		_api.multiplayer_peer.close()
	_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	_conectado = false
	_conectando = false
	pedido_pendente = false
	sala.clear()
	salas.clear()
	jogador_id = -1


func _estado(texto: String) -> void:
	estado_conexao = texto
	conexao_alterada.emit()


func _ao_peer_conectar(peer: int) -> void:
	if not _servidor:
		return
	if _clientes.size() >= _maximo_clientes:
		_api.disconnect_peer(peer)
		return
	_clientes[peer] = {"pronto": false, "entrada": Time.get_ticks_msec(), "janela": 0, "pedidos": 0, "entradas": 0}
	_api.refuse_new_connections = _clientes.size() >= _maximo_clientes


func _ao_peer_sair(peer: int) -> void:
	if _servidor:
		_clientes.erase(peer)
		_remover_da_sala(peer)
		_api.refuse_new_connections = _clientes.size() >= _maximo_clientes


@rpc("any_peer", "reliable")
func _solicitar(acao: String, dados: Dictionary) -> void:
	if not _servidor:
		return
	var peer := _api.get_remote_sender_id()
	if not _clientes.has(peer) or not _permitir_pedido(peer, acao):
		return
	if acao == "apresentar":
		if dados.get("protocolo") != PROTOCOLO:
			_responder(peer, "versao_incompativel", {})
			return
		_clientes[peer]["pronto"] = true
		_responder(peer, "bem_vindo", {"protocolo": PROTOCOLO})
		_enviar_lista(peer)
		return
	if not bool(_clientes[peer]["pronto"]):
		return
	match acao:
		"listar":
			_enviar_lista(peer)
		"criar", "entrar":
			_entrar_servidor(peer, acao, dados)
		"sair":
			_remover_da_sala(peer)
			_responder(peer, "saiu", {})
		"iniciar", "comando", "chat":
			var codigo := str(_sala_por_peer.get(peer, ""))
			if codigo.is_empty() or dados.get("codigo") != codigo:
				_erro(peer, acao, "Entre na sala antes de continuar.")
				return
			var atual: SalaCentral = _salas[codigo]
			if acao == "chat":
				_chat_servidor(peer, atual, dados)
				return
			var resultado: Dictionary
			if acao == "iniciar":
				_sequencia_partida += 1
				resultado = atual.iniciar(peer, _sequencia_partida)
			else:
				if not dados.get("partida") is int or not dados.get("comando") is String or not dados.get("dados") is Dictionary:
					_erro(peer, acao, "Comando inválido.")
					return
				resultado = atual.comandar(peer, int(dados["partida"]), str(dados["comando"]), dados["dados"])
			if not resultado["sucesso"]:
				_erro(peer, acao, str(resultado["mensagem"]))
				return
			if acao == "iniciar":
				_publicar_sala(atual)
			_distribuir_eventos(atual, resultado["eventos"])
			if acao == "iniciar" or not atual.em_partida:
				_publicar_listas()


func _permitir_pedido(peer: int, acao: String) -> bool:
	var cliente: Dictionary = _clientes[peer]
	var janela := Time.get_ticks_msec() / 1000
	if int(cliente["janela"]) != int(janela):
		cliente["janela"] = int(janela)
		cliente["pedidos"] = 0
		cliente["entradas"] = 0
	cliente["pedidos"] += 1
	if acao in ["criar", "entrar"]:
		cliente["entradas"] += 1
	return int(cliente["pedidos"]) <= 20 and int(cliente["entradas"]) <= 3


func _entrar_servidor(peer: int, acao: String, dados: Dictionary) -> void:
	if _sala_por_peer.has(peer):
		_erro(peer, acao, "Você já está em uma sala.")
		return
	if not dados.get("nome") is String:
		_erro(peer, acao, "Nome inválido.")
		return
	var codigo := ""
	var atual: SalaCentral
	if acao == "criar":
		if _salas.size() >= _maximo_salas:
			_erro(peer, acao, "O servidor está com todas as mesas ocupadas. Tente novamente depois.")
			return
		codigo = _novo_codigo()
		atual = SalaCentral.new(codigo)
	else:
		codigo = str(dados.get("codigo", "")).strip_edges().to_upper()
		if codigo.length() != 6 or not _salas.has(codigo):
			_erro(peer, acao, "Sala não encontrada. Confira o código.")
			return
		atual = _salas[codigo]
	var resultado := atual.entrar(peer, str(dados["nome"]))
	if not resultado["sucesso"]:
		_erro(peer, acao, str(resultado["mensagem"]))
		return
	_salas[codigo] = atual
	_sala_por_peer[peer] = codigo
	_publicar_sala(atual)
	_publicar_listas()


func _novo_codigo() -> String:
	while true:
		var codigo := ""
		for _indice in range(6):
			codigo += ALFABETO[randi_range(0, ALFABETO.length() - 1)]
		if not _salas.has(codigo):
			return codigo
	return ""


func _remover_da_sala(peer: int) -> void:
	if not _sala_por_peer.has(peer):
		return
	var codigo := str(_sala_por_peer[peer])
	_sala_por_peer.erase(peer)
	var atual: SalaCentral = _salas[codigo]
	var motivo := atual.remover(peer)
	if atual.participantes.is_empty():
		_salas.erase(codigo)
	else:
		if not motivo.is_empty():
			for outro in atual.participantes:
				_responder(int(outro), "interrompida", {"codigo": codigo, "motivo": motivo})
		_publicar_sala(atual)
	_publicar_listas()


func _distribuir_eventos(atual: SalaCentral, eventos: Array) -> void:
	for evento in eventos:
		for peer in atual.participantes:
			var filtrado := VisibilidadeEventos.para_jogador(evento, int(atual.participantes[peer]["id"]))
			if not filtrado.is_empty():
				_responder(int(peer), "evento", {"codigo": atual.codigo, "partida": atual.id_partida, "evento": filtrado})
		if evento.get("tipo") == "PartidaEncerrada":
			atual.em_partida = false
			_publicar_sala(atual)


func _chat_servidor(peer: int, atual: SalaCentral, dados: Dictionary) -> void:
	if not dados.get("texto") is String:
		_erro(peer, "chat", "Mensagem inválida.")
		return
	var texto := str(dados["texto"]).strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if texto.is_empty() or texto.length() > 280:
		_erro(peer, "chat", "Digite uma mensagem com até 280 caracteres.")
		return
	var mensagem: Dictionary = atual.participantes[peer].duplicate()
	mensagem["jogador_id"] = mensagem["id"]
	mensagem.erase("id")
	mensagem["texto"] = texto
	for outro in atual.participantes:
		_responder(int(outro), "chat", {"codigo": atual.codigo, "mensagem": mensagem})


func _publicar_sala(atual: SalaCentral) -> void:
	for peer in atual.participantes:
		_responder(int(peer), "sala", atual.estado(int(peer)))


func _enviar_lista(peer: int) -> void:
	var lista: Array = []
	for atual: SalaCentral in _salas.values():
		lista.append(atual.resumo())
	_responder(peer, "lista", {"salas": lista})


func _publicar_listas() -> void:
	for peer in _clientes:
		if bool(_clientes[peer]["pronto"]):
			_enviar_lista(int(peer))


func _erro(peer: int, destino: String, texto: String) -> void:
	_responder(peer, "erro", {"destino": destino, "mensagem": texto})


func _responder(peer: int, tipo: String, dados: Dictionary) -> void:
	_receber.rpc_id(peer, tipo, dados)


@rpc("authority", "reliable")
func _receber(tipo: String, dados: Dictionary) -> void:
	if _servidor:
		return
	match tipo:
		"bem_vindo":
			_conectado = true
			_conectando = false
			_estado("Conectado ao servidor.")
		"versao_incompativel":
			_desconectar()
			_estado("Atualize o jogo: a versão do servidor é diferente.")
			status_alterado.emit(estado_conexao, true)
		"lista":
			salas = dados["salas"]
			lista_alterada.emit(salas)
		"sala":
			var entrando := sala.is_empty()
			sala = dados
			pedido_pendente = false
			jogador_id = int(sala["jogador_id"])
			if entrando:
				identidade_confirmada.emit(jogador_id)
			sala_atualizada.emit(sala["jogadores"], pode_iniciar())
		"saiu":
			sala.clear()
			jogador_id = -1
			pedido_pendente = false
			partida_interrompida.emit("Você saiu da sala.")
			status_alterado.emit("Você saiu da sala.", true)
		"interrompida":
			if dados["codigo"] == sala.get("codigo"):
				partida_interrompida.emit(str(dados["motivo"]))
		"evento":
			if dados["codigo"] == sala.get("codigo") and dados["partida"] == sala.get("id_partida"):
				evento_partida.emit(dados["evento"])
		"chat":
			if dados["codigo"] == sala.get("codigo"):
				mensagem_chat_recebida.emit(dados["mensagem"])
		"erro":
			var destino := str(dados["destino"])
			if destino == "chat":
				erro_chat.emit(str(dados["mensagem"]))
			elif destino in ["criar", "entrar"]:
				pedido_pendente = false
				status_alterado.emit(str(dados["mensagem"]), true)
			else:
				pedido_pendente = false
				erro_comando.emit(str(dados["mensagem"]))
