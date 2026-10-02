extends Node2D

const FACE = preload("res://scripts/desenvolvimento/laboratorios/plano_mao_perspectiva.gdshader")
const SOMBRA = preload("res://scripts/desenvolvimento/laboratorios/sombra_mao_no_tampo.gdshader")
const SOMBRA_ENTRE_CARTAS = preload("res://scripts/desenvolvimento/laboratorios/sombra_entre_cartas.gdshader")
const CAPTURA := Vector2(224, 208)

var face: Polygon2D
var sombra: Polygon2D
var _captura: SubViewport
var _virada: Node2D
var _textura: TextureRect
var _carta: Carta
var regiao := Vector4(0, 0, 1, 1)
var tamanho_textura := CAPTURA
var _captura_pronta := true
var _sombras_recebidas: Dictionary = {}
var _sombras_ativas: Dictionary = {}


func _ready() -> void:
	sombra = _poligono(SOMBRA, 1)
	face = _poligono(FACE, 15)


func _poligono(shader: Shader, ordem: int) -> Polygon2D:
	var poligono := Polygon2D.new()
	poligono.z_index = ordem
	poligono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = shader
	poligono.material = material
	add_child(poligono)
	return poligono


func usar_textura(textura: Texture2D, dimensoes: Vector2, recorte: Vector4) -> void:
	face.texture = textura
	sombra.texture = textura
	tamanho_textura = dimensoes
	regiao = recorte


func capturar_carta(carta: Carta) -> void:
	_carta = carta
	_captura_pronta = false
	face.visible = false
	sombra.visible = false
	_captura = SubViewport.new()
	_captura.disable_3d = true
	_captura.gui_disable_input = true
	_captura.transparent_bg = true
	_captura.size = Vector2i(CAPTURA * 2.0)
	_captura.size_2d_override = Vector2i(CAPTURA)
	_captura.size_2d_override_stretch = true
	# Desenhar mesmo oculta para nunca exibir uma textura ainda não inicializada.
	_captura.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_captura)
	var centro := Node2D.new()
	centro.position = (CAPTURA - Carta.SIZE) / 2.0
	_captura.add_child(centro)
	_virada = Node2D.new()
	centro.add_child(_virada)
	_textura = TextureRect.new()
	_textura.position = Vector2(-8, -8)
	_textura.size = Carta.SIZE + Vector2.ONE * 16.0
	_textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_textura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_textura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_virada.add_child(_textura)
	usar_textura(_captura.get_texture(), CAPTURA, Vector4(0, 0, 1, 1))
	sincronizar_carta()
	RenderingServer.frame_post_draw.connect(_ao_desenhar_captura, CONNECT_ONE_SHOT)


func _ao_desenhar_captura() -> void:
	_captura_pronta = true
	_captura.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


func sincronizar_carta() -> void:
	if not is_instance_valid(_carta):
		return
	var aparencia := _carta.obter_apresentacao()
	_textura.texture = aparencia["textura"]
	_textura.material = aparencia["material"]
	_virada.transform = aparencia["virada"]


func _inversa(material: ShaderMaterial, matriz: Basis, prefixo: String) -> void:
	material.set_shader_parameter(prefixo + "_x", Vector3(matriz.x.x, matriz.y.x, matriz.z.x))
	material.set_shader_parameter(prefixo + "_y", Vector3(matriz.x.y, matriz.y.y, matriz.z.y))
	material.set_shader_parameter(prefixo + "_z", Vector3(matriz.x.z, matriz.y.z, matriz.z.z))


func _aplicar(poligono: Polygon2D, matriz: Basis) -> bool:
	var vertices := PackedVector2Array()
	for uv in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		var q: Vector3 = matriz * Vector3(uv.x, uv.y, 1)
		if q.z <= 0.00001:
			break
		vertices.append(Vector2(q.x, q.y) / q.z)
	poligono.visible = _captura_pronta and vertices.size() == 4 and absf(matriz.determinant()) > 0.00001
	if poligono.visible:
		poligono.polygon = vertices
		var material := poligono.material as ShaderMaterial
		_inversa(material, matriz.inverse(), "inversa")
		material.set_shader_parameter("regiao_textura", regiao)
	return poligono.visible


func apresentar(matriz: Basis) -> void:
	_aplicar(face, matriz)


func projetar_sombra(laboratorio: Node, plano: Dictionary, opacidade: float, intensidade: float = -1.0, suavidade: float = -1.0) -> void:
	sombra.visible = false
	if not _captura_pronta or opacidade <= 0.001 or not laboratorio._sombras_melhoradas.button_pressed:
		return
	var dimensoes := Vector2(laboratorio._mesa.tamanho_plano)
	var mesa: Basis = laboratorio._matriz_da_mesa(Vector3.ZERO,
		Vector3(dimensoes.x, 0, 0), Vector3(0, dimensoes.y, 0))
	var projecao: Basis = laboratorio._matriz_sombra(plano["ponto"], plano["u"], plano["v"])
	var retangulo: Rect2 = laboratorio._mesa.obter_retangulo_plano()
	var receptor: Basis = laboratorio._matriz_da_mesa(Vector3(retangulo.position.x, retangulo.position.y, 0),
		Vector3(retangulo.size.x, 0, 0), Vector3(0, retangulo.size.y, 0))
	if absf(projecao.determinant()) < 0.00001 or not _aplicar(sombra, receptor):
		return
	var material := sombra.material as ShaderMaterial
	_inversa(material, projecao.inverse(), "inversa")
	_inversa(material, mesa.inverse(), "mesa")
	var p: Vector3 = plano["ponto"]
	var u: Vector3 = plano["u"]
	var v: Vector3 = plano["v"]
	material.set_shader_parameter("altura_plano", Vector3(u.z, v.z, p.z))
	material.set_shader_parameter("tamanho_captura", tamanho_textura)
	laboratorio._mesa.configurar_recorte_sombra(material)
	material.set_shader_parameter("intensidade", (laboratorio.intensidade_sombra if intensidade < 0.0 else intensidade) * opacidade)
	material.set_shader_parameter("suavidade", laboratorio.suavidade_sombra if suavidade < 0.0 else suavidade)
	material.set_shader_parameter("suavidade_por_altura", laboratorio.suavidade_por_altura)
	material.set_shader_parameter("fonte_localizada", laboratorio.usar_fonte_localizada)
	material.set_shader_parameter("altura_fonte", laboratorio.posicao_fonte.z)


