extends "res://scripts/desenvolvimento/laboratorios/interno/base_plano_mesa.gd"

const PROJECAO = preload("res://scripts/desenvolvimento/laboratorios/plano_mao_perspectiva.gdshader")
const SOMBRA_PLANO = preload("res://scripts/desenvolvimento/laboratorios/sombra_mao_no_tampo.gdshader")
const TAMANHO_MAO := Vector2(600, 360)
const TAMANHO_ATLAS := Vector2i(1200, 720)
const NOMES = ["Inferior", "Superior", "Esquerda", "Direita"]
const ARQUIVO_TESTES = "user://laboratorio_maos_erguidas.json"
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

@onready var _painel: PanelContainer = $Painel
@onready var _rolagem: ScrollContainer = $Painel/Margem/Rolagem
@onready var _controles_ui: VBoxContainer = $Painel/Margem/Rolagem/Controles

var _atlas: SubViewport
var _maos_erguidas: Array[MaoVisual] = []
var _poligonos: Array[Polygon2D] = []
var _sombras_tampo: Array[Polygon2D] = []
var _inversas: Array[Basis] = []
var _origens_atlas: Array[Vector2] = []
var _perfis: Array[Dictionary] = []
var _controles: Dictionary = {}
var _selecionada := 0
var _seletor: OptionButton
var _comparar: CheckBox
var _nome: LineEdit
var _notas: TextEdit
var _lista: OptionButton
var _carregar: Button
var _mensagem: Label
var _testes: Dictionary = {}
var _atualizando_ui := false
var _tamanho_captura := TAMANHO_MAO
var _avancados_botao: Button
var _avancados_painel: PanelContainer
var _avancados_resumo: Label
var _controles_avancados: Dictionary = {}
var _indicadores_avancados: Dictionary = {}
var _blocos_avancados: Dictionary = {}
var _dados_maos: Array[Array] = []
var _virando_maos: Array[bool] = [false, false, false, false]
var _versoes_virada: Array[int] = [0, 0, 0, 0]
var _primeiro_plano: CheckBox
var _sombras_melhoradas: CheckBox
var _legendas_basicas: Dictionary = {}
var _fonte_localizada: CheckBox
var _controles_fonte: Dictionary = {}
var _padrao_fonte: Dictionary = {}
var _campos_fonte: VBoxContainer
var _viewport_mouse: SubViewport


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
	_montar_painel()
	_ler_testes()
	_mostrar_perfil()
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
	for numero in range(7):
		var carta := CENA_CARTA.instantiate() as Carta
		mao.receber_carta(carta, false)
		var dados := {"id": indice * 7 + numero + 1,
			"cor": CORES[numero % CORES.size()], "valor": str(numero + 1)}
		carta.setup_dados(dados)
		dados_mao.append(dados)
		carta.definir_sombra_visivel(true)
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


func _perfil_em_edicao() -> Dictionary:
	if _selecionada == 0 and _primeiro_plano.button_pressed:
		return _perfis[0]["primeiro_plano"]
	return _perfis[_selecionada]


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
	var inclinacao := deg_to_rad(float(perfil["inclinacao"])) if not _comparar.button_pressed else 0.0
	var altura := float(perfil["altura"]) if not _comparar.button_pressed else 0.0
	# A mão inclina ao redor de uma linha próxima à base das cartas.
	var apoio := 50.0
	var ponto := Vector2(local.x, apoio + (local.y - apoio) * cos(inclinacao))
	ponto = (ponto * float(perfil["tamanho"])).rotated(deg_to_rad(float(perfil["giro"])))
	var centro := Vector2(_mesa.tamanho_plano) * Vector2(
		float(perfil["posicao_x"]), float(perfil["posicao_y"])) / 100.0
	return Vector3(centro.x + ponto.x, centro.y + ponto.y,
		altura - (local.y - apoio) * sin(inclinacao) * float(perfil["tamanho"]))


