extends Control

const TEMA = preload("res://scripts/main/componentes/tema_menu.gd")
const VISUAL_PARTIDA = preload("res://scripts/main/componentes/tema_partida.gd")

@onready var _tela: TelaMesa = $MesaPartida
@onready var _apresentacao: Control = $ApresentacaoSala
@onready var _painel: VBoxContainer = $ApresentacaoSala/Conteudo/PainelConexao/Conteudo
@onready var _formulario: VBoxContainer = _painel.get_node("Formulario")
@onready var _resumo: VBoxContainer = _painel.get_node("Resumo")
@onready var _nome: LineEdit = _formulario.get_node("Nome")
@onready var _ip: LineEdit = _formulario.get_node("Endereco/IPGrupo/IP")
@onready var _porta: LineEdit = _formulario.get_node("Endereco/PortaGrupo/Porta")
@onready var _modo_criar: Button = _formulario.get_node("Modo/Criar")
@onready var _modo_entrar: Button = _formulario.get_node("Modo/Entrar")
@onready var _botao_hospedar: Button = _formulario.get_node("Acoes/Hospedar")
@onready var _botao_entrar: Button = _formulario.get_node("Acoes/Entrar")
@onready var _status: Label = _painel.get_node("Status")
@onready var _enderecos: OptionButton = _resumo.get_node("Enderecos")
@onready var _sala: VBoxContainer = $ApresentacaoSala/Conteudo/PainelSala/Conteudo
@onready var _iniciar: Button = _sala.get_node("Iniciar")
@onready var _jogadores: Label = _sala.get_node("Jogadores")
@onready var _espera: Label = _sala.get_node("Espera")
@onready var _vagas: VBoxContainer = _sala.get_node("Vagas")

var _criando_sala := true
var _lugares: Array[Dictionary] = []


func _ready() -> void:
	GameManager.definir_musica_menu(true)
	_ajustar_controles_sala(true)
	var tema := TEMA.tema()
	_apresentacao.theme = tema
	for botao in [$Sair, $VoltarSala, $VoltarMenu]:
		botao.theme = tema
	VISUAL_PARTIDA.aplicar_chat($ChatPartida)
	$VoltarSala.theme = VISUAL_PARTIDA.tema()
	$VoltarSala.theme_type_variation = &"AcaoPartida"
	_tela.hide()
	_criar_lugares()
	_modo_criar.pressed.connect(_selecionar_modo.bind(true))
	_modo_entrar.pressed.connect(_selecionar_modo.bind(false))
	_botao_hospedar.pressed.connect(_hospedar)
	_botao_entrar.pressed.connect(_entrar)
	for campo in [_nome, _ip, _porta]:
		campo.text_submitted.connect(_confirmar_formulario)
	_resumo.get_node("Copiar").pressed.connect(_copiar_endereco)
	_tela.comando_solicitado.connect(_enviar_comando)
	GameManager.event_bus.evento_partida.connect(_ao_receber_evento)
	GameManager.event_bus.erro_comando.connect(_ao_receber_erro)
	GameManager.event_bus.identidade_definida.connect(_ao_definir_identidade)
	GameManager.event_bus.estado_conexao.connect(_ao_alterar_status)
	GameManager.event_bus.sala_atualizada.connect(_ao_atualizar_sala)
	GameManager.event_bus.partida_interrompida.connect(_ao_interromper_partida)
	_iniciar.pressed.connect(GameManager.match_endpoint.iniciar_partida)
	$Sair.pressed.connect(GameManager.network_manager.sair)
	$VoltarSala.pressed.connect(_voltar_sala)
	$VoltarMenu.pressed.connect(_voltar_menu)
	_selecionar_modo(true)
	_nome.grab_focus.call_deferred()


func _selecionar_modo(criar: bool) -> void:
	_criando_sala = criar
	_modo_criar.set_pressed_no_signal(criar)
	_modo_entrar.set_pressed_no_signal(not criar)
	_formulario.get_node("Endereco/IPGrupo").visible = not criar
	_botao_hospedar.visible = criar
	_botao_entrar.visible = not criar
	_painel.get_node("Titulo").text = "Crie uma sala" if criar else "Entre em uma sala"
	_painel.get_node("Instrucao").text = "Convide até três amigos para jogar." if criar else "Use o endereço recebido do anfitrião."
	_mostrar_status("Você pode reunir de 2 a 4 jogadores.")


func _confirmar_formulario(_texto: String) -> void:
	if _criando_sala and not _botao_hospedar.disabled:
		_hospedar()
	elif not _criando_sala and not _botao_entrar.disabled:
		_entrar()


func _hospedar() -> void:
	var porta := _obter_porta()
	if porta == -1:
		return
	var resultado := GameManager.network_manager.hospedar(_nome.text, porta)
	if resultado["sucesso"]:
		_bloquear_formulario()
	else:
		_mostrar_status(resultado["mensagem"], true)


