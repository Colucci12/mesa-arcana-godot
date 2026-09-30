extends Node
class_name EndpointPartida

var _mesa_api: Mesa_Api = Mesa_Api.new()
var _gerenciador_rede: GerenciadorRede
var _barramento: BarramentoEventos
var _partida_iniciada: bool = false

func configurar(gerenciador_rede: GerenciadorRede, barramento: BarramentoEventos) -> void:
	_gerenciador_rede = gerenciador_rede
	_barramento = barramento

func registrar_jogador(id_jogador: int, nome: String) -> void:
	if multiplayer.is_server():
		_mesa_api.obter_mesa().adicionar_jogador(id_jogador, nome)

func iniciar_partida() -> void:
	if not multiplayer.is_server() or _partida_iniciada:
		return
	var resultado := _mesa_api.iniciar_partida()
	if not resultado["sucesso"]:
		_barramento.erro_comando.emit(resultado["mensagem"])
		return
	_partida_iniciada = true
	_gerenciador_rede.bloquear_entradas()
	_distribuir_eventos(resultado["eventos"])

func enviar_comando(comando: StringName, dados: Dictionary) -> void:
	if multiplayer.is_server():
		_executar_comando(1, comando, dados)
	else:
		_solicitar_comando.rpc_id(1, String(comando), dados)

@rpc("any_peer", "reliable")
func _solicitar_comando(comando: String, dados: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var id_jogador := _gerenciador_rede.obter_jogador_por_peer(peer_id)
	if id_jogador <= 0:
		return
	_executar_comando(id_jogador, StringName(comando), dados)

func _executar_comando(id_jogador: int, comando: StringName, dados: Dictionary) -> void:
	var resultado: Dictionary
	match comando:
		&"jogar_carta":
			var id_carta = dados.get("id_carta", null)
			if not (id_carta is int) or id_carta <= 0:
				_enviar_erro(id_jogador, "Carta inválida.")
				return
			resultado = _mesa_api.jogar_carta(id_jogador, id_carta)
		&"comprar_carta":
			resultado = _mesa_api.comprar_carta(id_jogador)
		&"aceitar_compra_acumulada":
			resultado = _mesa_api.aceitar_compra_acumulada(id_jogador)
		&"passar_vez":
			resultado = _mesa_api.passar_vez(id_jogador)
		&"escolher_cor":
			var cor = dados.get("cor", null)
			if not (cor is String):
				_enviar_erro(id_jogador, "Cor inválida.")
				return
			resultado = _mesa_api.escolher_cor(id_jogador, cor)
		_:
			_enviar_erro(id_jogador, "Comando desconhecido.")
			return
	if resultado["sucesso"]:
		_distribuir_eventos(resultado["eventos"])
	else:
		_enviar_erro(id_jogador, resultado["mensagem"])

func _distribuir_eventos(eventos: Array) -> void:
	for evento in eventos:
		var evento_anfitriao := VisibilidadeEventos.para_jogador(evento, 1)
		if not evento_anfitriao.is_empty():
			_barramento.evento_partida.emit(evento_anfitriao)
		var peer_cliente := _gerenciador_rede.obter_peer_cliente()
		if peer_cliente > 0:
			var evento_cliente := VisibilidadeEventos.para_jogador(evento, 2)
			if not evento_cliente.is_empty():
				_receber_evento.rpc_id(peer_cliente, evento_cliente)

func _enviar_erro(id_jogador: int, mensagem: String) -> void:
	if id_jogador == 1:
		_barramento.erro_comando.emit(mensagem)
		return
	var peer_cliente := _gerenciador_rede.obter_peer_cliente()
	if peer_cliente > 0:
		_receber_erro.rpc_id(peer_cliente, mensagem)

@rpc("authority", "reliable")
func _receber_evento(evento: Dictionary) -> void:
	if not multiplayer.is_server():
		_barramento.evento_partida.emit(evento)

@rpc("authority", "reliable")
func _receber_erro(mensagem: String) -> void:
	if not multiplayer.is_server():
		_barramento.erro_comando.emit(mensagem)
