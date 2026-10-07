extends "res://scripts/main/cenario/base_plano_mesa.gd"

const PROJECAO = preload("res://scripts/main/cenario/plano_mao_perspectiva.gdshader")
const SOMBRA_PLANO = preload("res://scripts/main/cenario/sombra_mao_no_tampo.gdshader")
const TAMANHO_MAO := Vector2(600, 360)
const TAMANHO_ATLAS := Vector2i(1200, 720)
const NOMES = ["Inferior", "Superior", "Esquerda", "Direita"]
const LIMITES = {
	"posicao_x": Vector2(-25, 125), "posicao_y": Vector2(-25, 125),
	"tamanho": Vector2(0.6, 1.4), "giro": Vector2(-180, 180),
	"inclinacao": Vector2(-45, 85), "altura": Vector2(0, 100)
}
const LIMITES_FONTE = {
	"x": Vector2(-50, 150), "y": Vector2(-100, 200), "altura": Vector2(20, 2000)
}
const NUMERICOS_AVANCADOS = {
	"compressao": [1.0, 0.3, 1.5, 0.05, "Altura das cartas", ""],
	"largura": [360.0, 180, 900, 5, "Largura do leque", ""],
	"separacao": [-10.0, -60, 25, 1, "Separação", ""],
	"curvatura": [-15.0, -90, 90, 1, "Curvatura do arco", ""],
	"abertura": [5.0, -35, 35, 1, "Abertura", "°"],
	"deformacao": [0.0, -25, 25, 1, "Deformar conjunto", "°"],
	"variacao_tamanho": [0.0, -0.5, 0.5, 0.05, "Variação de tamanho", ""],
	"inclinacao_x": [0.0, -85, 85, 1, "Inclinar cima/baixo", "°"],
	"inclinacao_x_inicio": [0.0, -85, 85, 1, "Cima/baixo · primeira", "°"],
	"inclinacao_x_fim": [0.0, -85, 85, 1, "Cima/baixo · última", "°"],
	"inclinacao_y": [0.0, -85, 85, 1, "Inclinar esquerda/direita", "°"],
	"inclinacao_y_inicio": [0.0, -85, 85, 1, "Esquerda/direita · primeira", "°"],
	"inclinacao_y_fim": [0.0, -85, 85, 1, "Esquerda/direita · última", "°"]
}
const OPCOES_AVANCADAS = {
	"deformacao_progressiva": "Deformação gradual por carta",
	"inclinacao_x_progressiva": "Inclinação cima/baixo gradual",
	"inclinacao_y_progressiva": "Inclinação esquerda/direita gradual",
	"frentes": "Mostrar frentes", "sombras": "Mostrar sombras"
}

@export_group("Sombras no tampo")
@export var usar_fonte_localizada := true
@export var posicao_fonte := Vector3(800, -140, 700)
@export var direcao_sombra := Vector2(-0.35, 0.55)
@export_range(0.0, 0.8, 0.01) var intensidade_sombra := 0.30
@export_range(0.5, 12.0, 0.5) var suavidade_sombra := 2.0
@export_range(0.0, 0.1, 0.005) var suavidade_por_altura := 0.035

var _atlas: SubViewport
var _maos_erguidas: Array[MaoVisual] = []
var _poligonos: Array[Polygon2D] = []
var _sombras_tampo: Array[Polygon2D] = []
var _inversas: Array[Basis] = []
var _origens_atlas: Array[Vector2] = []
var _perfis: Array[Dictionary] = []
var _tamanho_captura := TAMANHO_MAO
var _dados_maos: Array[Array] = []
var _virando_maos: Array[bool] = [false, false, false, false]
var _versoes_virada: Array[int] = [0, 0, 0, 0]
var _padrao_fonte: Dictionary = {}
var _viewport_mouse: SubViewport


var _inferior_livre := true
var _sombras_no_tampo := true

