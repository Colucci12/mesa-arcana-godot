extends Control

const CENA_CARTA = preload("res://scenes/main/componentes/carta.tscn")
const REFERENCIA := Vector2(1280, 720)
const TAMANHO_PLANO := Vector2(1000, 700)
const CORES = ["VERMELHO", "AZUL", "VERDE", "AMARELO"]

@export_group("Plano da mesa")
@export var area_mesa := Rect2(100, 205, 1080, 365)
@export_range(0.35, 0.85, 0.01) var largura_distante: float = 0.56
@export_range(0.0, 60.0, 1.0) var espessura_borda: float = 24.0
@export var centro_monte := Vector2(0.41, 0.65)
@export var centro_descarte := Vector2(0.59, 0.65)

@export_group("Mão próxima")
@export var posicao_mao_inferior := Vector2(640, 615)
@export var escala_mao_inferior := Vector2(1.25, 1.25)

@export_group("Mão distante")
@export var posicao_mao_superior := Vector2(640, 140)
@export var escala_mao_superior := Vector2(0.65, 0.65)

@export_group("Mãos laterais")
@export var posicao_mao_esquerda := Vector2(230, 385)
@export var posicao_mao_direita := Vector2(1050, 385)
@export var escala_maos_laterais := Vector2(0.8, 0.72)
@export_range(25.0, 80.0, 1.0) var rotacao_laterais: float = 55.0
@export_range(0.0, 20.0, 1.0) var inclinacao_laterais: float = 8.0

@onready var _composicao: Node2D = $Composicao
@onready var _plano: TextureRect = $Composicao/PlanoMesa
@onready var _borda: Polygon2D = $Composicao/BordaMesa
@onready var _monte: MonteVisual = $PlanoViewport/Conteudo/Monte
@onready var _descarte: DescarteVisual = $PlanoViewport/Conteudo/Descarte
@onready var _maos: Array[MaoVisual] = [
	$Composicao/MaoInferior/Leque,
	$Composicao/MaoSuperior/Leque,
	$Composicao/MaoEsquerda/Leque,
	$Composicao/MaoDireita/Leque
]


func _ready() -> void:
	_plano.texture = $PlanoViewport.get_texture()
	_atualizar_composicao()
	_montar_maos()
	_montar_descarte()
	resized.connect(_ajustar_enquadramento)
	_ajustar_enquadramento()


func _ajustar_enquadramento() -> void:
	var fator := minf(size.x / REFERENCIA.x, size.y / REFERENCIA.y)
	_composicao.scale = Vector2.ONE * fator
	_composicao.position = (size - REFERENCIA * fator) / 2.0


func _atualizar_composicao() -> void:
	_plano.position = area_mesa.position
	_plano.size = area_mesa.size
	(_plano.material as ShaderMaterial).set_shader_parameter("largura_distante", largura_distante)
	var esquerda := area_mesa.position + Vector2(0, area_mesa.size.y)
	var direita := area_mesa.end
	_borda.polygon = PackedVector2Array([
		esquerda, direita,
		direita + Vector2(0, espessura_borda), esquerda + Vector2(0, espessura_borda)
	])
	_monte.position = centro_monte * TAMANHO_PLANO - _monte.size / 2.0
	_descarte.position = centro_descarte * TAMANHO_PLANO - _descarte.size / 2.0
	_configurar_mao($Composicao/MaoInferior, posicao_mao_inferior, escala_mao_inferior, 0.0)
	_configurar_mao($Composicao/MaoSuperior, posicao_mao_superior, escala_mao_superior, 180.0)
	_configurar_mao($Composicao/MaoEsquerda, posicao_mao_esquerda, escala_maos_laterais, rotacao_laterais)
	_configurar_mao($Composicao/MaoDireita, posicao_mao_direita, escala_maos_laterais, -rotacao_laterais)
	$Composicao/MaoEsquerda.skew = deg_to_rad(inclinacao_laterais)
	$Composicao/MaoDireita.skew = -deg_to_rad(inclinacao_laterais)


func _configurar_mao(grupo: Node2D, centro: Vector2, escala: Vector2, angulo: float) -> void:
	grupo.position = centro
	grupo.scale = escala
	grupo.rotation_degrees = angulo
	var mao := grupo.get_node("Leque") as MaoVisual
	mao.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mao.custom_minimum_size = Vector2(500, 140)
	mao.size = Vector2(500, 140)
	mao.position = Vector2(-250, -47.5)
	mao.pivot_offset = Vector2(250, 47.5)
	mao.rotacao_max_graus = 9
	mao.offset_max = -28
	mao.separacao = -4
	mao.color = Color.TRANSPARENT
	mao.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _montar_maos() -> void:
	for indice_mao in range(_maos.size()):
		var mao := _maos[indice_mao]
		for indice in range(7):
			var carta := _criar_carta(mao, indice_mao * 7 + indice + 1, CORES[(indice_mao + indice) % CORES.size()], str(indice + 1))
			# As mãos estão à frente/ao redor da mesa, sem sombra de contato nela.
			carta.definir_sombra_visivel(false)
			if indice_mao != 0:
				carta.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _montar_descarte() -> void:
	for indice in range(3):
		var carta := _criar_carta($PlanoViewport/Conteudo, 29 + indice, CORES[indice], str(7 + indice))
		_descarte.receber_carta(carta)


func _criar_carta(destino: Node, id: int, cor: String, valor: String) -> Carta:
	var carta := CENA_CARTA.instantiate() as Carta
	if destino is CanvasItem:
		carta.posicao = (destino as CanvasItem).get_global_transform() * Vector2(250, 47.5)
	if destino is MaoVisual:
		destino.receber_carta(carta)
	else:
		destino.add_child(carta)
	carta.setup_dados({"id": id, "cor": cor, "valor": valor})
	return carta