func iniciar_sombras_recebidas() -> void:
	_sombras_ativas.clear()
	for poligono in _sombras_recebidas.values():
		poligono.hide()


func _limites_projetados(matriz: Basis, margem: Vector2 = Vector2.ZERO) -> Rect2:
	var limites := Rect2()
	var cantos := [-margem, Vector2(1.0 + margem.x, -margem.y),
		Vector2.ONE + margem, Vector2(-margem.x, 1.0 + margem.y)]
	for indice in range(4):
		var uv: Vector2 = cantos[indice]
		var q := matriz * Vector3(uv.x, uv.y, 1)
		if q.z <= 0.00001:
			return Rect2()
		var ponto := Vector2(q.x, q.y) / q.z
		limites = Rect2(ponto, Vector2.ZERO) if indice == 0 else limites.expand(ponto)
	return limites


func receber_sombra(laboratorio: Node, plano: Dictionary, origem: Node2D, plano_origem: Dictionary,
		opacidade: float, intensidade: float, suavidade: float) -> bool:
	if origem == self or not _captura_pronta or not origem._captura_pronta or opacidade <= 0.001 or intensidade <= 0.001:
		return false
	if not laboratorio._sombras_melhoradas.button_pressed:
		return false
	var ponto: Vector3 = plano["ponto"]
	var u: Vector3 = plano["u"]
	var v: Vector3 = plano["v"]
	# Os receptores desta etapa são as cartas horizontais das duas pilhas.
	if absf(u.z) > 0.001 or absf(v.z) > 0.001:
		return false
	var p_origem: Vector3 = plano_origem["ponto"]
	var u_origem: Vector3 = plano_origem["u"]
	var v_origem: Vector3 = plano_origem["v"]
	var altura_maior := maxf(maxf(p_origem.z, (p_origem + u_origem).z), maxf((p_origem + v_origem).z, (p_origem + u_origem + v_origem).z))
	if altura_maior <= ponto.z + 0.01 or (laboratorio.usar_fonte_localizada and laboratorio.posicao_fonte.z <= ponto.z + 0.5):
		return false
	var receptor: Basis = laboratorio._matriz_da_mesa(ponto, u, v)
	var projecao: Basis = laboratorio._matriz_sombra(p_origem, u_origem, v_origem, ponto.z)
	if absf(projecao.determinant()) < 0.00001:
		return false
	var alcance := minf(suavidade + (altura_maior - ponto.z) * laboratorio.suavidade_por_altura, 20.0)
	var limites := _limites_projetados(projecao, Vector2.ONE * alcance / origem.tamanho_textura)
	if limites.has_area() and not limites.intersects(_limites_projetados(receptor)):
		return false
	var id := origem.get_instance_id()
	if not _sombras_recebidas.has(id):
		_sombras_recebidas[id] = _poligono(SOMBRA_ENTRE_CARTAS, face.z_index + 1)
	var poligono: Polygon2D = _sombras_recebidas[id]
	poligono.z_index = face.z_index + 1
	if not _aplicar(poligono, receptor):
		return false
	_sombras_ativas[id] = true
	var material := poligono.material as ShaderMaterial
	_inversa(material, projecao.inverse(), "inversa")
	_inversa(material, receptor.inverse(), "receptor")
	material.set_shader_parameter("textura_origem", origem.face.texture)
	material.set_shader_parameter("textura_receptor", face.texture)
	material.set_shader_parameter("regiao_origem", origem.regiao)
	material.set_shader_parameter("regiao_receptor", regiao)
	material.set_shader_parameter("altura_plano", Vector3(u_origem.z, v_origem.z, p_origem.z))
	material.set_shader_parameter("altura_receptor", ponto.z)
	material.set_shader_parameter("tamanho_captura", origem.tamanho_textura)
	material.set_shader_parameter("intensidade", intensidade * opacidade)
	material.set_shader_parameter("suavidade", suavidade)
	material.set_shader_parameter("suavidade_por_altura", laboratorio.suavidade_por_altura)
	material.set_shader_parameter("fonte_localizada", laboratorio.usar_fonte_localizada)
	material.set_shader_parameter("altura_fonte", laboratorio.posicao_fonte.z)
	return true


func concluir_sombras_recebidas() -> void:
	for id in _sombras_recebidas.keys():
		if not _sombras_ativas.has(id):
			_sombras_recebidas[id].queue_free()
			_sombras_recebidas.erase(id)
