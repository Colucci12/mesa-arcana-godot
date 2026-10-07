extends Node
class_name GerenciadorRede

signal identidade_confirmada(id_jogador: int)
signal status_alterado(mensagem: String, permitir_nova_tentativa: bool)
signal sala_atualizada(jogadores: Array, pode_iniciar: bool)
signal partida_interrompida(motivo: String)

const LIMITE_JOGADORES := 4

var _nome_local: String = ""
var _participantes: Dictionary = {}
var _proximo_id: int = 2
var _em_partida: bool = false
var _conectado: bool = false
var _central: CentralSalas
var _modo_central := true

func configurar_central(central: CentralSalas) -> void:
	_central = central
	central.identidade_confirmada.connect(func(id: int):
		if usando_central(): identidade_confirmada.emit(id))
	central.sala_atualizada.connect(func(jogadores: Array, inicio: bool):
		if usando_central(): sala_atualizada.emit(jogadores, inicio))
	central.status_alterado.connect(func(texto: String, permitir: bool):
		if usando_central(): status_alterado.emit(texto, permitir))
	central.partida_interrompida.connect(func(texto: String):
		if usando_central(): partida_interrompida.emit(texto))

func usando_central() -> bool:
	return _modo_central and _central != null

func definir_modo_central(ativo: bool) -> void:
	if ativo == _modo_central:
		return
	if not usando_central():
		_encerrar_conexao()
	_modo_central = ativo

func eh_anfitriao() -> bool:
	return _central.eh_anfitriao() if usando_central() else multiplayer.is_server()

func obter_central() -> CentralSalas:
	return _central

func _ready() -> void:
	multiplayer.connected_to_server.connect(_ao_conectar_no_servidor)
	multiplayer.connection_failed.connect(_ao_falhar_conexao)
	multiplayer.server_disconnected.connect(_ao_servidor_desconectar)
	multiplayer.peer_disconnected.connect(_ao_peer_desconectar)

func hospedar(nome: String, porta: int) -> Dictionary:
	if OS.has_feature("web"):
		return _falha("No navegador, crie sua sala no servidor online.")
	# Chamadas antigas continuam sendo o fluxo direto, inclusive nos testes existentes.
	_modo_central = false
	var nome_limpo := nome.strip_edges()
	if nome_limpo.is_empty() or nome_limpo.length() > 24:
		return _falha("Escolha um nome com até 24 caracteres.")
	var peer = ClassDB.instantiate("ENetMultiplayerPeer")
	var erro = peer.create_server(porta, LIMITE_JOGADORES - 1)
	if erro != OK:
		return _falha("Não foi possível abrir a porta %d (erro %d)." % [porta, erro])
	_encerrar_conexao()
	multiplayer.multiplayer_peer = peer
	_conectado = true
	_nome_local = nome_limpo
	_participantes[1] = {"id": 1, "nome": nome_limpo, "pronto": true}
	identidade_confirmada.emit(1)
	_publicar_sala()
	return {"sucesso": true, "mensagem": ""}

func entrar(nome: String, endereco: String, porta: int) -> Dictionary:
	if OS.has_feature("web"):
		return _falha("No navegador, entre na sala pelo código.")
	_modo_central = false
	var nome_limpo := nome.strip_edges()
	if nome_limpo.is_empty() or nome_limpo.length() > 24:
		return _falha("Escolha um nome com até 24 caracteres.")
	if endereco.strip_edges().is_empty():
		return _falha("Informe o IP do anfitrião.")
	var peer = ClassDB.instantiate("ENetMultiplayerPeer")
	var erro = peer.create_client(endereco.strip_edges(), porta)
	if erro != OK:
		return _falha("Não foi possível iniciar a conexão (erro %d)." % erro)
	_encerrar_conexao()
	_nome_local = nome_limpo
	multiplayer.multiplayer_peer = peer
	status_alterado.emit("Conectando...", false)
	return {"sucesso": true, "mensagem": ""}

func sair() -> void:
	if usando_central():
		_central.sair_sala()
		return
	_encerrar_conexao()
	partida_interrompida.emit("Você saiu da sala.")
	status_alterado.emit("Você saiu da sala.", true)

func esta_conectado() -> bool:
	if usando_central():
		return _central.em_sala()
	return _conectado

func obter_jogador_por_peer(peer_id: int) -> int:
	return int(_participantes.get(peer_id, {}).get("id", -1))

