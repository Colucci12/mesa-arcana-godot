extends Node

var _papel: int = 0
var _porta: int = 19994
var _id_local: int = -1
var _partidas: int = 0
var _entregas: int = 0
var _mensagens_chat: int = 0
var _interrupcoes: int = 0
var _iniciando: bool = false
var _falhou: bool = false

func _ready() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("papel="):
			_papel = argumento.trim_prefix("papel=").to_int()
		if argumento.begins_with("porta="):
			_porta = argumento.trim_prefix("porta=").to_int()
	$PartidaRede/MesaPartida.intervalo_entre_cartas = 0.001
	var bus := GameManager.event_bus
	bus.identidade_definida.connect(func(id: int): _id_local = id)
	bus.sala_atualizada.connect(_sala)
	bus.evento_partida.connect(_evento)
	bus.partida_interrompida.connect(_interrompida)
	bus.erro_comando.connect(_falhar)
	bus.mensagem_chat_recebida.connect(_ao_receber_chat)
	get_tree().create_timer(25.0).timeout.connect(func(): _falhar("Tempo esgotado"))
	var resultado: Dictionary
	if _papel == 0:
		resultado = GameManager.network_manager.hospedar("Teste0", _porta)
	else:
		resultado = GameManager.network_manager.entrar("Teste%d" % _papel, "127.0.0.1", _porta)
	if not resultado["sucesso"]:
		_falhar(resultado["mensagem"])

func _sala(jogadores: Array, pode_iniciar: bool) -> void:
	if _papel == 0 and jogadores.size() == 4 and pode_iniciar and not _iniciando:
		_iniciando = true
		GameManager.chat_endpoint.enviar_mensagem("Sala com quatro")
		GameManager.match_endpoint.iniciar_partida.call_deferred()

func _ao_receber_chat(mensagem: Dictionary) -> void:
	_mensagens_chat += 1
	if mensagem["jogador_id"] != 1 or mensagem["nome"] != "Teste0" or mensagem["texto"] != "Sala com quatro":
		_falhar("Mensagem do chat não corresponde ao anfitrião")

func _evento(evento: Dictionary) -> void:
	var publico: Dictionary = evento["publico"]
	match evento["tipo"]:
		"PartidaIniciada":
			_partidas += 1
			if _mensagens_chat != _partidas:
				_falhar("O chat não chegou a todos antes de iniciar a partida")
			_entregas = 0
			if publico["jogadores"].size() != 4:
				_falhar("Quantidade de jogadores incorreta")
		"CartaRecebida":
			_entregas += 1
			var tem_carta: bool = evento["privado"].has("carta")
			if tem_carta != (int(publico["jogador_id"]) == _id_local):
				_falhar("Dados privados enviados ao destinatário errado")
		"DistribuicaoConcluida":
			_validar_distribuicao()

func _validar_distribuicao() -> void:
	await get_tree().create_timer(0.8).timeout
	if _entregas != 28:
		_falhar("Esperava 28 entregas individuais")
	var tela: TelaMesa = $PartidaRede/MesaPartida
	if tela._maos.size() != 4:
		_falhar("A tela não mostra quatro mãos")
	for id in tela._maos:
		var mao: MaoVisual = tela._maos[id]
		if mao.quantidade_cartas() != 7:
			_falhar("Quantidade visual da mão incorreta")
		for carta in mao.obter_cartas():
			if carta.verso != (id != _id_local):
				_falhar("Orientação da carta incorreta")
	if _papel == 3 and _partidas == 1:
		var id_anterior := _id_local
		GameManager.network_manager.sair()
		await get_tree().create_timer(1.0).timeout
		GameManager.network_manager.entrar("Teste3", "127.0.0.1", _porta)
		await get_tree().create_timer(0.4).timeout
		if _id_local == id_anterior:
			_falhar("Uma nova entrada reutilizou o ID antigo")
	if _papel == 0 and _partidas == 2:
		await get_tree().create_timer(1.0).timeout
		GameManager.network_manager.sair()
		_concluir()

func _interrompida(_motivo: String) -> void:
	_interrupcoes += 1
	_iniciando = false
	if _papel != 0 and _partidas == 2:
		_concluir()

func _concluir() -> void:
	if _falhou:
		return
	if _interrupcoes < 2:
		_falhar("Faltou notificação de desconexão")
		return
	print("PASSOU: rede, privacidade, quatro mãos e desconexões; papel ", _papel)
	get_tree().quit()

func _falhar(mensagem: String) -> void:
	_falhou = true
	push_error(mensagem)
	get_tree().quit(1)