func _matriz_da_mesa(ponto: Vector3, eixo_u: Vector3, eixo_v: Vector3) -> Basis:
	return preload("res://scripts/desenvolvimento/laboratorios/interno/projecao_laboratorio.gd").matriz(_mesa, ponto, eixo_u, eixo_v)


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
		var livre := indice == 0 and _primeiro_plano.button_pressed
		var ponto := _ponto_no_mundo(-_tamanho_captura / 2.0, perfil)
		var u := _ponto_no_mundo(Vector2(_tamanho_captura.x / 2.0, -_tamanho_captura.y / 2.0), perfil) - ponto
		var v := _ponto_no_mundo(Vector2(-_tamanho_captura.x / 2.0, _tamanho_captura.y / 2.0), perfil) - ponto
		var matriz := _matriz_primeiro_plano(perfil["primeiro_plano"]) if livre else _matriz_da_mesa(ponto, u, v)
		if _aplicar_projecao(_poligonos[indice], matriz, indice):
			_inversas[indice] = matriz.inverse()
		var sombra := _sombras_tampo[indice]
		sombra.visible = false
		if livre or not _sombras_melhoradas.button_pressed or not bool(perfil["avancados"]["sombras"]):
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


func _process(_delta: float) -> void:
	if not _mouse_na_janela or not get_window().has_focus() or (_painel.visible and _painel.get_global_rect().has_point(get_global_mouse_position())):
		_sair_da_mesa()
		return
	var mouse := _composicao.get_local_mouse_position()
	for indice in [0, 3, 2, 1]:
		if not _poligonos[indice].visible:
			continue
		var ponto: Vector3 = _inversas[indice] * Vector3(mouse.x, mouse.y, 1.0)
		if absf(ponto.z) < 0.00001:
			continue
		var uv := Vector2(ponto.x, ponto.y) / ponto.z
		if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
			continue
		var posicao := _origens_atlas[indice] + uv * _tamanho_captura
		# Não deixar a margem transparente de um plano bloquear outra mão.
		var sobre_carta := false
		for carta in _maos_erguidas[indice].obter_cartas():
			if carta.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			var local := carta.get_global_transform_with_canvas().affine_inverse() * posicao
			if Rect2(Vector2.ZERO, carta.size).has_point(local):
				sobre_carta = true
				break
		if not sobre_carta:
			continue
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


func _ajustar_enquadramento() -> void:
	var margem := _painel.size.x if _painel.visible else 0.0
	var area := Vector2(maxf(size.x - margem, 1.0), size.y)
	var fator := maxf(minf(area.x / REFERENCIA.x, area.y / REFERENCIA.y), 0.001)
	_composicao.scale = Vector2.ONE * fator
	_composicao.position = Vector2(margem, 0) + (area - REFERENCIA * fator) / 2.0
	($Guia as Label).offset_left = margem + 18.0


