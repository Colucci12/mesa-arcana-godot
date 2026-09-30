extends Node
class_name EndpointChat

const LIMITE_CARACTERES := 280

var _gerenciador_rede: GerenciadorRede
var _barramento: BarramentoEventos

func configurar(gerenciador_rede: GerenciadorRede, barramento: BarramentoEventos) -> void:
	_gerenciador_rede = gerenciador_rede
	_barramento = barramento

func enviar_mensagem(texto: String) -> void:
	if not _gerenciador_rede.esta_conectado():
		_barramento.erro_chat.emit("Entre em uma sala para conversar.")
		return
	if multiplayer.is_server():
		_processar_mensagem(1, texto)
	else:
		_solicitar_mensagem.rpc_id(1, texto)

@rpc("any_peer", "reliable")
func _solicitar_mensagem(texto: String) -> void:
	if multiplayer.is_server():
		_processar_mensagem(multiplayer.get_remote_sender_id(), texto)

func _processar_mensagem(peer_id: int, texto: String) -> void:
	var id_jogador := _gerenciador_rede.obter_jogador_por_peer(peer_id)
	var autor: Dictionary = {}
	for jogador in _gerenciador_rede.obter_jogadores():
		if int(jogador["id"]) == id_jogador:
			autor = jogador
			break
	if autor.is_empty():
		_enviar_erro(peer_id, "Confirme sua entrada na sala antes de conversar.")
		return
	var texto_limpo := texto.strip_edges().replace("\r", " ").replace("\n", " ").replace("\t", " ")
	if texto_limpo.is_empty():
		_enviar_erro(peer_id, "Digite uma mensagem.")
		return
	if texto_limpo.length() > LIMITE_CARACTERES:
		_enviar_erro(peer_id, "A mensagem deve ter até %d caracteres." % LIMITE_CARACTERES)
		return
	var mensagem := {"jogador_id": id_jogador, "nome": autor["nome"], "texto": texto_limpo}
	_receber_mensagem(mensagem)
	for peer_cliente in _gerenciador_rede.obter_peers_prontos():
		_receber_mensagem.rpc_id(peer_cliente, mensagem)

func _enviar_erro(peer_id: int, mensagem: String) -> void:
	if peer_id == 1:
		_barramento.erro_chat.emit(mensagem)
	else:
		_receber_erro.rpc_id(peer_id, mensagem)

@rpc("authority", "reliable")
func _receber_mensagem(mensagem: Dictionary) -> void:
	_barramento.mensagem_chat_recebida.emit(mensagem)

@rpc("authority", "reliable")
func _receber_erro(mensagem: String) -> void:
	_barramento.erro_chat.emit(mensagem)
