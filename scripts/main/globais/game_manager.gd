extends Node

signal volume_musica_menu_alterado(volume: float)

var _volume_musica_menu: float = 0.25

@onready var event_bus: BarramentoEventos = $EventBus
@onready var network_manager: GerenciadorRede = $NetworkManager
@onready var match_endpoint: EndpointPartida = $MatchEndpoint
@onready var chat_endpoint: EndpointChat = $ChatEndpoint
@onready var _musica_menu: AudioStreamPlayer = $MusicaMenu
@onready var online: CentralSalas = $Online/CentralSalas

func _ready() -> void:
	# Cópia para repetir só no menu, preservando o recurso usado nos laboratórios.
	var musica := _musica_menu.stream.duplicate() as AudioStreamOggVorbis
	musica.loop = true
	_musica_menu.stream = musica
	if OS.has_feature("web"):
		_musica_menu.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_musica_menu.volume_linear = _volume_musica_menu
	match_endpoint.configurar(network_manager, event_bus)
	chat_endpoint.configurar(network_manager, event_bus)
	network_manager.configurar_central(online)
	online.evento_partida.connect(event_bus.evento_partida.emit)
	online.erro_comando.connect(event_bus.erro_comando.emit)
	online.mensagem_chat_recebida.connect(event_bus.mensagem_chat_recebida.emit)
	online.erro_chat.connect(event_bus.erro_chat.emit)
	network_manager.partida_interrompida.connect(match_endpoint.interromper)
	network_manager.partida_interrompida.connect(event_bus.partida_interrompida.emit)
	network_manager.sala_atualizada.connect(event_bus.sala_atualizada.emit)
	network_manager.identidade_confirmada.connect(_ao_confirmar_identidade)
	network_manager.status_alterado.connect(_ao_alterar_status)
	event_bus.comando_solicitado.connect(match_endpoint.enviar_comando)
	event_bus.mensagem_chat_solicitada.connect(chat_endpoint.enviar_mensagem)
	if modo_servidor():
		get_tree().change_scene_to_file.call_deferred("res://scenes/servidor/servidor_salas.tscn")

func modo_servidor() -> bool:
	return OS.has_feature("dedicated_server") or "--servidor" in OS.get_cmdline_user_args()

func definir_musica_menu(ativa: bool) -> void:
	if ativa:
		if not _musica_menu.playing:
			_musica_menu.play()
	else:
		_musica_menu.stop()

func obter_volume_musica_menu() -> float:
	return _volume_musica_menu

func definir_volume_musica_menu(volume: float) -> void:
	_volume_musica_menu = clampf(volume, 0.0, 1.0)
	_musica_menu.volume_linear = _volume_musica_menu
	volume_musica_menu_alterado.emit(_volume_musica_menu)

func _ao_confirmar_identidade(id_jogador: int) -> void:
	event_bus.identidade_definida.emit(id_jogador)

func _ao_alterar_status(mensagem: String, permitir_nova_tentativa: bool) -> void:
	event_bus.estado_conexao.emit(mensagem, permitir_nova_tentativa)
