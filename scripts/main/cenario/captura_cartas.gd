extends Node2D

signal evento_audio(acao: String)

const CENA = preload("res://scenes/main/componentes/projecao_partida.tscn")
const PROJECAO = preload("res://scripts/main/cenario/projecao_partida.gd")
const LUZ = preload("res://scripts/main/cenario/luz_cenario.gd")
const REFERENCIA := Vector2(1280, 720)
const LIMITES_LUZ_MESA = PROJECAO.LIMITES_ILUMINACAO
const LIMITES := {"x": Vector2(-1280, 1280), "y": Vector2(-720, 720),
	"tamanho": Vector2(25, 200), "camada": Vector2(-100, 100)}

var _captura: SubViewport
var _apresentacao: PROJECAO
var _imagem: Sprite2D
var _assinatura := ""
var _assinatura_luz := ""
var _luz_mesa: Dictionary = {}
var _luz_ativa := false
var _transformacao := Transform2D.IDENTITY
var _interacao_ativa := false
var cena_apresentacao: PackedScene = CENA


static func padrao() -> Dictionary:
	return {"tipo": "mesa_perspectiva", "visivel": true, "mesa_visivel": true,
		"perfil": {}, "x": 0.0, "y": 0.0, "tamanho": 100.0, "camada": 35.0,
		"luz_mesa": luz_padrao()}


static func luz_padrao() -> Dictionary:
	var ajustes := PROJECAO.PADRAO_ILUMINACAO.duplicate()
	ajustes["ativa"] = false
	return ajustes


static func validar_luz(dados: Variant) -> Dictionary:
	var ajustes := LUZ.numeros(dados, luz_padrao(), PROJECAO.LIMITES_ILUMINACAO)
	if dados is Dictionary and dados.get("ativa") is bool:
		ajustes["ativa"] = dados["ativa"]
	return ajustes


static func validar(dados: Variant) -> Dictionary:
	var resultado := padrao()
	if not dados is Dictionary or dados.get("tipo") != "mesa_perspectiva":
		return resultado
	for chave in ["visivel", "mesa_visivel"]:
		if dados.get(chave) is bool:
			resultado[chave] = dados[chave]
	for chave in LIMITES:
		var valor: Variant = dados.get(chave)
		if (valor is float or valor is int) and is_finite(float(valor)):
			var limite: Vector2 = LIMITES[chave]
			resultado[chave] = clampf(float(valor), limite.x, limite.y)
	if perfil_valido(dados.get("perfil")):
		resultado["perfil"] = dados["perfil"].duplicate(true)
	resultado["luz_mesa"] = validar_luz(dados.get("luz_mesa"))
	return resultado


static func perfil_valido(dados: Variant) -> bool:
	if not dados is Dictionary or not dados.get("maos") is Array or dados["maos"].size() != 4:
		return false
	for mao in dados["maos"]:
		if not mao is Dictionary:
			return false
	return dados.get("mesa") is Dictionary


func _ready() -> void:
	_captura = SubViewport.new()
	_captura.disable_3d = true
	_captura.gui_disable_input = true
	_captura.transparent_bg = true
	_captura.size = Vector2i(REFERENCIA * 2)
	_captura.size_2d_override = Vector2i(REFERENCIA)
	_captura.size_2d_override_stretch = true
	_captura.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_captura)
	_apresentacao = cena_apresentacao.instantiate() as PROJECAO
	_apresentacao.evento_audio.connect(func(acao: String): evento_audio.emit(acao))
	# A cena original usa FULL_RECT. Definir seu tamanho mantendo essas âncoras
	# soma os offsets ao tamanho da captura e desloca o conjunto para fora dela.
	# Aqui o retângulo lógico é fixo; a resolução maior serve apenas à nitidez.
	_apresentacao.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_apresentacao.position = Vector2.ZERO
	_apresentacao.size = REFERENCIA
	_captura.add_child(_apresentacao)
	_imagem = Sprite2D.new()
	_imagem.centered = false
	_imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_imagem.texture = _captura.get_texture()
	add_child(_imagem)


