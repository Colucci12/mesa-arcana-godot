extends Node2D
class_name MesaVisual

const TAMANHO_PLANO := Vector2(1000, 700)

@export_group("Formato do tampo")
@export_enum("Retangular", "Arredondado") var formato := 0
# Zero usa o tamanho do plano; o contorno pode crescer sem mudar a câmera.
@export var dimensoes_tampo := Vector2.ZERO
var tamanho_plano := TAMANHO_PLANO

@export_group("Perspectiva")
@export_range(200.0, 1600.0, 10.0) var largura_proxima := 1000.0
@export_range(60.0, 900.0, 5.0) var profundidade_aparente := 420.0
@export_range(0.15, 1.0, 0.01) var largura_distante := 0.56
@export_group("Bordas")
@export_range(0.0, 120.0, 1.0) var largura_moldura := 36.0
@export_range(0.0, 100.0, 1.0) var espessura := 28.0
@onready var _plano: TextureRect = $PlanoMesa
@onready var _espessura: Polygon2D = $Espessura
@onready var _viewport: SubViewport = $PlanoViewport
@onready var _superficie: ColorRect = $PlanoViewport/Conteudo/Superficie


func _ready() -> void:
	_plano.texture = _viewport.get_texture()
	atualizar_visual()


func atualizar_visual() -> void:
	var retangulo := obter_retangulo_plano()
	_viewport.size_2d_override = Vector2i(retangulo.size.ceil())
	_viewport.size = Vector2i(retangulo.size.ceil() * 1.5)
	$PlanoViewport/Conteudo.position = -retangulo.position
	_superficie.position = retangulo.position
	_superficie.size = retangulo.size
	var projecao := matriz_projecao_plano()
	var limites := Rect2(_projetar_ponto(retangulo.position), Vector2.ZERO)
	for canto in [retangulo.position + Vector2(retangulo.size.x, 0), retangulo.end,
		retangulo.position + Vector2(0, retangulo.size.y)]:
		limites = limites.expand(_projetar_ponto(canto))
	_plano.position = limites.position
	_plano.size = limites.size
	var material_projecao := _plano.material as ShaderMaterial
	var inversa := projecao.inverse()
	for indice in range(3):
		material_projecao.set_shader_parameter(["inversa_x", "inversa_y", "inversa_z"][indice],
			Vector3(inversa.x[indice], inversa.y[indice], inversa.z[indice]))
	material_projecao.set_shader_parameter("origem_retangulo", limites.position)
	material_projecao.set_shader_parameter("tamanho_plano", tamanho_plano)
	material_projecao.set_shader_parameter("origem_captura", retangulo.position)
	material_projecao.set_shader_parameter("tamanho_captura", retangulo.size)
	var material_superficie := _superficie.material as ShaderMaterial
	material_superficie.set_shader_parameter("tamanho_plano", tamanho_plano)
	material_superficie.set_shader_parameter("origem_captura", retangulo.position)
	material_superficie.set_shader_parameter("tamanho_captura", retangulo.size)
	material_superficie.set_shader_parameter("arredondada", formato == 1)
	material_superficie.set_shader_parameter("dimensoes_tampo", obter_dimensoes_tampo())
	material_superficie.set_shader_parameter("largura_moldura", largura_moldura)
	material_superficie.set_shader_parameter("mostrar_grade", false)
	var frente := PackedVector2Array()
	var tamanho := obter_dimensoes_tampo()
	if formato == 1:
		# Extremos laterais da elipse já projetada; só o arco frontal recebe espessura.
		var k := 1.0 - largura_distante
		var lateral := asin(clampf(k * tamanho.y / (2.0 * tamanho_plano.y) / (1.0 - k / 2.0), 0.0, 0.999))
		for indice in range(65):
			var angulo := lerpf(lateral, PI - lateral, indice / 64.0)
			frente.append(_projetar_ponto(tamanho_plano / 2.0 + Vector2(cos(angulo), sin(angulo)) * tamanho / 2.0))
	else:
		frente.append(_projetar_ponto(tamanho_plano / 2.0 + tamanho / 2.0))
		frente.append(_projetar_ponto(tamanho_plano / 2.0 + Vector2(-tamanho.x, tamanho.y) / 2.0))
	var vertices := frente.duplicate()
	for indice in range(frente.size() - 1, -1, -1):
		vertices.append(frente[indice] + Vector2(0, espessura))
	_espessura.polygon = vertices
	_espessura.visible = espessura > 0.0


func definir_tamanho_plano(tamanho: Vector2) -> void:
	tamanho_plano = tamanho
	atualizar_visual()


func obter_materiais_apresentacao() -> Array[ShaderMaterial]:
	return [_plano.material as ShaderMaterial, _espessura.material as ShaderMaterial]


func obter_dimensoes_tampo() -> Vector2:
	return dimensoes_tampo if dimensoes_tampo.x > 0.0 and dimensoes_tampo.y > 0.0 else tamanho_plano


func obter_retangulo_plano() -> Rect2:
	var tamanho := obter_dimensoes_tampo()
	return Rect2(Vector2.ZERO, tamanho_plano).merge(Rect2((tamanho_plano - tamanho) / 2.0, tamanho))


func matriz_projecao_plano() -> Basis:
	var k := 1.0 - largura_distante
	var w := largura_proxima
	var h := profundidade_aparente
	return Basis(Vector3(w * largura_distante, 0, 0),
		Vector3(0, h * (largura_distante + k / 2.0), -k),
		Vector3(-w * largura_distante / 2.0, -h / 2.0, 1))


func _projetar_ponto(ponto: Vector2) -> Vector2:
	var q := matriz_projecao_plano() * Vector3(ponto.x / tamanho_plano.x, ponto.y / tamanho_plano.y, 1)
	return Vector2(q.x, q.y) / q.z


func configurar_recorte_sombra(material: ShaderMaterial) -> void:
	material.set_shader_parameter("margem_feltro", Vector2.ONE * largura_moldura / tamanho_plano)
	material.set_shader_parameter("mesa_arredondada", formato == 1)
	material.set_shader_parameter("raios_feltro", (obter_dimensoes_tampo() / 2.0 - Vector2.ONE * largura_moldura) / tamanho_plano)


func contem_feltro(ponto: Vector2) -> bool:
	var raios := obter_dimensoes_tampo() / 2.0 - Vector2.ONE * largura_moldura
	if raios.x <= 0 or raios.y <= 0:
		return false
	var local := (ponto - tamanho_plano / 2.0) / raios
	return local.length_squared() <= 1.0 if formato == 1 else absf(local.x) <= 1.0 and absf(local.y) <= 1.0