func _entrar() -> void:
	# Aceita também o IP:porta copiado pelo anfitrião, sem separar IPv6.
	var endereco := _ip.text.strip_edges()
	if endereco.count(":") == 1:
		var partes := endereco.split(":")
		if not partes[1].is_valid_int() or int(partes[1]) < 1 or int(partes[1]) > 65535 or partes[1].length() > 5:
			_mostrar_status("O endereço deve ter uma porta entre 1 e 65535.", true)
			return
		_ip.text = partes[0]
		_porta.text = partes[1]
	var porta := _obter_porta()
	if porta == -1:
		return
	var resultado := GameManager.network_manager.entrar(_nome.text, _ip.text, porta)
	if resultado["sucesso"]:
		_bloquear_formulario()
	else:
		_mostrar_status(resultado["mensagem"], true)


func _obter_porta() -> int:
	if not _porta.text.is_valid_int():
		_mostrar_status("Informe uma porta válida.", true)
		return -1
	var porta := int(_porta.text)
	if porta < 1 or porta > 65535:
		_mostrar_status("A porta deve estar entre 1 e 65535.", true)
		return -1
	return porta


func _bloquear_formulario() -> void:
	$Sair.show()
	$VoltarMenu.hide()
	_nome.editable = false
	_ip.editable = false
	_porta.editable = false
	_modo_criar.disabled = true
	_modo_entrar.disabled = true
	_botao_hospedar.disabled = true
	_botao_entrar.disabled = true
	if GameManager.network_manager.esta_conectado():
		_formulario.hide()
		_resumo.show()
		_atualizar_resumo()


func _liberar_formulario() -> void:
	$Sair.hide()
	$VoltarMenu.show()
	_iniciar.hide()
	_resumo.hide()
	_formulario.show()
	_enderecos.clear()
	_tela.id_jogador_local = -1
	_jogadores.text = "Quatro lugares. Uma boa companhia."
	_espera.text = "Uma partida começa com pelo menos 2 jogadores."
	_nome.editable = true
	_ip.editable = true
	_porta.editable = true
	_modo_criar.disabled = false
	_modo_entrar.disabled = false
	_botao_hospedar.disabled = false
	_botao_entrar.disabled = false
	_painel.get_node("Titulo").text = "Crie uma sala" if _criando_sala else "Entre em uma sala"
	_painel.get_node("Instrucao").text = "Convide até três amigos para jogar." if _criando_sala else "Use o endereço recebido do anfitrião."
	_atualizar_lugares([])
	_nome.grab_focus.call_deferred()


func _atualizar_resumo() -> void:
	var anfitriao := multiplayer.is_server()
	_painel.get_node("Titulo").text = "Sua sala está aberta" if anfitriao else "Você está na sala"
	_painel.get_node("Instrucao").text = "Compartilhe o endereço com seus amigos." if anfitriao else "Tudo pronto. Aguarde o início da partida."
	_resumo.get_node("Nome").text = _nome.text.strip_edges()
	_resumo.get_node("EnderecoLegenda").text = "ENDEREÇO PARA COMPARTILHAR" if anfitriao else "ENDEREÇO DO ANFITRIÃO"
	_resumo.get_node("Informacao").text = "Escolha o IP da rede dos seus amigos. Eles podem colar o endereço completo ao entrar.\nPorta: %s" % _porta.text if anfitriao else "A partida começa quando o anfitrião chamar a mesa.\nPorta: %s" % _porta.text
	if _enderecos.item_count > 0:
		return
	var enderecos: PackedStringArray = []
	if anfitriao:
		for endereco in IP.get_local_addresses():
			if endereco.is_valid_ip_address() and not endereco.contains(":") and not endereco.begins_with("127.") and not endereco.begins_with("169.254.") and endereco != "0.0.0.0":
				if not enderecos.has(endereco):
					if endereco.begins_with("192.168.") or endereco.begins_with("10."):
						enderecos.insert(0, endereco)
					else:
						enderecos.append(endereco)
		enderecos.append("127.0.0.1")
	else:
		enderecos.append(_ip.text.strip_edges())
	for endereco in enderecos:
		_enderecos.add_item("%s:%s" % [endereco, _porta.text])
	_enderecos.select(0)


func _copiar_endereco() -> void:
	if _enderecos.selected < 0:
		return
	DisplayServer.clipboard_set(_enderecos.get_item_text(_enderecos.selected))
	_mostrar_status("Endereço copiado! Envie para seus amigos.")