func _ready() -> void:
	_atlas = SubViewport.new()
	_atlas.name = "AtlasMaos"
	_atlas.disable_3d = true
	_atlas.transparent_bg = true
	_atlas.size = TAMANHO_ATLAS
	_atlas.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_composicao.add_child(_atlas)
	super._ready()
	_padrao_fonte = _configuracao_fonte()
	_aplicar_avancados()
	_projetar_maos()


func _montar_mao(indice: int) -> void:
	var origem := Vector2(indice % 2, floori(indice / 2.0)) * TAMANHO_MAO
	var mao := CENA_MAO.instantiate() as MaoVisual
	mao.name = "Mao" + NOMES[indice]
	mao.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mao.custom_minimum_size = Vector2(360, 140)
	mao.size = Vector2(360, 140)
	mao.pivot_offset = mao.size / 2.0
	mao.position = origem + TAMANHO_MAO / 2.0 - mao.pivot_offset
	mao.color = Color.TRANSPARENT
	mao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mao.mao_adversaria = indice != 0
	_atlas.add_child(mao)
	mao.definir_hover_habilitado(true, true)
	var dados_mao: Array = []
	var poligono := Polygon2D.new()
	poligono.name = "Plano" + NOMES[indice]
	poligono.z_index = [13, 10, 11, 12][indice]
	poligono.texture = _atlas.get_texture()
	poligono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = PROJECAO
	material.set_shader_parameter("regiao_textura", Vector4(
		origem.x / TAMANHO_ATLAS.x, origem.y / TAMANHO_ATLAS.y,
		TAMANHO_MAO.x / TAMANHO_ATLAS.x, TAMANHO_MAO.y / TAMANHO_ATLAS.y))
	poligono.material = material
	_composicao.add_child(poligono)
	var sombra := Polygon2D.new()
	sombra.name = "SombraTampo" + NOMES[indice]
	sombra.z_index = 1
	sombra.texture = _atlas.get_texture()
	sombra.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material_sombra := ShaderMaterial.new()
	material_sombra.shader = SOMBRA_PLANO
	sombra.material = material_sombra
	_composicao.add_child(sombra)
	_sombras_tampo.append(sombra)
	_maos_erguidas.append(mao)
	_poligonos.append(poligono)
	_inversas.append(Basis.IDENTITY)
	_origens_atlas.append(origem)
	_perfis.append(_perfil_inicial(indice))
	_dados_maos.append(dados_mao)


func _perfil_inicial(indice: int) -> Dictionary:
	return {"posicao_x": CENTROS[indice].x * 100.0, "posicao_y": CENTROS[indice].y * 100.0,
		"tamanho": 1.0, "giro": GIROS[indice], "inclinacao": 0.0, "altura": 0.0,
		"primeiro_plano": _padrao_primeiro_plano(),
		"avancados": _padrao_avancados(indice)}


func _padrao_primeiro_plano() -> Dictionary:
	return {"posicao_x": 50.0, "posicao_y": 90.0, "tamanho": 1.8,
		"giro": 0.0, "inclinacao": 0.0, "altura": 0.0}


func _limite_basico(chave: String, livre: bool) -> Vector2:
	if livre:
		match chave:
			"posicao_x", "posicao_y": return Vector2(-20, 120)
			"tamanho": return Vector2(0.6, 3.0)
			"altura": return Vector2(0, 400)
	return LIMITES[chave]


func _padrao_avancados(indice: int) -> Dictionary:
	var valores: Dictionary = {}
	for chave in NUMERICOS_AVANCADOS:
		valores[chave] = NUMERICOS_AVANCADOS[chave][0]
	for chave in OPCOES_AVANCADAS:
		valores[chave] = false
	valores["frentes"] = indice == 0
	valores["sombras"] = true
	return valores


