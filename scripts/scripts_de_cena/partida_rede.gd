extends Control

@onready var _tela: TelaMesa = $MesaPartida
@onready var _painel: PanelContainer = $PainelConexao
@onready var _nome: LineEdit = $PainelConexao/Conteudo/Nome
@onready var _ip: LineEdit = $PainelConexao/Conteudo/IP
@onready var _porta: LineEdit = $PainelConexao/Conteudo/Porta
@onready var _botao_hospedar: Button = $PainelConexao/Conteudo/Acoes/Hospedar
@onready var _botao_entrar: Button = $PainelConexao/Conteudo/Acoes/Entrar
@onready var _status: Label = $PainelConexao/Conteudo/Status

func _ready() -> void:
	_tela.hide()
	_botao_hospedar.pressed.connect(_hospedar)
	_botao_entrar.pressed.connect(_entrar)
	_tela.comando_solicitado.connect(_enviar_comando)
	GameManager.event_bus.evento_partida.connect(_ao_receber_evento)
	GameManager.event_bus.erro_comando.connect(_ao_receber_erro)
	GameManager.event_bus.identidade_definida.connect(_ao_definir_identidade)
	GameManager.event_bus.estado_conexao.connect(_ao_alterar_status)

func _hospedar() -> void:
	var porta := _obter_porta()
	if porta == -1:
		return
	var resultado := GameManager.network_manager.hospedar(_nome.text, porta)
	if resultado["sucesso"]:
		_bloquear_formulario()
	else:
		_status.text = resultado["mensagem"]

func _entrar() -> void:
	var porta := _obter_porta()
	if porta == -1:
		return
	var resultado := GameManager.network_manager.entrar(_nome.text, _ip.text, porta)
	if resultado["sucesso"]:
		_bloquear_formulario()
	else:
		_status.text = resultado["mensagem"]

func _obter_porta() -> int:
	if not _porta.text.is_valid_int():
		_status.text = "Informe uma porta válida."
		return -1
	var porta := int(_porta.text)
	if porta < 1 or porta > 65535:
		_status.text = "A porta deve estar entre 1 e 65535."
		return -1
	return porta

func _bloquear_formulario() -> void:
	_nome.editable = false
	_ip.editable = false
	_porta.editable = false
	_botao_hospedar.disabled = true
	_botao_entrar.disabled = true

func _liberar_formulario() -> void:
	_nome.editable = true
	_ip.editable = true
	_porta.editable = true
	_botao_hospedar.disabled = false
	_botao_entrar.disabled = false

func _enviar_comando(comando: StringName, dados: Dictionary) -> void:
	GameManager.event_bus.comando_solicitado.emit(comando, dados)

func _ao_receber_evento(evento: Dictionary) -> void:
	if evento.get("tipo", "") == "PartidaIniciada":
		_painel.hide()
		_tela.show()
	_tela.aplicar_eventos([evento])

func _ao_receber_erro(mensagem: String) -> void:
	if _tela.visible:
		_tela.mostrar_erro(mensagem)
	else:
		_status.text = mensagem

func _ao_definir_identidade(id_jogador: int) -> void:
	_tela.id_jogador_local = id_jogador

func _ao_alterar_status(mensagem: String, permitir_nova_tentativa: bool) -> void:
	if _tela.visible:
		if permitir_nova_tentativa:
			_tela.interromper_partida(mensagem)
	else:
		_status.text = mensagem
		if permitir_nova_tentativa:
			_liberar_formulario()
