extends Node2D

const APRESENTACAO = preload("res://scripts/main/cenario/projecao_partida.gd")
const ORNAMENTO = preload("res://images/ambiente/ornamento_mesa.png")
const MENU = preload("res://scripts/main/componentes/tema_menu.gd")
const CONTORNO = preload("res://scripts/main/componentes/contorno_mao_turno.gdshader")
const GIRO = preload("res://scripts/main/componentes/ornamento_turno.gdshader")
const LUZ = preload("res://scripts/main/cenario/luz_cenario.gd")
const LIMITES := {"mao": Vector2(-1, 3), "fonte": Vector2(0, 1),
	"x": Vector2(-25, 125), "y": Vector2(-25, 125),
	"largura": Vector2(100, 2600), "profundidade": Vector2(100, 1400),
	"circularizacao": Vector2(50, 120), "velocidade": Vector2(0, 60),
	"giro": Vector2(-180, 180), "opacidade": Vector2(5, 100),
	"espessura": Vector2(1, 8), "intensidade": Vector2(25, 200),
	"transicao": Vector2(0.05, 1.5)}

var _apresentacao: APRESENTACAO
var _dados := padrao()
var _ornamento: Polygon2D
var _bordas: Array[Polygon2D] = []
var _opacidades: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _angulo := 0.0
var _mao_da_vez := -1
var _textura_pack: AtlasTexture
var _animacao_ativa := true


static func padrao() -> Dictionary:
	return {"ornamento": false, "contorno": false, "fonte": 0, "mao": -1,
		"sentido": 1, "girar": true, "seta": true,
		"x": 50.0, "y": 50.0, "largura": 1850.0, "profundidade": 820.0,
		"circularizacao": 76.0, "velocidade": 12.0, "giro": 0.0,
		"opacidade": 55.0, "espessura": 2.5, "intensidade": 100.0,
		"transicao": 0.25, "cor": "ffca4fff"}


static func validar(dados: Variant) -> Dictionary:
	var resultado := padrao()
	if not dados is Dictionary:
		return resultado
	for chave in ["ornamento", "contorno", "girar", "seta"]:
		if dados.get(chave) is bool:
			resultado[chave] = dados[chave]
	for chave in LIMITES:
		var valor: Variant = dados.get(chave)
		if (valor is float or valor is int) and is_finite(float(valor)):
			var limites: Vector2 = LIMITES[chave]
			resultado[chave] = clampf(float(valor), limites.x, limites.y)
	resultado["mao"] = roundi(resultado["mao"])
	resultado["fonte"] = roundi(resultado["fonte"])
	resultado["sentido"] = -1 if dados.get("sentido", 1) == -1 else 1
	if dados.get("cor") is String and Color.html_is_valid(dados["cor"]):
		resultado["cor"] = dados["cor"]
	return resultado


func preparar(apresentacao: APRESENTACAO) -> void:
	_apresentacao = apresentacao
	_textura_pack = MENU.emblema()
	_ornamento = Polygon2D.new()
	_ornamento.name = "OrnamentoSentido"
	_ornamento.z_index = 2
	_ornamento.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ornamento.material = ShaderMaterial.new()
	(_ornamento.material as ShaderMaterial).shader = GIRO
	add_child(_ornamento)
	for indice in range(4):
		var borda := Polygon2D.new()
		borda.name = "ContornoMao%d" % indice
		borda.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		borda.material = ShaderMaterial.new()
		(borda.material as ShaderMaterial).shader = CONTORNO
		borda.hide()
		add_child(borda)
		_bordas.append(borda)
	configurar(_dados)


func configurar(dados: Dictionary) -> void:
	var novos := validar(dados)
	if not is_equal_approx(float(novos["giro"]), float(_dados["giro"])):
		_angulo = 0.0
	if novos["mao"] != _dados["mao"]:
		_mao_da_vez = int(novos["mao"])
	_dados = novos
	if _ornamento == null:
		return
	_ornamento.texture = ORNAMENTO if _dados["fonte"] == 0 else _textura_pack
	var material := _ornamento.material as ShaderMaterial
	material.set_shader_parameter("escala_fonte", Vector2(1.25, 1.25 * _dados["circularizacao"] / 100.0) if _dados["fonte"] == 0 else Vector2.ONE)
	material.set_shader_parameter("opacidade", _dados["opacidade"] / 100.0)
	material.set_shader_parameter("mostrar_seta", _dados["seta"])
	material.set_shader_parameter("sentido", float(_dados["sentido"]))
	for borda in _bordas:
		var contorno := borda.material as ShaderMaterial
		contorno.set_shader_parameter("cor", Color.html(_dados["cor"]))
		contorno.set_shader_parameter("espessura", float(_dados["espessura"]))
		contorno.set_shader_parameter("intensidade", _dados["intensidade"] / 100.0)
	set_process(true)