func _ponto_no_mundo(local: Vector2, perfil: Dictionary) -> Vector3:
	var inclinacao := deg_to_rad(float(perfil["inclinacao"])) if not false else 0.0
	var altura := float(perfil["altura"]) if not false else 0.0
	# A mão inclina ao redor de uma linha próxima à base das cartas.
	var apoio := 50.0
	var ponto := Vector2(local.x, apoio + (local.y - apoio) * cos(inclinacao))
	ponto = (ponto * float(perfil["tamanho"])).rotated(deg_to_rad(float(perfil["giro"])))
	var centro := Vector2(_mesa.tamanho_plano) * Vector2(
		float(perfil["posicao_x"]), float(perfil["posicao_y"])) / 100.0
	return Vector3(centro.x + ponto.x, centro.y + ponto.y,
		altura - (local.y - apoio) * sin(inclinacao) * float(perfil["tamanho"]))


func _matriz_da_mesa(ponto: Vector3, eixo_u: Vector3, eixo_v: Vector3) -> Basis:
	return preload("res://scripts/main/cenario/projecao_mesa.gd").matriz(_mesa, ponto, eixo_u, eixo_v)


func _matriz_por_linhas(x: Vector3, y: Vector3, z: Vector3) -> Basis:
	return Basis(Vector3(x.x, y.x, z.x), Vector3(x.y, y.y, z.y), Vector3(x.z, y.z, z.z))


func _ponto_primeiro_plano(local: Vector2, perfil: Dictionary) -> Vector3:
	# Câmera própria, frontal: não usa profundidade, largura ou inclinação da mesa.
	var angulo := deg_to_rad(float(perfil["inclinacao"]))
	var escala := float(perfil["tamanho"])
	var apoio := 50.0
	var xy := Vector2(local.x, apoio + (local.y - apoio) * cos(angulo))
	xy = (xy * escala).rotated(deg_to_rad(float(perfil["giro"])))
	return Vector3(xy.x, xy.y, float(perfil["altura"]) - (local.y - apoio) * sin(angulo) * escala)


func _matriz_primeiro_plano(perfil: Dictionary) -> Basis:
	var ponto := _ponto_primeiro_plano(-_tamanho_captura / 2.0, perfil)
	var u := _ponto_primeiro_plano(Vector2(_tamanho_captura.x / 2.0, -_tamanho_captura.y / 2.0), perfil) - ponto
	var v := _ponto_primeiro_plano(Vector2(-_tamanho_captura.x / 2.0, _tamanho_captura.y / 2.0), perfil) - ponto
	var centro := REFERENCIA * Vector2(float(perfil["posicao_x"]), float(perfil["posicao_y"])) / 100.0
	var denominador := Vector3(-u.z / 1200.0, -v.z / 1200.0, 1.0 - ponto.z / 1200.0)
	return _matriz_por_linhas(Vector3(u.x, v.x, ponto.x) + centro.x * denominador,
		Vector3(u.y, v.y, ponto.y) + centro.y * denominador, denominador)


func _enviar_inversa(material: ShaderMaterial, inversa: Basis, prefixo: String = "inversa") -> void:
	material.set_shader_parameter(prefixo + "_x", Vector3(inversa.x.x, inversa.y.x, inversa.z.x))
	material.set_shader_parameter(prefixo + "_y", Vector3(inversa.x.y, inversa.y.y, inversa.z.y))
	material.set_shader_parameter(prefixo + "_z", Vector3(inversa.x.z, inversa.y.z, inversa.z.z))