func atualizar(dados: Dictionary, luz: Dictionary) -> void:
	visible = bool(dados["visivel"])
	var perfil: Dictionary = dados["perfil"]
	if not perfil_valido(perfil):
		push_error("Configuração da apresentação inválida.")
		visible = false
		return
	var assinatura := JSON.stringify(perfil)
	if assinatura != _assinatura:
		_assinatura = assinatura
		_apresentacao.configurar_referencia_cenario(perfil, bool(dados["mesa_visivel"]))
		_assinatura_luz = ""
	else:
		_apresentacao.mostrar_mesa_referencia(bool(dados["mesa_visivel"]))
	var tamanho := float(dados["tamanho"]) / 100.0
	# A captura tem duas amostras por unidade; escala/pan deslocam todo o conjunto junto.
	_imagem.scale = Vector2.ONE * tamanho * 0.5
	_imagem.position = REFERENCIA * 0.5 * (1.0 - tamanho) + Vector2(float(dados["x"]), float(dados["y"]))
	z_index = roundi(float(dados["camada"]))
	_transformacao = Transform2D(Vector2(tamanho, 0), Vector2(0, tamanho), _imagem.position)
	_luz_mesa = dados["luz_mesa"]
	_luz_ativa = bool(luz["ativa"])
	var assinatura_luz := JSON.stringify([luz, _luz_mesa, dados["x"], dados["y"], dados["tamanho"]])
	if assinatura_luz != _assinatura_luz:
		_assinatura_luz = assinatura_luz
		_apresentacao.configurar_luz_cenario_referencia(luz, _luz_mesa, _transformacao)
	_apresentacao.definir_interacao_referencia(_interacao_ativa and visible)


func definir_interacao(ativa: bool) -> void:
	_interacao_ativa = ativa
	if not _assinatura.is_empty():
		_apresentacao.definir_interacao_referencia(ativa and visible)


func obter_apresentacao() -> PROJECAO:
	return _apresentacao


func posicao_referencia(ponto: Vector2) -> Vector2:
	return _transformacao.affine_inverse() * ponto


func _pode_interagir() -> bool:
	return _interacao_ativa and visible and not _assinatura.is_empty()


func atualizar_mouse(ponto: Vector2) -> void:
	var local := _transformacao.affine_inverse() * ponto
	if not _pode_interagir() or not Rect2(Vector2.ZERO, REFERENCIA).has_point(local):
		sair_do_mouse()
		return
	_apresentacao.atualizar_mouse_referencia(local)


func sair_do_mouse() -> void:
	_apresentacao.sair_do_mouse_referencia()


func clicar(ponto: Vector2) -> bool:
	if not _pode_interagir():
		return false
	var local := _transformacao.affine_inverse() * ponto
	return Rect2(Vector2.ZERO, REFERENCIA).has_point(local) and _apresentacao.clicar_carta_referencia(local)


func configurar_luz_mesa(material: ShaderMaterial, receber: bool) -> void:
	material.set_shader_parameter("iluminacao_ativa", receber and _luz_ativa and bool(_luz_mesa.get("ativa", false)))
	material.set_shader_parameter("iluminacao_cartas", false)
	material.set_shader_parameter("vela_luz_ativa", false)
	if _luz_mesa.is_empty():
		return
	var t := _transformacao.affine_inverse()
	var inversa := _apresentacao.obter_inversa_luz_referencia() * Basis(
		Vector3(t.x.x, t.x.y, 0), Vector3(t.y.x, t.y.y, 0), Vector3(t.origin.x, t.origin.y, 1))
	material.set_shader_parameter("iluminacao_inversa_x", Vector3(inversa.x.x, inversa.y.x, inversa.z.x))
	material.set_shader_parameter("iluminacao_inversa_y", Vector3(inversa.x.y, inversa.y.y, inversa.z.y))
	material.set_shader_parameter("iluminacao_inversa_z", Vector3(inversa.x.z, inversa.y.z, inversa.z.z))
	material.set_shader_parameter("iluminacao_centro", Vector2(_luz_mesa["x"], _luz_mesa["y"]) / 100.0)
	for chave in ["ambiente", "intensidade", "minimo_cartas", "abrangencia", "temperatura"]:
		material.set_shader_parameter("iluminacao_" + chave, float(_luz_mesa[chave]) / 100.0)