func obter_giro() -> float:
	return wrapf(rad_to_deg(_angulo) + float(_dados["giro"]), -180.0, 180.0)


func definir_turno(mao: int, sentido: int, ativo: bool) -> void:
	_dados["mao"] = clampi(mao, -1, 3)
	_dados["sentido"] = -1 if sentido < 0 else 1
	_mao_da_vez = int(_dados["mao"]) if ativo else -1
	_animacao_ativa = ativo
	(_ornamento.material as ShaderMaterial).set_shader_parameter("sentido", float(_dados["sentido"]))
	set_process(true)


func reiniciar() -> void:
	_angulo = 0.0
	_mao_da_vez = -1
	_dados["mao"] = -1
	for indice in range(_bordas.size()):
		_opacidades[indice] = 0.0
		_bordas[indice].hide()
	_atualizar_ornamento()


func aplicar_luz(dados: Dictionary) -> void:
	if _ornamento == null or _apresentacao == null:
		return
	# Mesma conversão da apresentação capturada para as posições das fontes na cena.
	LUZ.enviar(_ornamento.material as ShaderMaterial, dados, LUZ.ALVO_ORNAMENTO,
		_apresentacao._transformacao_cenario_referencia)


func _process(delta: float) -> void:
	if _apresentacao == null or not is_visible_in_tree():
		return
	if _dados["girar"] and _animacao_ativa:
		_angulo = fmod(_angulo + deg_to_rad(float(_dados["velocidade"])) * int(_dados["sentido"]) * delta, TAU)
	_atualizar_ornamento()
	for indice in range(4):
		var alvo := 1.0 if _dados["contorno"] and indice == _mao_da_vez else 0.0
		_opacidades[indice] = move_toward(_opacidades[indice], alvo, delta / float(_dados["transicao"]))
		_atualizar_borda(indice)
	if (not _animacao_ativa or (not _dados["ornamento"] and not _dados["contorno"])) and _opacidades.all(func(valor: float) -> bool: return valor < 0.001):
		set_process(false)


func _atualizar_ornamento() -> void:
	_ornamento.visible = bool(_dados["ornamento"])
	if not _ornamento.visible:
		return
	var dimensoes := Vector2(_apresentacao._mesa.tamanho_plano)
	var tamanho := Vector2(_dados["largura"], _dados["profundidade"])
	var centro := dimensoes * Vector2(_dados["x"], _dados["y"]) / 100.0
	var matriz := _apresentacao._matriz_da_mesa(Vector3(centro.x - tamanho.x / 2.0, centro.y - tamanho.y / 2.0, 0.1),
		Vector3(tamanho.x, 0, 0), Vector3(0, tamanho.y, 0))
	var pontos := PackedVector2Array()
	for uv in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		var ponto: Vector3 = matriz * Vector3(uv.x, uv.y, 1)
		if ponto.z <= 0.00001:
			_ornamento.hide()
			return
		pontos.append(Vector2(ponto.x, ponto.y) / ponto.z)
	if absf(matriz.determinant()) < 0.00001:
		_ornamento.hide()
		return
	_ornamento.polygon = pontos
	var material := _ornamento.material as ShaderMaterial
	_apresentacao._enviar_inversa(material, matriz.inverse())
	material.set_shader_parameter("angulo", _angulo + deg_to_rad(float(_dados["giro"])))


func _atualizar_borda(indice: int) -> void:
	var borda := _bordas[indice]
	var original: Polygon2D = _apresentacao._poligonos[indice]
	borda.visible = original.visible and _opacidades[indice] > 0.001 and _apresentacao._maos_erguidas[indice].quantidade_cartas() > 0
	if not borda.visible or original.polygon.is_empty():
		return
	borda.texture = original.texture
	borda.z_index = original.z_index + 1
	var limites := Rect2(original.polygon[0], Vector2.ZERO)
	for ponto in original.polygon:
		limites = limites.expand(ponto)
	limites = limites.grow(float(_dados["espessura"]) + 2.0)
	borda.polygon = PackedVector2Array([limites.position, limites.position + Vector2(limites.size.x, 0),
		limites.end, limites.position + Vector2(0, limites.size.y)])
	var origem := original.material as ShaderMaterial
	var material := borda.material as ShaderMaterial
	for parametro in ["inversa_x", "inversa_y", "inversa_z", "regiao_textura"]:
		material.set_shader_parameter(parametro, origem.get_shader_parameter(parametro))
	material.set_shader_parameter("opacidade", _opacidades[indice])