func _aplicar_projecao(poligono: Polygon2D, matriz: Basis, indice: int) -> bool:
	var vertices := PackedVector2Array()
	for uv in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		var projetado: Vector3 = matriz * Vector3(uv.x, uv.y, 1.0)
		if projetado.z <= 0.00001:
			break
		vertices.append(Vector2(projetado.x, projetado.y) / projetado.z)
	poligono.visible = vertices.size() == 4 and absf(matriz.determinant()) > 0.00001
	if not poligono.visible:
		return false
	poligono.polygon = vertices
	var material := poligono.material as ShaderMaterial
	_enviar_inversa(material, matriz.inverse())
	var dimensoes := Vector2(_atlas.size)
	material.set_shader_parameter("regiao_textura", Vector4(
		_origens_atlas[indice].x / dimensoes.x, _origens_atlas[indice].y / dimensoes.y,
		_tamanho_captura.x / dimensoes.x, _tamanho_captura.y / dimensoes.y))
	return true


func _matriz_sombra(ponto: Vector3, u: Vector3, v: Vector3, altura_receptor: float = 0.0) -> Basis:
	var chao: Basis
	if usar_fonte_localizada:
		# Interseção do raio fonte -> carta com o plano receptor, em coordenadas homogêneas.
		# A divisão por (altura da fonte - altura da carta) varia ao longo da mão.
		var distancia_fonte := posicao_fonte.z - altura_receptor
		chao = Basis(
			Vector3(distancia_fonte * u.x - posicao_fonte.x * u.z,
				distancia_fonte * u.y - posicao_fonte.y * u.z, -u.z),
			Vector3(distancia_fonte * v.x - posicao_fonte.x * v.z,
				distancia_fonte * v.y - posicao_fonte.y * v.z, -v.z),
			Vector3(distancia_fonte * ponto.x + posicao_fonte.x * (altura_receptor - ponto.z),
				distancia_fonte * ponto.y + posicao_fonte.y * (altura_receptor - ponto.z), posicao_fonte.z - ponto.z))
	else:
		chao = Basis(Vector3(u.x + u.z * direcao_sombra.x, u.y + u.z * direcao_sombra.y, 0),
			Vector3(v.x + v.z * direcao_sombra.x, v.y + v.z * direcao_sombra.y, 0),
			Vector3(ponto.x + (ponto.z - altura_receptor) * direcao_sombra.x,
				ponto.y + (ponto.z - altura_receptor) * direcao_sombra.y, 1))
	return _matriz_da_mesa(Vector3(0, 0, altura_receptor), Vector3.RIGHT, Vector3.UP) * chao


func _projetar_maos() -> void:
	var tamanho_mesa := Vector2(_mesa.tamanho_plano)
	var matriz_mesa := _matriz_da_mesa(Vector3.ZERO,
		Vector3(tamanho_mesa.x, 0, 0), Vector3(0, tamanho_mesa.y, 0))
	var inversa_mesa := matriz_mesa.inverse()
	var retangulo := _mesa.obter_retangulo_plano()
	var matriz_receptor := _matriz_da_mesa(Vector3(retangulo.position.x, retangulo.position.y, 0),
		Vector3(retangulo.size.x, 0, 0), Vector3(0, retangulo.size.y, 0))
	for indice in range(4):
		var perfil := _perfis[indice]
		var livre := indice == 0 and _inferior_livre
		var ponto := _ponto_no_mundo(-_tamanho_captura / 2.0, perfil)
		var u := _ponto_no_mundo(Vector2(_tamanho_captura.x / 2.0, -_tamanho_captura.y / 2.0), perfil) - ponto
		var v := _ponto_no_mundo(Vector2(-_tamanho_captura.x / 2.0, _tamanho_captura.y / 2.0), perfil) - ponto
		var matriz := _matriz_primeiro_plano(perfil["primeiro_plano"]) if livre else _matriz_da_mesa(ponto, u, v)
		if _aplicar_projecao(_poligonos[indice], matriz, indice):
			_inversas[indice] = matriz.inverse()
		var sombra := _sombras_tampo[indice]
		sombra.visible = false
		if livre or not _sombras_no_tampo or not bool(perfil["avancados"]["sombras"]):
			continue
		var matriz_sombra := _matriz_sombra(ponto, u, v)
		if absf(matriz_sombra.determinant()) < 0.00001:
			continue
		# Desenhar no receptor, em vez de um quad de sombra potencialmente infinito
		# quando a fonte passa pela altura de parte do plano da mão.
		if not _aplicar_projecao(sombra, matriz_receptor, indice):
			continue
		var material := sombra.material as ShaderMaterial
		_enviar_inversa(material, matriz_sombra.inverse())
		_enviar_inversa(material, inversa_mesa, "mesa")
		material.set_shader_parameter("altura_plano", Vector3(u.z, v.z, ponto.z))
		material.set_shader_parameter("tamanho_captura", _tamanho_captura)
		_mesa.configurar_recorte_sombra(material)
		material.set_shader_parameter("intensidade", intensidade_sombra)
		material.set_shader_parameter("suavidade", suavidade_sombra)
		material.set_shader_parameter("suavidade_por_altura", suavidade_por_altura)
		material.set_shader_parameter("fonte_localizada", usar_fonte_localizada)
		material.set_shader_parameter("altura_fonte", posicao_fonte.z)


