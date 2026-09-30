extends Node

@onready var event_bus: BarramentoEventos = $EventBus
@onready var network_manager: GerenciadorRede = $NetworkManager
@onready var match_endpoint: EndpointPartida = $MatchEndpoint

func _ready() -> void:
	match_endpoint.configurar(network_manager, event_bus)
	network_manager.partida_interrompida.connect(match_endpoint.interromper)
	network_manager.partida_interrompida.connect(event_bus.partida_interrompida.emit)
	network_manager.sala_atualizada.connect(event_bus.sala_atualizada.emit)
	network_manager.identidade_confirmada.connect(_ao_confirmar_identidade)
	network_manager.status_alterado.connect(_ao_alterar_status)
	event_bus.comando_solicitado.connect(match_endpoint.enviar_comando)

func _ao_confirmar_identidade(id_jogador: int) -> void:
	event_bus.identidade_definida.emit(id_jogador)

func _ao_alterar_status(mensagem: String, permitir_nova_tentativa: bool) -> void:
	event_bus.estado_conexao.emit(mensagem, permitir_nova_tentativa)
