extends Node2D
class_name MesaVisual

const TAMANHO_PLANO := Vector2(1000, 700)
const CENA_CARTA = preload("res://scenes/main/componentes/carta.tscn")

@export_group("Perspectiva")
@export_range(200.0, 1600.0, 10.0) var largura_proxima := 1000.0
@export_range(60.0, 900.0, 5.0) var profundidade_aparente := 420.0
@export_range(0.15, 1.0, 0.01) var largura_distante := 0.56
@export_group("Bordas")
@export_range(0.0, 120.0, 1.0) var largura_moldura := 36.0
@export_range(0.0, 100.0, 1.0) var espessura := 28.0
@export_group("Referências visuais")
@export var mostrar_grade := false
@export var mostrar_cartas := false

@onready var _plano: TextureRect = $PlanoMesa
@onready var _espessura: Polygon2D = $Espessura
@onready var _viewport: SubViewport = $PlanoViewport
@onready var _superficie: ColorRect = $PlanoViewport/Conteudo/Superficie
@onready var _referencias: Node2D = $PlanoViewport/Conteudo/Referencias


func _ready() -> void:
	_plano.texture = _viewport.get_texture()
	_montar_referencias()
	atualizar_visual()


func configurar_visual(ajustes: Dictionary, grade: bool, cartas: bool) -> void:
	largura_proxima = float(ajustes.get("largura", largura_proxima))
	profundidade_aparente = float(ajustes.get("profundidade", profundidade_aparente))
	largura_distante = float(ajustes.get("largura_distante", largura_distante * 100.0)) / 100.0
	largura_moldura = float(ajustes.get("moldura", largura_moldura))
	espessura = float(ajustes.get("espessura", espessura))
	rotation_degrees = float(ajustes.get("giro", rotation_degrees))
	mostrar_grade = grade
	mostrar_cartas = cartas
	atualizar_visual()


func atualizar_visual() -> void:
	var dimensoes := Vector2(largura_proxima, profundidade_aparente)
	_plano.position = -dimensoes / 2.0
	_plano.size = dimensoes
	(_plano.material as ShaderMaterial).set_shader_parameter("largura_distante", largura_distante)
	var material_superficie := _superficie.material as ShaderMaterial
	material_superficie.set_shader_parameter("largura_moldura", largura_moldura)
	material_superficie.set_shader_parameter("mostrar_grade", mostrar_grade)
	_referencias.visible = mostrar_cartas
	var esquerda := Vector2(-largura_proxima / 2.0, profundidade_aparente / 2.0)
	var direita := Vector2(largura_proxima / 2.0, profundidade_aparente / 2.0)
	_espessura.polygon = PackedVector2Array([
		esquerda, direita, direita + Vector2(0, espessura), esquerda + Vector2(0, espessura)
	])
	_espessura.visible = espessura > 0.0


func _montar_referencias() -> void:
	for indice in range(2):
		var carta := CENA_CARTA.instantiate() as Carta
		_referencias.add_child(carta)
		carta.setup_dados({"id": indice + 1, "cor": "VERDE" if indice == 0 else "VERMELHO", "valor": "3" if indice == 0 else "7"})
		carta.SCALE = Vector2(1.5, 1.5)
		carta.definir_hover_habilitado(false)
		carta.definir_sombra_visivel(false)
		carta.verso = false
		var centro := TAMANHO_PLANO * Vector2(0.5, 0.25 if indice == 0 else 0.75)
		carta.teleportar(centro - Carta.SIZE / 2.0)