func _carta_no_ponto_da_mao(mouse: Vector2, indice: int) -> Carta:
	if not _poligonos[indice].visible:
		return null
	var ponto: Vector3 = _inversas[indice] * Vector3(mouse.x, mouse.y, 1.0)
	if absf(ponto.z) < 0.00001:
		return null
	var uv := Vector2(ponto.x, ponto.y) / ponto.z
	if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
		return null
	var posicao := _origens_atlas[indice] + uv * _tamanho_captura
	var cartas := _maos_erguidas[indice].obter_cartas()
	# A última carta é desenhada por cima no leque, como no encaminhamento GUI.
	for numero in range(cartas.size() - 1, -1, -1):
		var carta := cartas[numero]
		if carta.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var local := carta.get_global_transform_with_canvas().affine_inverse() * posicao
		if Rect2(Vector2.ZERO, carta.size).has_point(local):
			return carta
	return null


func _atualizar_mouse_maos(mouse: Vector2) -> void:
	for indice in [0, 3, 2, 1]:
		# Não deixar a margem transparente de um plano bloquear outra mão.
		if _carta_no_ponto_da_mao(mouse, indice) == null:
			continue
		var ponto: Vector3 = _inversas[indice] * Vector3(mouse.x, mouse.y, 1.0)
		var uv := Vector2(ponto.x, ponto.y) / ponto.z
		var posicao := _origens_atlas[indice] + uv * _tamanho_captura
		var viewport := _viewport_da_mao(indice)
		if _viewport_mouse != viewport:
			_sair_da_mesa()
			viewport.notify_mouse_entered()
			_viewport_mouse = viewport
			_mouse_na_mesa = true
			_posicao_mouse_anterior = posicao
		var evento := InputEventMouseMotion.new()
		evento.position = posicao
		evento.global_position = posicao
		evento.relative = posicao - _posicao_mouse_anterior
		viewport.push_input(evento, true)
		_posicao_mouse_anterior = posicao
		return
	_sair_da_mesa()


func _sair_da_mesa() -> void:
	if _mouse_na_mesa:
		if is_instance_valid(_viewport_mouse):
			_viewport_mouse.notify_mouse_exited()
		_viewport_mouse = null
		_mouse_na_mesa = false


func _viewport_da_mao(_indice: int) -> SubViewport:
	return _atlas


func _configuracao_fonte() -> Dictionary:
	var dimensoes := Vector2(_mesa.tamanho_plano)
	return {"localizada": usar_fonte_localizada, "x": posicao_fonte.x / dimensoes.x * 100.0,
		"y": posicao_fonte.y / dimensoes.y * 100.0, "altura": posicao_fonte.z}