func _montar_painel() -> void:
	_texto("Mãos erguidas", 20)
	_texto("Adversários na perspectiva da mesa; sua mão perto da câmera, com ajustes independentes.")
	_botao("Ocultar controles · Tab", _alternar_painel)
	_primeiro_plano = CheckBox.new()
	_primeiro_plano.text = "Mão inferior em primeiro plano"
	_primeiro_plano.button_pressed = true
	_controles_ui.add_child(_primeiro_plano)
	_primeiro_plano.toggled.connect(_alterar_modo_visual)
	_sombras_melhoradas = CheckBox.new()
	_sombras_melhoradas.text = "Sombras projetadas no tampo"
	_sombras_melhoradas.button_pressed = true
	_controles_ui.add_child(_sombras_melhoradas)
	_sombras_melhoradas.toggled.connect(_alterar_modo_visual)
	_montar_fonte()
	_seletor = OptionButton.new()
	for nome in NOMES:
		_seletor.add_item("Mão " + nome.to_lower())
	_controles_ui.add_child(_seletor)
	_seletor.item_selected.connect(_selecionar_mao)
	_texto("Ajustes básicos", 16)
	_ajuste("posicao_x", "Posição horizontal", 1, "%")
	_ajuste("posicao_y", "Posição vertical", 1, "%")
	_ajuste("tamanho", "Tamanho uniforme", 0.05)
	_ajuste("giro", "Giro na mesa", 1, "°")
	_ajuste("inclinacao", "Erguer a mão", 1, "°")
	_ajuste("altura", "Altura do apoio", 1)
	_texto("Inferior livre: posição na tela, tamanho, inclinação local e proximidade. Adversários: posição, inclinação e altura sobre a mesa. Os dois perfis da inferior são guardados separadamente.")
	_montar_avancados()
	_comparar = CheckBox.new()
	_comparar.text = "Comparar mãos da mesa apoiadas"
	_controles_ui.add_child(_comparar)
	_comparar.toggled.connect(_comparar_planas)
	_botao("Restaurar mão selecionada", _restaurar_mao)
	_botao("Restaurar referência completa", _restaurar_todas)
	_nome = LineEdit.new()
	_nome.placeholder_text = "Nome do conjunto"
	_nome.max_length = 80
	_controles_ui.add_child(_nome)
	_notas = TextEdit.new()
	_notas.custom_minimum_size.y = 90
	_notas.placeholder_text = "O que funcionou? O que ficou estranho?"
	_notas.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_controles_ui.add_child(_notas)
	_botao("Salvar conjunto", _salvar)
	_lista = OptionButton.new()
	_controles_ui.add_child(_lista)
	_carregar = _botao("Carregar conjunto selecionado", _carregar_teste)
	_mensagem = _texto("Começa na referência, sem importar os presets antigos.")


func _texto(texto: String, tamanho: int = 13) -> Label:
	var legenda := Label.new()
	legenda.text = texto
	legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legenda.add_theme_font_size_override("font_size", tamanho)
	_controles_ui.add_child(legenda)
	return legenda


