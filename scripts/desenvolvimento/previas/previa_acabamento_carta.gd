extends Control

@export_enum("AZUL", "VERDE", "AMARELO", "VERMELHO", "PRETO") var cor_carta: String = "VERMELHO":
	set(valor):
		cor_carta = valor
		if is_node_ready():
			_configurar_cartas()

@export_group("Impressão experimental")
# Variação máxima nas áreas claras: 0.015 corresponde a 1.5%.
@export_range(0.0, 0.05, 0.001) var intensidade_claros: float = 0.015:
	set(valor):
		intensidade_claros = valor
		if is_node_ready():
			_atualizar_acabamento()

# Grão na tinta: 0.03 corresponde a 3%.
@export_range(0.0, 0.08, 0.001) var intensidade_tinta: float = 0.03:
	set(valor):
		intensidade_tinta = valor
		if is_node_ready():
			_atualizar_acabamento()

@export_group("Cobertura da tinta")
# Variação ampla e estática na tinta, independente das intensidades de grão.
@export_range(0.0, 0.15, 0.001) var variacao_tinta: float = 0.035:
	set(valor):
		variacao_tinta = valor
		if is_node_ready():
			_atualizar_acabamento()

# Tamanho das regiões em pixels da arte. Maior produz variações mais amplas.
@export_range(4.0, 48.0, 1.0) var escala_variacao: float = 18.0:
	set(valor):
		escala_variacao = valor
		if is_node_ready():
			_atualizar_acabamento()

@onready var _original: Carta = $CartaOriginal
@onready var _experimento: Carta = $CartaAcabamento


func _ready() -> void:
	_configurar_cartas()
	for carta in [_original, _experimento]:
		carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carta.verso = false
	resized.connect(_posicionar_cartas)
	_posicionar_cartas()


func _configurar_cartas() -> void:
	var dados := {"id": 1, "cor": cor_carta, "valor": "7"}
	_original.setup_dados(dados)
	_experimento.setup_dados(dados)
	_atualizar_acabamento()


func _atualizar_acabamento() -> void:
	_original.definir_acabamento(0.0, 0.0)
	_experimento.definir_acabamento(intensidade_claros, intensidade_tinta, variacao_tinta, escala_variacao)


func _posicionar_cartas() -> void:
	_original.position = size * Vector2(0.35, 0.5) - Carta.SIZE / 2.0
	_experimento.position = size * Vector2(0.65, 0.5) - Carta.SIZE / 2.0