func _aplicar_configuracao_fonte(configuracao: Dictionary) -> void:
	var valores := _padrao_fonte.duplicate()
	for chave in LIMITES_FONTE:
		var valor: Variant = configuracao.get(chave, valores[chave])
		if (valor is float or valor is int) and is_finite(float(valor)):
			valores[chave] = clampf(float(valor), LIMITES_FONTE[chave].x, LIMITES_FONTE[chave].y)
	var localizada: Variant = configuracao.get("localizada", valores["localizada"])
	usar_fonte_localizada = localizada if localizada is bool else bool(valores["localizada"])
	var dimensoes := Vector2(_mesa.tamanho_plano)
	posicao_fonte = Vector3(float(valores["x"]) / 100.0 * dimensoes.x,
		float(valores["y"]) / 100.0 * dimensoes.y, float(valores["altura"]))


func _aplicar_perfil(perfil: Dictionary, nome: String) -> void:
	for indice in range(4):
		var ajustes := _perfil_inicial(indice)
		for chave in LIMITES:
			var valor: Variant = perfil["maos"][indice].get(chave, ajustes[chave])
			if (valor is float or valor is int) and is_finite(float(valor)):
				ajustes[chave] = clampf(float(valor), LIMITES[chave].x, LIMITES[chave].y)
		var livre: Variant = perfil["maos"][indice].get("primeiro_plano", {})
		if livre is Dictionary:
			for chave in LIMITES:
				var valor: Variant = livre.get(chave, ajustes["primeiro_plano"][chave])
				var limites := _limite_basico(chave, true)
				if (valor is float or valor is int) and is_finite(float(valor)):
					ajustes["primeiro_plano"][chave] = clampf(float(valor), limites.x, limites.y)
		var avancados: Variant = perfil["maos"][indice].get("avancados", {})
		if avancados is Dictionary:
			for chave in NUMERICOS_AVANCADOS:
				var valor: Variant = avancados.get(chave, ajustes["avancados"][chave])
				if (valor is float or valor is int) and is_finite(float(valor)):
					ajustes["avancados"][chave] = clampf(float(valor), NUMERICOS_AVANCADOS[chave][1], NUMERICOS_AVANCADOS[chave][2])
			for chave in OPCOES_AVANCADAS:
				var valor: Variant = avancados.get(chave, ajustes["avancados"][chave])
				if valor is bool:
					ajustes["avancados"][chave] = valor
		_perfis[indice] = ajustes
	_inferior_livre = bool(perfil.get("inferior_livre", true))
	_sombras_no_tampo = bool(perfil.get("sombras_tampo", true))
	var fonte: Variant = perfil.get("fonte_sombra", {})
	_aplicar_configuracao_fonte(fonte if fonte is Dictionary else {})
	_aplicar_avancados()
	_projetar_maos()


func _alteracoes_avancadas(indice: int) -> Dictionary:
	var alteracoes: Dictionary = {}
	var padrao := _padrao_avancados(indice)
	var atual := _avancados_efetivos(indice)
	for chave in padrao:
		var mudou: bool = atual[chave] != padrao[chave] if padrao[chave] is bool else not is_equal_approx(float(atual[chave]), float(padrao[chave]))
		if mudou:
			alteracoes[chave] = {"padrao": padrao[chave], "valor": atual[chave]}
	return alteracoes


func _avancados_efetivos(indice: int) -> Dictionary:
	# Conservar o que foi salvo/editado, mas ignorar opções sem efeito geométrico.
	var atual: Dictionary = _perfis[indice]["avancados"].duplicate()
	if is_zero_approx(float(atual["deformacao"])):
		atual["deformacao_progressiva"] = false
	for eixo in ["x", "y"]:
		var chave: String = "inclinacao_" + eixo
		if bool(atual[chave + "_progressiva"]):
			atual[chave] = 0.0
			if is_zero_approx(float(atual[chave + "_inicio"])) and is_zero_approx(float(atual[chave + "_fim"])):
				atual[chave + "_progressiva"] = false
		else:
			atual[chave + "_inicio"] = 0.0
			atual[chave + "_fim"] = 0.0
	return atual