func _botao(texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.pressed.connect(acao)
	_controles_ui.add_child(botao)
	return botao


func _configuracao_fonte() -> Dictionary:
	var dimensoes := Vector2(_mesa.tamanho_plano)
	return {"localizada": usar_fonte_localizada, "x": posicao_fonte.x / dimensoes.x * 100.0,
		"y": posicao_fonte.y / dimensoes.y * 100.0, "altura": posicao_fonte.z}


func _montar_fonte() -> void:
	_texto("Fonte das sombras", 16)
	_fonte_localizada = CheckBox.new()
	_fonte_localizada.text = "Fonte em ponto específico"
	_fonte_localizada.button_pressed = usar_fonte_localizada
	_controles_ui.add_child(_fonte_localizada)
	_fonte_localizada.toggled.connect(_alternar_tipo_fonte)
	_campos_fonte = VBoxContainer.new()
	_campos_fonte.visible = usar_fonte_localizada
	_controles_ui.add_child(_campos_fonte)
	var anterior := _controles_ui
	_controles_ui = _campos_fonte
	_texto("Posição no plano da mesa: 0% a 100% vai de uma borda à outra. Pode ficar fora da mesa. A fonte é invisível e só altera as sombras.")
	for chave in LIMITES_FONTE:
		var legenda := {"x": "Luz · horizontal", "y": "Luz · profundidade", "altura": "Luz · altura sobre a mesa"}
		_texto(legenda[chave])
		var numero := SpinBox.new()
		numero.min_value = LIMITES_FONTE[chave].x
		numero.max_value = LIMITES_FONTE[chave].y
		numero.step = 5.0 if chave == "altura" else 1.0
		numero.suffix = "" if chave == "altura" else "%"
		_controles_ui.add_child(numero)
		var controle := HSlider.new()
		controle.min_value = numero.min_value
		controle.max_value = numero.max_value
		controle.step = numero.step
		controle.share(numero)
		_controles_ui.add_child(controle)
		_controles_fonte[chave] = controle
		controle.value_changed.connect(_alterar_fonte.bind(chave))
	_botao("Restaurar fonte", _restaurar_fonte)
	_controles_ui = anterior
	_texto("Desligar a fonte localizada compara com a direção fixa anterior. A inferior livre não lança sombra no tampo.")
	_mostrar_fonte()


func _mostrar_fonte() -> void:
	var atualizando := _atualizando_ui
	_atualizando_ui = true
	var configuracao := _configuracao_fonte()
	for chave in LIMITES_FONTE:
		(_controles_fonte[chave] as HSlider).value = float(configuracao[chave])
	_fonte_localizada.set_pressed_no_signal(usar_fonte_localizada)
	_campos_fonte.visible = usar_fonte_localizada
	_atualizando_ui = atualizando


func _alternar_tipo_fonte(ativo: bool) -> void:
	usar_fonte_localizada = ativo
	_campos_fonte.visible = ativo
	_projetar_maos()


func _alterar_fonte(valor: float, chave: String) -> void:
	if _atualizando_ui:
		return
	match chave:
		"x": posicao_fonte.x = valor / 100.0 * _mesa.tamanho_plano.x
		"y": posicao_fonte.y = valor / 100.0 * _mesa.tamanho_plano.y
		"altura": posicao_fonte.z = valor
	_projetar_maos()


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
	_mostrar_fonte()


func _restaurar_fonte() -> void:
	_aplicar_configuracao_fonte(_padrao_fonte)
	_projetar_maos()


func _ajuste(chave: String, texto: String, passo: float, unidade: String = "") -> void:
	var bloco := VBoxContainer.new()
	var linha := HBoxContainer.new()
	var legenda := Label.new()
	legenda.text = texto
	legenda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(legenda)
	var numero := SpinBox.new()
	numero.custom_minimum_size.x = 85
	numero.min_value = LIMITES[chave].x
	numero.max_value = LIMITES[chave].y
	numero.step = passo
	numero.suffix = unidade
	linha.add_child(numero)
	bloco.add_child(linha)
	var controle := HSlider.new()
	controle.min_value = numero.min_value
	controle.max_value = numero.max_value
	controle.step = passo
	controle.share(numero)
	bloco.add_child(controle)
	_controles_ui.add_child(bloco)
	_controles[chave] = controle
	_legendas_basicas[chave] = legenda
	controle.value_changed.connect(_alterar.bind(chave))


func _mostrar_perfil() -> void:
	_atualizando_ui = true
	var livre := _selecionada == 0 and _primeiro_plano.button_pressed
	var perfil := _perfil_em_edicao()
	for chave in LIMITES:
		var controle := _controles[chave] as HSlider
		var limites := _limite_basico(chave, livre)
		controle.min_value = limites.x
		controle.max_value = limites.y
		controle.value = float(perfil[chave])
	(_legendas_basicas["giro"] as Label).text = "Giro da mão" if livre else "Giro na mesa"
	(_legendas_basicas["inclinacao"] as Label).text = "Inclinação local" if livre else "Erguer a mão"
	(_legendas_basicas["altura"] as Label).text = "Aproximar da câmera" if livre else "Altura do apoio"
	var avancados: Dictionary = _perfis[_selecionada]["avancados"]
	for chave in NUMERICOS_AVANCADOS:
		(_controles_avancados[chave] as HSlider).value = float(avancados[chave])
	for chave in OPCOES_AVANCADAS:
		(_controles_avancados[chave] as CheckBox).set_pressed_no_signal(bool(avancados[chave]))
	_atualizando_ui = false
	_atualizar_indicadores()


func _selecionar_mao(indice: int) -> void:
	_sair_da_mesa()
	_selecionada = indice
	_mostrar_perfil()


func _alterar(valor: float, chave: String) -> void:
	if _atualizando_ui:
		return
	_sair_da_mesa()
	var perfil := _perfil_em_edicao()
	perfil[chave] = valor
	_projetar_maos()


func _alterar_modo_visual(_ativo: bool) -> void:
	_sair_da_mesa()
	_mostrar_perfil()
	_aplicar_avancados()
	_projetar_maos()


func _comparar_planas(_ativo: bool) -> void:
	_sair_da_mesa()
	_projetar_maos()


func _restaurar_mao() -> void:
	_sair_da_mesa()
	_perfis[_selecionada] = _perfil_inicial(_selecionada)
	_mostrar_perfil()
	_aplicar_avancados(_selecionada)
	_projetar_maos()


func _restaurar_todas() -> void:
	_sair_da_mesa()
	for indice in range(4):
		_perfis[indice] = _perfil_inicial(indice)
	_comparar.set_pressed_no_signal(false)
	_primeiro_plano.set_pressed_no_signal(true)
	_sombras_melhoradas.set_pressed_no_signal(true)
	_aplicar_configuracao_fonte(_padrao_fonte)
	_mostrar_perfil()
	_aplicar_avancados()
	_projetar_maos()


func _alternar_painel() -> void:
	_sair_da_mesa()
	_painel.visible = not _painel.visible
	var foco := get_viewport().gui_get_focus_owner()
	if foco != null:
		foco.release_focus()
	_ajustar_enquadramento()


func _input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _painel.visible and _painel.get_global_rect().has_point(get_global_mouse_position()):
			if evento.pressed:
				var sentido := -1.0 if evento.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_rolagem.get_v_scroll_bar().value += sentido * 40.0 * evento.factor
			get_viewport().set_input_as_handled()
			return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_TAB:
		_alternar_painel()
		get_viewport().set_input_as_handled()


func _ler_testes() -> void:
	if FileAccess.file_exists(_arquivo_testes()):
		var arquivo := FileAccess.open(_arquivo_testes(), FileAccess.READ)
		if arquivo != null:
			var dados: Variant = JSON.parse_string(arquivo.get_as_text())
			if dados is Dictionary:
				for nome in dados:
					var perfil: Variant = dados[nome]
					if perfil is Dictionary and perfil.get("maos") is Array and perfil["maos"].size() == 4:
						var valido := true
						for mao in perfil["maos"]:
							if not mao is Dictionary:
								valido = false
								break
						if valido:
							_testes[String(nome)] = perfil
	_atualizar_lista()


func _arquivo_testes() -> String:
	return ARQUIVO_TESTES


func _atualizar_lista(nome: String = "") -> void:
	_lista.clear()
	var nomes := _testes.keys()
	nomes.sort()
	for salvo in nomes:
		_lista.add_item(String(salvo))
		if salvo == nome:
			_lista.select(_lista.item_count - 1)
	_carregar.disabled = nomes.is_empty()
	if nomes.is_empty():
		_lista.add_item("Nenhum conjunto salvo")
		_lista.set_item_disabled(0, true)


func _salvar() -> void:
	var nome := _nome.text.strip_edges()
	if nome.is_empty():
		_mensagem.text = "Dê um nome ao conjunto antes de salvar."
		return
	var arquivo := FileAccess.open(_arquivo_testes(), FileAccess.WRITE)
	if arquivo == null:
		_mensagem.text = "Não foi possível salvar."
		return
	var alteracoes: Array[Dictionary] = []
	for indice in range(4):
		alteracoes.append(_alteracoes_avancadas(indice))
	_testes[nome] = {"maos": _perfis.duplicate(true), "notas": _notas.text,
		"alteracoes_avancadas": alteracoes, "inferior_livre": _primeiro_plano.button_pressed,
		"sombras_tampo": _sombras_melhoradas.button_pressed, "fonte_sombra": _configuracao_fonte()}
	_testes[nome].merge(_parametros_adicionais_teste(), true)
	arquivo.store_string(JSON.stringify(_testes, "\t"))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	_atualizar_lista(nome)
	_mensagem.text = "Salvo: " + nome if erro == OK else "Falha ao gravar; o conjunto está apenas nesta sessão."


func _parametros_adicionais_teste() -> Dictionary:
	return {}


func _carregar_teste() -> void:
	if _testes.is_empty():
		return
	_sair_da_mesa()
	var nome := _lista.get_item_text(_lista.selected)
	var perfil: Dictionary = _testes[nome]
	_aplicar_teste(perfil, nome)


func _aplicar_teste(perfil: Dictionary, nome: String) -> void:
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
	_primeiro_plano.set_pressed_no_signal(bool(perfil.get("inferior_livre", true)))
	_sombras_melhoradas.set_pressed_no_signal(bool(perfil.get("sombras_tampo", true)))
	var fonte: Variant = perfil.get("fonte_sombra", {})
	_aplicar_configuracao_fonte(fonte if fonte is Dictionary else {})
	_nome.text = nome
	_notas.text = String(perfil.get("notas", ""))
	_comparar.set_pressed_no_signal(false)
	_mostrar_perfil()
	_aplicar_avancados()
	_projetar_maos()
	_mensagem.text = "Carregado: " + nome


func _montar_avancados() -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.24, 0.045, 0.055)
	estilo.border_color = Color(0.65, 0.18, 0.20)
	estilo.set_border_width_all(1)
	estilo.set_content_margin_all(10)
	_avancados_botao = Button.new()
	_avancados_botao.text = "▶ Avançados · 0 alterados"
	_controles_ui.add_child(_avancados_botao)
	_avancados_botao.toggle_mode = true
	for estado in ["normal", "hover", "pressed", "focus"]:
		_avancados_botao.add_theme_stylebox_override(estado, estilo)
	_avancados_painel = PanelContainer.new()
	_avancados_painel.add_theme_stylebox_override("panel", estilo)
	_avancados_painel.visible = false
	_controles_ui.add_child(_avancados_painel)
	_avancados_botao.toggled.connect(_mostrar_avancados)
	var conteudo := VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avancados_painel.add_child(conteudo)
	var anterior := _controles_ui
	_controles_ui = conteudo
	_texto("Use só se os básicos não resolverem. Padrão = referência deste laboratório.")
	for chave in NUMERICOS_AVANCADOS:
		var definicao: Array = NUMERICOS_AVANCADOS[chave]
		var bloco := VBoxContainer.new()
		var legenda := Label.new()
		legenda.text = String(definicao[4])
		bloco.add_child(legenda)
		var numero := SpinBox.new()
		numero.min_value = definicao[1]
		numero.max_value = definicao[2]
		numero.step = definicao[3]
		numero.suffix = String(definicao[5])
		bloco.add_child(numero)
		var controle := HSlider.new()
		controle.min_value = numero.min_value
		controle.max_value = numero.max_value
		controle.step = numero.step
		controle.share(numero)
		bloco.add_child(controle)
		conteudo.add_child(bloco)
		_controles_avancados[chave] = controle
		_blocos_avancados[chave] = bloco
		controle.value_changed.connect(_alterar_avancado.bind(chave))
		_indicador_avancado(chave, bloco)
	for chave in OPCOES_AVANCADAS:
		var bloco := VBoxContainer.new()
		var controle := CheckBox.new()
		controle.text = OPCOES_AVANCADAS[chave]
		controle.add_theme_font_size_override("font_size", 12)
		bloco.add_child(controle)
		conteudo.add_child(bloco)
		_controles_avancados[chave] = controle
		controle.toggled.connect(_alterar_avancado.bind(chave))
		_indicador_avancado(chave, bloco)
	_botao("Restaurar só os avançados", _restaurar_avancados)
	_controles_ui = anterior
	_avancados_resumo = _texto("")
	_botao("Copiar alterações avançadas", _copiar_alteracoes)