func _criar_lugares() -> void:
	for _indice in range(4):
		var linha := PanelContainer.new()
		linha.theme_type_variation = &"VagaSala"
		linha.custom_minimum_size.y = 44
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vagas.add_child(linha)
		var conteudo := HBoxContainer.new()
		conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(conteudo)
		var icone := TextureRect.new()
		icone.texture = TEMA.emblema()
		icone.custom_minimum_size = Vector2(28, 30)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		conteudo.add_child(icone)
		var nome := Label.new()
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.add_theme_font_size_override("font_size", 22)
		nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		conteudo.add_child(nome)
		var papel := Label.new()
		papel.add_theme_font_size_override("font_size", 14)
		papel.add_theme_color_override("font_color", TEMA.OURO)
		conteudo.add_child(papel)
		_lugares.append({"linha": linha, "nome": nome, "papel": papel})
	_atualizar_lugares([])


func _atualizar_lugares(jogadores: Array) -> void:
	for indice in range(_lugares.size()):
		var lugar: Dictionary = _lugares[indice]
		var ocupado := indice < jogadores.size()
		lugar["linha"].modulate = Color.WHITE if ocupado else Color(1, 1, 1, 0.45)
		if ocupado:
			var jogador: Dictionary = jogadores[indice]
			var id := int(jogador["id"])
			lugar["nome"].text = String(jogador["nome"])
			var papeis: PackedStringArray = []
			if id == _tela.id_jogador_local:
				papeis.append("VOCÊ")
			if id == 1:
				papeis.append("ANFITRIÃO")
			lugar["papel"].text = " · ".join(papeis) if not papeis.is_empty() else "CONVIDADO"
		else:
			lugar["nome"].text = "Lugar disponível"
			lugar["papel"].text = "%02d" % (indice + 1)


func _mostrar_status(mensagem: String, erro: bool = false) -> void:
	_status.text = mensagem
	_status.add_theme_color_override("font_color", Color("#eea49a") if erro else TEMA.OURO)


func _enviar_comando(comando: StringName, dados: Dictionary) -> void:
	GameManager.event_bus.comando_solicitado.emit(comando, dados)


func _ao_receber_evento(evento: Dictionary) -> void:
	if evento.get("tipo", "") == "PartidaIniciada":
		GameManager.definir_musica_menu(false)
		_ajustar_controles_sala(false)
		$VoltarSala.hide()
		_tela.interromper_partida("")
		_apresentacao.hide()
		$PlanoFundo.hide()
		_tela.show()
	if evento.get("tipo", "") == "PartidaEncerrada":
		$VoltarSala.show()
	_tela.aplicar_eventos([evento])


func _ao_receber_erro(mensagem: String) -> void:
	if _tela.visible:
		_tela.mostrar_erro(mensagem)
	else:
		_mostrar_status(mensagem, true)


func _ao_definir_identidade(id_jogador: int) -> void:
	_tela.id_jogador_local = id_jogador


func _ao_alterar_status(mensagem: String, permitir_nova_tentativa: bool) -> void:
	if permitir_nova_tentativa:
		_ao_interromper_partida(mensagem)
		_liberar_formulario()
	_mostrar_status(mensagem, permitir_nova_tentativa and mensagem != "Você saiu da sala.")


func _ao_atualizar_sala(jogadores: Array, pode_iniciar: bool) -> void:
	_atualizar_lugares(jogadores)
	_jogadores.text = "%d de 4 lugares ocupados" % jogadores.size()
	_iniciar.visible = multiplayer.is_server()
	_iniciar.disabled = not pode_iniciar
	_bloquear_formulario()
	if multiplayer.is_server():
		_espera.text = "A mesa está pronta. Pode começar!" if pode_iniciar else "Aguarde seus amigos para começar."
	else:
		_espera.text = "Aguardando o anfitrião começar a partida."
	_mostrar_status("Sala aberta. Convide seus amigos!" if multiplayer.is_server() else "Conectado. Seu lugar está reservado.")


func _ao_interromper_partida(motivo: String) -> void:
	_tela.interromper_partida(motivo)
	_voltar_sala()
	_mostrar_status(motivo)


func _voltar_sala() -> void:
	_tela.hide()
	GameManager.definir_musica_menu(true)
	_ajustar_controles_sala(true)
	_apresentacao.show()
	$PlanoFundo.show()
	$VoltarSala.hide()


func _ajustar_controles_sala(na_sala: bool) -> void:
	$VolumeMusica.visible = na_sala
	if not na_sala:
		$VolumeMusica.fechar_painel()
	# Chat no cabeçalho da sala; na partida conserva a posição original.
	$ChatPartida.offset_left = -424.0 if na_sala else -316.0
	$ChatPartida.offset_right = -124.0 if na_sala else -16.0
	$ChatPartida.anchor_top = 0.0 if na_sala else 1.0
	$ChatPartida.anchor_bottom = 0.0 if na_sala else 1.0
	$ChatPartida.offset_top = 76.0 if na_sala else -48.0
	$ChatPartida.offset_bottom = 108.0 if na_sala else -16.0
	$ChatPartida.grow_vertical = Control.GROW_DIRECTION_END if na_sala else Control.GROW_DIRECTION_BEGIN


func _voltar_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main/telas/menu_principal.tscn")
