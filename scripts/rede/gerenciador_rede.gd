extends Node
class_name GerenciadorRede

signal jogador_registrado(id_jogador: int, nome: String)
signal identidade_confirmada(id_jogador: int)
signal cliente_pronto
signal status_alterado(mensagem: String, permitir_nova_tentativa: bool)

var _nome_local: String = ""
var _nome_anfitriao: String = ""
var _peer_cliente: int = 0
var _jogadores_por_peer: Dictionary = {}
var _aceitando_conexoes: bool = true

func _ready() -> void:
	multiplayer.connected_to_server.connect(_ao_conectar_no_servidor)
	multiplayer.connection_failed.connect(_ao_falhar_conexao)
	multiplayer.server_disconnected.connect(_ao_servidor_desconectar)
	multiplayer.peer_disconnected.connect(_ao_peer_desconectar)

func hospedar(nome: String, porta: int) -> Dictionary:
	var nome_limpo := nome.strip_edges()
	if nome_limpo.is_empty():
		return _falha("Informe seu nome.")
	var peer := ENetMultiplayerPeer.new()
	var erro := peer.create_server(porta, 1)
	if erro != OK:
		return _falha("Não foi possível abrir a porta %d (erro %d)." % [porta, erro])
	multiplayer.multiplayer_peer = peer
	_nome_local = nome_limpo
	_nome_anfitriao = nome_limpo
	_aceitando_conexoes = true
	_jogadores_por_peer[1] = 1
	jogador_registrado.emit(1, nome_limpo)
	identidade_confirmada.emit(1)
	status_alterado.emit("Aguardando outro jogador...", false)
	return {"sucesso": true, "mensagem": ""}

func entrar(nome: String, endereco: String, porta: int) -> Dictionary:
	var nome_limpo := nome.strip_edges()
	if nome_limpo.is_empty():
		return _falha("Informe seu nome.")
	var endereco_limpo := endereco.strip_edges()
	if endereco_limpo.is_empty():
		return _falha("Informe o IP do anfitrião.")
	var peer := ENetMultiplayerPeer.new()
	var erro := peer.create_client(endereco_limpo, porta)
	if erro != OK:
		return _falha("Não foi possível iniciar a conexão (erro %d)." % erro)
	_nome_local = nome_limpo
	multiplayer.multiplayer_peer = peer
	status_alterado.emit("Conectando a %s:%d..." % [endereco_limpo, porta], false)
	return {"sucesso": true, "mensagem": ""}

func obter_jogador_por_peer(peer_id: int) -> int:
	return int(_jogadores_por_peer.get(peer_id, -1))

func obter_peer_cliente() -> int:
	return _peer_cliente

func bloquear_entradas() -> void:
	_aceitando_conexoes = false

func _ao_conectar_no_servidor() -> void:
	_apresentar.rpc_id(1, _nome_local)
	status_alterado.emit("Conectado. Aguardando confirmação...", false)

func _ao_falhar_conexao() -> void:
	_encerrar_conexao()
	status_alterado.emit("Não foi possível conectar ao anfitrião.", true)

func _ao_servidor_desconectar() -> void:
	_encerrar_conexao()
	status_alterado.emit("O anfitrião se desconectou.", true)

func _ao_peer_desconectar(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id != _peer_cliente:
		return
	_jogadores_por_peer.erase(peer_id)
	_peer_cliente = 0
	status_alterado.emit("O outro jogador se desconectou.", true)

@rpc("any_peer", "reliable")
func _apresentar(nome: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var nome_limpo := nome.strip_edges()
	var motivo := ""
	if nome_limpo.is_empty() or nome_limpo.length() > 24:
		motivo = "Escolha um nome com até 24 caracteres."
	elif not _aceitando_conexoes:
		motivo = "A partida já começou."
	elif nome_limpo.to_lower() == _nome_anfitriao.to_lower():
		motivo = "Esse nome já está em uso."
	elif _peer_cliente != 0:
		motivo = "A partida já tem dois jogadores."
	if not motivo.is_empty():
		_entrada_recusada.rpc_id(peer_id, motivo)
		await get_tree().create_timer(0.2).timeout
		if multiplayer.is_server():
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	_peer_cliente = peer_id
	_jogadores_por_peer[peer_id] = 2
	jogador_registrado.emit(2, nome_limpo)
	_identidade_confirmada.rpc_id(peer_id, 2)
	status_alterado.emit("%s entrou. Preparando partida..." % nome_limpo, false)

@rpc("authority", "reliable")
func _identidade_confirmada(id_jogador: int) -> void:
	if multiplayer.is_server():
		return
	identidade_confirmada.emit(id_jogador)
	status_alterado.emit("Registrado. Aguardando partida...", false)
	_confirmar_pronto.rpc_id(1)

@rpc("any_peer", "reliable")
func _confirmar_pronto() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == _peer_cliente and obter_jogador_por_peer(peer_id) == 2:
		cliente_pronto.emit()

@rpc("authority", "reliable")
func _entrada_recusada(motivo: String) -> void:
	if multiplayer.is_server():
		return
	_encerrar_conexao()
	status_alterado.emit(motivo, true)

func _encerrar_conexao() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_peer_cliente = 0
	_jogadores_por_peer.clear()

func _falha(mensagem: String) -> Dictionary:
	return {"sucesso": false, "mensagem": mensagem}
