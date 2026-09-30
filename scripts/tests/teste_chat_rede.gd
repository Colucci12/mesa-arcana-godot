extends Node

var _papel: int = 0
var _porta: int = 19995
var _mensagens: Array[Dictionary] = []
var _erros: int = 0
var _iniciando: bool = false
var _concluindo: bool = false
var _falhou: bool = false

func _ready() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("papel="):
			_papel = argumento.trim_prefix("papel=").to_int()
		if argumento.begins_with("porta="):
			_porta = argumento.trim_prefix("porta=").to_int()
	$PartidaRede/MesaPartida.intervalo_entre_cartas = 0.001
	var bus := GameManager.event_bus
	bus.sala_atualizada.connect(_ao_atualizar_sala)
	bus.mensagem_chat_recebida.connect(_ao_receber_mensagem)
	bus.erro_chat.connect(_ao_receber_erro)
	bus.evento_partida.connect(_ao_receber_evento)
	bus.estado_conexao.connect(_ao_alterar_conexao)
	get_tree().create_timer(20.0).timeout.connect(func(): _falhar("Tempo esgotado no teste do chat"))
	var resultado: Dictionary
	if _papel == 0:
		resultado = GameManager.network_manager.hospedar("Chat0", _porta)
	else:
		resultado = GameManager.network_manager.entrar("Chat1", "127.0.0.1", _porta)
	_verificar(resultado["sucesso"], "Não foi possível iniciar a conexão")

func _ao_atualizar_sala(jogadores: Array, pode_iniciar: bool) -> void:
	if _papel == 0 and jogadores.size() == 2 and pode_iniciar and not _iniciando:
		_iniciando = true
		_enviar_pela_interface("  [b]Olá da sala[/b]  ")

func _enviar_pela_interface(texto: String) -> void:
	var chat := $PartidaRede/ChatPartida
	chat._entrada.text = texto
	chat._enviar_mensagem()

func _ao_receber_mensagem(mensagem: Dictionary) -> void:
	_mensagens.append(mensagem)
	var id := int(mensagem["jogador_id"])
	_verificar(id in [1, 2] and mensagem["nome"] == "Chat%d" % (id - 1), "Autor não corresponde à conexão")
	_verificar(String(mensagem["texto"]).length() <= EndpointChat.LIMITE_CARACTERES, "Mensagem inválida foi publicada")
	if _papel == 1 and _mensagens.size() == 1:
		_enviar_pela_interface("Olá do cliente")
	if _mensagens.size() == 2:
		_testar_recusas_e_iniciar()
	if _mensagens.size() == 4:
		_concluir()

func _testar_recusas_e_iniciar() -> void:
	_verificar(_mensagens[0]["texto"] == "[b]Olá da sala[/b]", "O servidor não normalizou o texto")
	GameManager.chat_endpoint.enviar_mensagem("   ")
	GameManager.chat_endpoint.enviar_mensagem("x".repeat(EndpointChat.LIMITE_CARACTERES + 1))
	if _papel == 0:
		await get_tree().create_timer(0.3).timeout
		GameManager.match_endpoint.iniciar_partida()

func _ao_receber_erro(_mensagem: String) -> void:
	_erros += 1

func _ao_receber_evento(evento: Dictionary) -> void:
	if evento.get("tipo", "") == "DistribuicaoConcluida":
		_enviar_pela_interface("Partida %d" % _papel)

func _concluir() -> void:
	if _concluindo:
		return
	_concluindo = true
	await get_tree().create_timer(0.2).timeout
	_verificar(_erros == 2, "As recusas não chegaram apenas ao remetente")
	var chat := $PartidaRede/ChatPartida
	_verificar(chat._historico.size() == 4, "A interface não recebeu todas as mensagens")
	_verificar(chat._mensagens.get_parsed_text().contains("[b]Olá da sala[/b]"), "Mensagem foi interpretada como BBCode")
	_verificar(chat._entrada.text.is_empty() and not chat._enviando, "A interface não confirmou o envio")
	_verificar(chat._nao_lidas == 4, "Contagem de mensagens recolhidas incorreta")
	chat._abrir.button_pressed = true
	_verificar(chat._conteudo.visible and chat._nao_lidas == 0, "Abrir chat não limpou a contagem")
	if _papel == 0:
		await get_tree().create_timer(0.3).timeout
		GameManager.network_manager.sair()

func _ao_alterar_conexao(_mensagem: String, permitir_nova_tentativa: bool) -> void:
	if not permitir_nova_tentativa or not _concluindo:
		return
	var chat := $PartidaRede/ChatPartida
	_verificar(not chat.visible and chat._historico.is_empty(), "Chat não foi limpo ao sair da sala")
	if not _falhou:
		print("PASSOU: chat na sala e partida, autor, recusas privadas, texto literal e desconexão; papel ", _papel)
		get_tree().quit()

func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhar(mensagem)

func _falhar(mensagem: String) -> void:
	_falhou = true
	push_error(mensagem)
	get_tree().quit(1)