func obter_peer_por_jogador(id_jogador: int) -> int:
	for peer_id in _participantes:
		if obter_jogador_por_peer(peer_id) == id_jogador:
			return peer_id
	return 0

func obter_peers_prontos() -> Array[int]:
	var peers: Array[int] = []
	for peer_id in _participantes:
		if peer_id != 1 and bool(_participantes[peer_id]["pronto"]):
			peers.append(peer_id)
	return peers

func obter_jogadores() -> Array[Dictionary]:
	var jogadores: Array[Dictionary] = []
	for dados in _participantes.values():
		if bool(dados["pronto"]):
			jogadores.append({"id": dados["id"], "nome": dados["nome"]})
	return jogadores

func pode_iniciar() -> bool:
	if usando_central():
		return _central.pode_iniciar()
	return _conectado and multiplayer.is_server() and not _em_partida and obter_jogadores().size() >= 2 and obter_jogadores().size() == _participantes.size()

func bloquear_entradas() -> void:
	_em_partida = true
	_publicar_sala()

func concluir_partida() -> void:
	_em_partida = false
	_publicar_sala()

func _ao_conectar_no_servidor() -> void:
	_apresentar.rpc_id(1, _nome_local)

func _ao_falhar_conexao() -> void:
	_encerrar_conexao()
	status_alterado.emit("Não foi possível conectar ao anfitrião.", true)

func _ao_servidor_desconectar() -> void:
	_encerrar_conexao()
	partida_interrompida.emit("O anfitrião se desconectou.")
	status_alterado.emit("O anfitrião se desconectou.", true)

func _ao_peer_desconectar(peer_id: int) -> void:
	if not multiplayer.is_server() or not _participantes.has(peer_id):
		return
	var nome := String(_participantes[peer_id]["nome"])
	_participantes.erase(peer_id)
	if _em_partida:
		_em_partida = false
		_interromper_partida.rpc("%s saiu. A partida foi interrompida." % nome)
	_publicar_sala()

@rpc("authority", "call_local", "reliable")
func _interromper_partida(motivo: String) -> void:
	partida_interrompida.emit(motivo)

@rpc("any_peer", "reliable")
func _apresentar(nome: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _participantes.has(peer_id):
		return
	var nome_limpo := nome.strip_edges()
	var motivo := ""
	if _em_partida:
		motivo = "A partida já começou. Aguarde a próxima."
	elif _participantes.size() >= LIMITE_JOGADORES:
		motivo = "A sala já tem quatro jogadores."
	elif nome_limpo.is_empty() or nome_limpo.length() > 24:
		motivo = "Escolha um nome com até 24 caracteres."
	else:
		for dados in _participantes.values():
			if String(dados["nome"]).to_lower() == nome_limpo.to_lower():
				motivo = "Esse nome já está em uso."
	if not motivo.is_empty():
		_entrada_recusada.rpc_id(peer_id, motivo)
		return
	var id_jogador := _proximo_id
	_proximo_id += 1
	_participantes[peer_id] = {"id": id_jogador, "nome": nome_limpo, "pronto": false}
	_identidade_confirmada.rpc_id(peer_id, id_jogador)
	_publicar_sala()

@rpc("authority", "reliable")
func _identidade_confirmada(id_jogador: int) -> void:
	_conectado = true
	identidade_confirmada.emit(id_jogador)
	_confirmar_pronto.rpc_id(1)

@rpc("any_peer", "reliable")
func _confirmar_pronto() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _participantes.has(peer_id):
		return
	_participantes[peer_id]["pronto"] = true
	_publicar_sala()

func _publicar_sala() -> void:
	_receber_sala.rpc(obter_jogadores(), pode_iniciar())

@rpc("authority", "call_local", "reliable")
func _receber_sala(jogadores: Array, inicio_liberado: bool) -> void:
	sala_atualizada.emit(jogadores, inicio_liberado and multiplayer.is_server())

@rpc("authority", "reliable")
func _entrada_recusada(motivo: String) -> void:
	_encerrar_conexao()
	status_alterado.emit(motivo, true)

func _encerrar_conexao() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_participantes.clear()
	_proximo_id = 2
	_em_partida = false
	_conectado = false

func _falha(mensagem: String) -> Dictionary:
	return {"sucesso": false, "mensagem": mensagem}
