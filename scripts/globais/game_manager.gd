extends Node

@onready var event_bus: BarramentoEventos = $EventBus
@onready var network_manager: GerenciadorRede = $NetworkManager
@onready var match_endpoint: EndpointPartida = $MatchEndpoint

func _ready() -> void:
	match_endpoint.configurar(network_manager, event_bus)
	network_manager.jogador_registrado.connect(match_endpoint.registrar_jogador)
	network_manager.cliente_pronto.connect(match_endpoint.iniciar_partida)
	network_manager.identidade_confirmada.connect(_ao_confirmar_identidade)
	network_manager.status_alterado.connect(_ao_alterar_status)
	event_bus.comando_solicitado.connect(match_endpoint.enviar_comando)

func _ao_confirmar_identidade(id_jogador: int) -> void:
	event_bus.identidade_definida.emit(id_jogador)

func _ao_alterar_status(mensagem: String, permitir_nova_tentativa: bool) -> void:
	event_bus.estado_conexao.emit(mensagem, permitir_nova_tentativa)