func _aplicar_avancados(somente: int = -1) -> void:
	for indice in range(4):
		if somente != -1 and somente != indice:
			continue
		var avancados := _avancados_efetivos(indice)
		var ajustes := avancados.duplicate()
		ajustes["altura"] = avancados["compressao"]
		ajustes["tamanho"] = 1.0
		ajustes["giro"] = 0.0
		var mao := _maos_erguidas[indice]
		var opcoes := avancados.duplicate()
		# A silhueta do atlas não contém a sombra antiga quando projetada no tampo.
		var livre := indice == 0 and _inferior_livre
		opcoes["sombras"] = bool(avancados["sombras"]) and (livre or not _sombras_no_tampo)
		mao.configurar_visual(ajustes, opcoes, false)
		# Compensar a origem centrada do modo 2.5D para conservar a referência.
		mao.position = _origens_atlas[indice] + _tamanho_captura / 2.0 + Vector2(0, -22.5)
		var cartas := mao.obter_cartas()
		var virou := false
		for numero in range(cartas.size()):
			var carta := cartas[numero]
			if carta.verso != (not bool(avancados["frentes"])):
				if bool(avancados["frentes"]):
					carta.setup_dados(_dados_da_carta(carta, indice, numero))
				carta.verso = not bool(avancados["frentes"])
				virou = true
		if virou:
			_virando_maos[indice] = true
			_versoes_virada[indice] += 1
			_aguardar_virada(indice, _versoes_virada[indice])
	_atualizar_captura()


func _dados_da_carta(_carta: Carta, indice: int, numero: int) -> Dictionary:
	return _dados_maos[indice][numero]


func _aguardar_virada(indice: int, versao: int) -> void:
	await get_tree().create_timer(0.75).timeout
	if versao != _versoes_virada[indice]:
		return
	_virando_maos[indice] = false


func _atualizar_captura() -> void:
	var captura := TAMANHO_MAO
	for indice in range(4):
		var mudou_geometria := false
		var alteracoes := _alteracoes_avancadas(indice)
		for chave in NUMERICOS_AVANCADOS:
			mudou_geometria = mudou_geometria or alteracoes.has(chave)
		if not mudou_geometria:
			continue
		var mao := _maos_erguidas[indice]
		var cartas := mao.obter_cartas()
		for numero in range(cartas.size()):
			var carta := cartas[numero]
			var estado := mao.calcular_estado_carta(numero, cartas.size())
			var angulo := deg_to_rad(float(estado["deformacao"]))
			for sinal in [Vector2(-1, -1), Vector2(1, -1), Vector2.ONE, Vector2(-1, 1)]:
				# Quad máximo do shader e margem para escala elástica do hover.
				var ponto: Vector2 = sinal * (Carta.SIZE + Vector2.ONE * 16.0) * 0.75 * 1.25
				ponto += Vector2(-sin(angulo), cos(angulo) - 1.0) * ponto.y
				ponto = mao.transformacao_destino_carta(numero) * (Carta.SIZE / 2.0 + ponto)
				ponto -= _origens_atlas[indice] + _tamanho_captura / 2.0
				captura = captura.max((ponto.abs() + Vector2.ONE * 16.0) * 2.0)
	if not captura.is_equal_approx(TAMANHO_MAO):
		captura = Vector2(ceil(captura.x / 16.0) * 16.0, ceil(captura.y / 16.0) * 16.0)
	if captura.is_equal_approx(_tamanho_captura):
		return
	_tamanho_captura = captura
	_atlas.size = Vector2i(captura * 2.0)
	for indice in range(4):
		_origens_atlas[indice] = Vector2(indice % 2, floori(indice / 2.0)) * captura
		_maos_erguidas[indice].position = _origens_atlas[indice] + captura / 2.0 + Vector2(0, -22.5)