func _mostrar_avancados(aberto: bool) -> void:
	_avancados_painel.visible = aberto
	_atualizar_indicadores()


func _indicador_avancado(chave: String, bloco: VBoxContainer) -> void:
	var indicador := Label.new()
	indicador.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	indicador.add_theme_font_size_override("font_size", 12)
	bloco.add_child(indicador)
	_indicadores_avancados[chave] = indicador


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


func _valor_avancado(valor: Variant) -> String:
	if valor is bool:
		return "ligado" if valor else "desligado"
	return str(snappedf(float(valor), 0.01))


func _atualizar_indicadores() -> void:
	var alteracoes := _alteracoes_avancadas(_selecionada)
	var padrao := _padrao_avancados(_selecionada)
	for chave in padrao:
		var indicador := _indicadores_avancados[chave] as Label
		indicador.text = ("● Alterado · padrão: " if alteracoes.has(chave) else "✓ Padrão: ") + _valor_avancado(padrao[chave])
		indicador.modulate = Color(1.0, 0.76, 0.30) if alteracoes.has(chave) else Color(0.72, 0.77, 0.72)
		if _perfis[_selecionada]["avancados"][chave] != _avancados_efetivos(_selecionada)[chave]:
			indicador.text = "✓ Sem efeito neste modo"
	var seta := "▼" if _avancados_painel.visible else "▶"
	_avancados_botao.text = "%s Avançados · %d alterados" % [seta, alteracoes.size()]
	_avancados_resumo.text = "Avançados: todos no padrão." if alteracoes.is_empty() else "Alterados: " + ", ".join(PackedStringArray(alteracoes.keys()))
	(_controles_avancados["frentes"] as CheckBox).disabled = _virando_maos[_selecionada]
	var atual: Dictionary = _perfis[_selecionada]["avancados"]
	for eixo in ["x", "y"]:
		var chave: String = "inclinacao_" + eixo
		var gradual := bool(atual[chave + "_progressiva"])
		(_blocos_avancados[chave] as Control).visible = not gradual
		(_blocos_avancados[chave + "_inicio"] as Control).visible = gradual
		(_blocos_avancados[chave + "_fim"] as Control).visible = gradual


