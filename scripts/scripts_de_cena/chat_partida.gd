extends VBoxContainer

const LIMITE_HISTORICO := 50

var _historico: PackedStringArray = []
var _id_local: int = -1
var _nao_lidas: int = 0
var _enviando: bool = false

@onready var _abrir: Button = $Abrir
@onready var _conteudo: PanelContainer = $Conteudo
@onready var _mensagens: RichTextLabel = $Conteudo/Itens/Mensagens
@onready var _entrada: LineEdit = $Conteudo/Itens/Compor/Entrada
@onready var _enviar: Button = $Conteudo/Itens/Compor/Enviar
@onready var _erro: Label = $Conteudo/Itens/Erro

func _ready() -> void:
	hide()
	_entrada.max_length = EndpointChat.LIMITE_CARACTERES
	_abrir.toggled.connect(_ao_alternar_painel)
	_enviar.pressed.connect(_enviar_mensagem)
	_entrada.text_submitted.connect(_ao_confirmar_texto)
	GameManager.event_bus.identidade_definida.connect(_ao_definir_identidade)
	GameManager.event_bus.estado_conexao.connect(_ao_alterar_conexao)
	GameManager.event_bus.mensagem_chat_recebida.connect(_ao_receber_mensagem)
	GameManager.event_bus.erro_chat.connect(_ao_receber_erro)

func _ao_definir_identidade(id_jogador: int) -> void:
	_limpar()
	_id_local = id_jogador
	show()

func _ao_alterar_conexao(_mensagem: String, permitir_nova_tentativa: bool) -> void:
	if permitir_nova_tentativa:
		_limpar()
		hide()

func _limpar() -> void:
	_id_local = -1
	_historico.clear()
	_mensagens.clear()
	_entrada.clear()
	_erro.hide()
	_nao_lidas = 0
	_abrir.button_pressed = false
	_conteudo.hide()
	_abrir.text = "Chat"
	_liberar_envio()

func _ao_alternar_painel(aberto: bool) -> void:
	_conteudo.visible = aberto
	if aberto:
		_nao_lidas = 0
		_abrir.text = "Chat"
		_entrada.grab_focus()
	else:
		_entrada.release_focus()

func _ao_confirmar_texto(_texto: String) -> void:
	_enviar_mensagem()

func _enviar_mensagem() -> void:
	if _enviando:
		return
	if _entrada.text.strip_edges().is_empty():
		_ao_receber_erro("Digite uma mensagem.")
		return
	_erro.hide()
	_enviando = true
	_enviar.disabled = true
	_entrada.editable = false
	GameManager.event_bus.mensagem_chat_solicitada.emit(_entrada.text)

func _ao_receber_mensagem(mensagem: Dictionary) -> void:
	_historico.append("%s: %s" % [mensagem["nome"], mensagem["texto"]])
	if _historico.size() > LIMITE_HISTORICO:
		_historico.remove_at(0)
	_mensagens.text = "\n".join(_historico)
	if int(mensagem["jogador_id"]) == _id_local and _enviando:
		_entrada.clear()
		_liberar_envio()
	if not _conteudo.visible:
		_nao_lidas += 1
		_abrir.text = "Chat (%d)" % _nao_lidas

func _ao_receber_erro(mensagem: String) -> void:
	_liberar_envio()
	_erro.text = mensagem
	_erro.show()

func _liberar_envio() -> void:
	_enviando = false
	_enviar.disabled = false
	_entrada.editable = true