func _alterar_avancado(valor: Variant, chave: String) -> void:
	if _atualizando_ui:
		return
	if chave == "frentes" and _virando_maos[_selecionada]:
		_mostrar_perfil()
		return
	_sair_da_mesa()
	_perfis[_selecionada]["avancados"][chave] = valor
	_aplicar_avancados(_selecionada)
	_atualizar_indicadores()
	_projetar_maos()


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
		var livre := indice == 0 and _primeiro_plano.button_pressed
		opcoes["sombras"] = bool(avancados["sombras"]) and (livre or not _sombras_melhoradas.button_pressed)
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
	_atualizar_indicadores()


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


func _restaurar_avancados() -> void:
	_sair_da_mesa()
	_perfis[_selecionada]["avancados"] = _padrao_avancados(_selecionada)
	_mostrar_perfil()
	_aplicar_avancados(_selecionada)
	_projetar_maos()


func _copiar_alteracoes() -> void:
	var linhas := PackedStringArray()
	for indice in range(4):
		var alteracoes := _alteracoes_avancadas(indice)
		linhas.append(NOMES[indice] + ":")
		if alteracoes.is_empty():
			linhas.append("  Todos os avançados no padrão.")
		for chave in alteracoes:
			linhas.append("  %s: %s → %s" % [chave, _valor_avancado(alteracoes[chave]["padrao"]), _valor_avancado(alteracoes[chave]["valor"])])
	linhas.append("\nObservações: " + _notas.text)
	DisplayServer.clipboard_set("\n".join(linhas))
	_mensagem.text = "Alterações das quatro mãos e observações copiadas."
