extends "res://scripts/desenvolvimento/laboratorios/interno/base_perspectiva.gd"

const CENA_COMPRA = preload("res://scenes/main/componentes/monte.tscn")
const CENA_JOGADA = preload("res://scenes/main/componentes/descarte.tscn")
const PLANO_CARTA = preload("res://scripts/desenvolvimento/laboratorios/plano_carta_laboratorio.gd")
# Nome histórico preservado para carregar os conjuntos já salvos.
const ARQUIVO_MOVIMENTOS = "user://laboratorio_transferencias_2_5d.json"
const CAPTURA_PILHA := Vector2(280, 280)
const DESLOCAMENTOS_COMPRA := [Vector2.ZERO, Vector2(4, -3), Vector2(-4, 2), Vector2(2, 4)]
const LIMITES_PILHAS := {
	"x": Vector2(5, 95), "y": Vector2(5, 95), "tamanho": Vector2(0.5, 2.5),
	"giro": Vector2(-180, 180), "espessura": Vector2(0, 40),
	"camadas": Vector2(1, 12), "maximo_visiveis": Vector2(10, 20), "desalinhamento": Vector2(0, 3),
	"variacao_x": Vector2(0, 30), "variacao_y": Vector2(0, 30), "variacao_rotacao": Vector2(0, 30),
	"intensidade_sombra": Vector2(0, 0.8), "suavidade_sombra": Vector2(0, 8)}
const ALTURA_MAXIMA_DESCARTE := 32.0
const ORDEM_DESCARTE := 5
const ORDEM_MAOS := 60
const ORDEM_TRANSITO := 80
const PADRAO_SOMBRA_INFERIOR := {"intensidade": 14.0, "x": -2.0, "y": 3.0}
const LIMITES_SOMBRA_INFERIOR := {
	"intensidade": Vector2(0, 100), "x": Vector2(-20, 20), "y": Vector2(-20, 20)}
const PRESET_BASE := "res://scripts/desenvolvimento/laboratorios/presets/teste_8.json"
const PADRAO_MESA := {"formato": 1.0, "largura": 1600.0, "profundidade": 700.0,
	"x": 50.0, "y": 55.0, "profundidade_camera": 400.0, "perspectiva": 50.0,
	"moldura": 30.0, "espessura": 100.0}
const LIMITES_MESA := {"largura": Vector2(400, 2400), "profundidade": Vector2(300, 1050),
	"x": Vector2(-25, 125), "y": Vector2(-25, 125), "profundidade_camera": Vector2(60, 650),
	"perspectiva": Vector2(35, 100), "moldura": Vector2(0, 120), "espessura": Vector2(0, 100)}
const PADRAO_ENQUADRAMENTO := {"zoom": 100.0, "x": 0.0, "y": 0.0}
const LIMITES_ENQUADRAMENTO := {"zoom": Vector2(50, 180), "x": Vector2(-50, 50), "y": Vector2(-50, 50)}
const PADRAO_ILUMINACAO := {"ativa": true, "ambiente": 60.0, "intensidade": 55.0,
	"minimo_cartas": 72.0, "abrangencia": 100.0, "temperatura": 15.0, "x": 50.0, "y": 45.0}
const LIMITES_ILUMINACAO := {"ambiente": Vector2(0, 100), "intensidade": Vector2(0, 100),
	"minimo_cartas": Vector2(0, 100),
	"abrangencia": Vector2(30, 200), "temperatura": Vector2(0, 100),
	"x": Vector2(-50, 150), "y": Vector2(-50, 150)}
const PRESETS_MESAS := "res://scripts/desenvolvimento/laboratorios/presets/mesas_arredondadas.json"

@export_group("Transferências")
@export_range(0.8, 2.0, 0.05) var duracao_trajeto := 1.0
@export_range(0.0, 160.0, 5.0) var altura_trajeto := 65.0
@export var conjunto_visual_inicial := "teste 5"
@export var centro_compra := Vector2(0.42, 0.57)
@export var centro_jogada := Vector2(0.58, 0.57)

@export_group("Descarte")
@export_range(10, 20, 1) var maximo_cartas_visiveis_descarte := 20
@export var sombras_entre_cartas := true

var _compra: MonteVisual
var _jogada: DescarteVisual
var _viewport_pilhas: SubViewport
var _planos_pilhas: Array[Node2D] = []
var _cartas_descarte: Dictionary = {}
var _perfis_pilhas: Array[Dictionary] = []
var _seletor_pilha: OptionButton
var _controles_pilhas: Dictionary = {}
var _legenda_espessura: Label
var _bloco_camadas: VBoxContainer
var _bloco_maximo_visiveis: VBoxContainer
var _bloco_desalinhamento: VBoxContainer
var _blocos_variacao: Array[VBoxContainer] = []
var _comparar_sombras_cartas: CheckBox
var _captura_inferior: SubViewport
var _sombra_inferior := PADRAO_SOMBRA_INFERIOR.duplicate()
var _controles_sombra_inferior: Dictionary = {}
var _pilhas_prontas := false
var _baralho_visual := Baralho_Logico.new()
var _baralho_pronto := false
var _dados_por_instancia: Dictionary = {}
var _transitos: Dictionary = {}
var _comandos_trajeto: VBoxContainer
var _escolha_jogada: OptionButton
var _estado_trajeto: Label
var _importacoes: Dictionary = {}
var _lista_importacoes: OptionButton
var _edicao_bloqueada := false
var _controles_bloqueados: Array[Dictionary] = []
var _ajustes_mesa := PADRAO_MESA.duplicate()
var _enquadramento := PADRAO_ENQUADRAMENTO.duplicate()
var _controles_mesa: Dictionary = {}
var _controles_enquadramento: Dictionary = {}
var _formato_mesa: OptionButton
var _ver_inteira: CheckBox
var _area_enquadramento: Control
var _secoes: Dictionary = {}
var _iluminacao := PADRAO_ILUMINACAO.duplicate()
var _controles_iluminacao: Dictionary = {}
var _comparar_iluminacao: CheckBox
var _manter_iluminacao: CheckBox
var _inversa_iluminacao := Basis.IDENTITY
var _versao_iluminacao := 0


func _ready() -> void:
	_perfis_pilhas = [_padrao_pilha(0), _padrao_pilha(1)]
	_area_enquadramento = Control.new()
	_area_enquadramento.name = "AreaEnquadramento"
	_area_enquadramento.clip_contents = true
	_area_enquadramento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_area_enquadramento)
	move_child(_area_enquadramento, 1)
	_area_enquadramento.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_composicao.reparent(_area_enquadramento, false)
	super._ready()
	_montar_pilhas()
	_ler_importacoes()
	var base: Variant = _testes.get("teste 8", JSON.parse_string(FileAccess.get_file_as_string(PRESET_BASE)))
	if base is Dictionary and base.get("maos") is Array and base["maos"].size() == 4:
		_aplicar_teste(base, "Mesa arredondada 1")
		_mensagem.text = "Base: teste 8. Salve a mesa com um novo nome para guardar a referência."
	elif _importacoes.has(conjunto_visual_inicial):
		_aplicar_teste(_importacoes[conjunto_visual_inicial], conjunto_visual_inicial)
		_mensagem.text = "Restaurado: " + conjunto_visual_inicial + ". Testes salvos preservados."
	_atualizar_pilhas()
	_atualizar_estado_trajeto()
	_atualizar_iluminacao()


func _arquivo_testes() -> String:
	return ARQUIVO_MOVIMENTOS


func _ler_testes() -> void:
	super._ler_testes()
	# As cópias aprovadas ficam disponíveis mesmo sem o arquivo local do Godot.
	var presets: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESETS_MESAS))
	if presets is Dictionary:
		for nome in presets:
			var perfil: Variant = presets[nome]
			if not _testes.has(nome) and perfil is Dictionary and perfil.get("maos") is Array and perfil["maos"].size() == 4:
				_testes[nome] = perfil.duplicate(true)
	_atualizar_lista()


func _parametros_adicionais_teste() -> Dictionary:
	return {"trajeto": {"duracao": duracao_trajeto, "altura": altura_trajeto,
		"compra": [centro_compra.x, centro_compra.y], "descarte": [centro_jogada.x, centro_jogada.y]},
		"pilhas": _perfis_pilhas.duplicate(true), "sombras_entre_cartas": sombras_entre_cartas,
		"sombra_inferior": _sombra_inferior.duplicate(), "mesa": _ajustes_mesa.duplicate(),
		"enquadramento": _enquadramento.duplicate(), "iluminacao": _iluminacao.duplicate()}


func _padrao_pilha(indice: int) -> Dictionary:
	var centro := centro_compra if indice == 0 else centro_jogada
	return {"x": centro.x * 100.0, "y": centro.y * 100.0, "tamanho": 1.0, "giro": 0.0,
		"espessura": 12.0 if indice == 0 else 0.8, "camadas": 8.0,
		"maximo_visiveis": float(maximo_cartas_visiveis_descarte),
		"desalinhamento": 0.15 if indice == 0 else 1.0,
		"variacao_x": 0.0, "variacao_y": 6.0, "variacao_rotacao": 10.0,
		"intensidade_sombra": intensidade_sombra, "suavidade_sombra": suavidade_sombra}


func _aplicar_teste(perfil: Dictionary, nome: String) -> void:
	if is_instance_valid(_manter_iluminacao) and not _manter_iluminacao.button_pressed:
		_iluminacao = _validar_ajustes(perfil.get("iluminacao", {}), PADRAO_ILUMINACAO, LIMITES_ILUMINACAO)
		var ativa: Variant = perfil.get("iluminacao", {}).get("ativa", true) if perfil.get("iluminacao") is Dictionary else true
		_iluminacao["ativa"] = ativa if ativa is bool else true
		_mostrar_iluminacao()
		_versao_iluminacao += 1
	_ajustes_mesa = _validar_ajustes(perfil.get("mesa", {}), PADRAO_MESA, LIMITES_MESA)
	var formato: Variant = perfil.get("mesa", {}).get("formato", 1) if perfil.get("mesa") is Dictionary else 1
	_ajustes_mesa["formato"] = 1.0
	if (formato is float or formato is int) and is_finite(float(formato)):
		_ajustes_mesa["formato"] = float(clampi(roundi(float(formato)), 0, 1))
	_enquadramento = _validar_ajustes(perfil.get("enquadramento", {}), PADRAO_ENQUADRAMENTO, LIMITES_ENQUADRAMENTO)
	_ver_inteira.set_pressed_no_signal(false)
	_aplicar_mesa()
	_mostrar_ajustes_ambiente()
	_sombra_inferior = PADRAO_SOMBRA_INFERIOR.duplicate()
	var contato: Variant = perfil.get("sombra_inferior", {})
	if contato is Dictionary:
		for chave in LIMITES_SOMBRA_INFERIOR:
			var valor: Variant = contato.get(chave)
			if (valor is float or valor is int) and is_finite(float(valor)):
				var limites: Vector2 = LIMITES_SOMBRA_INFERIOR[chave]
				_sombra_inferior[chave] = clampf(float(valor), limites.x, limites.y)
	_mostrar_sombra_inferior()
	var sombras: Variant = perfil.get("sombras_entre_cartas", true)
	sombras_entre_cartas = sombras if sombras is bool else true
	_comparar_sombras_cartas.set_pressed_no_signal(sombras_entre_cartas)
	var trajeto: Variant = perfil.get("trajeto", {})
	if trajeto is Dictionary:
		for chave in ["duracao", "altura"]:
			var valor: Variant = trajeto.get(chave)
			if (valor is float or valor is int) and is_finite(float(valor)):
				if chave == "duracao":
					duracao_trajeto = clampf(float(valor), 0.8, 2.0)
				else:
					altura_trajeto = clampf(float(valor), 0.0, 160.0)
		for chave in ["compra", "descarte"]:
			var valor: Variant = trajeto.get(chave)
			if not valor is Array or valor.size() != 2:
				continue
			if not ((valor[0] is float or valor[0] is int) and (valor[1] is float or valor[1] is int)):
				continue
			if not is_finite(float(valor[0])) or not is_finite(float(valor[1])):
				continue
			var centro := Vector2(clampf(float(valor[0]), 0.05, 0.95), clampf(float(valor[1]), 0.05, 0.95))
			if chave == "compra":
				centro_compra = centro
			else:
				centro_jogada = centro
	var pilhas: Variant = perfil.get("pilhas", [])
	for indice in range(2):
		var ajustes := _padrao_pilha(indice)
		if pilhas is Array and pilhas.size() == 2 and pilhas[indice] is Dictionary:
			for chave in LIMITES_PILHAS:
				var valor: Variant = pilhas[indice].get(chave)
				if (valor is float or valor is int) and is_finite(float(valor)):
					var limites: Vector2 = LIMITES_PILHAS[chave]
					if chave == "espessura" and indice == 1:
						limites.y = 3.0
					ajustes[chave] = clampf(float(valor), limites.x, limites.y)
			if indice == 1:
				var antigo: Variant = pilhas[indice].get("desalinhamento")
				if (antigo is float or antigo is int) and is_finite(float(antigo)):
					var intensidade := clampf(float(antigo), 0.0, 3.0)
					if not pilhas[indice].has("variacao_y"):
						ajustes["variacao_y"] = intensidade * 4.0
					if not pilhas[indice].has("variacao_rotacao"):
						ajustes["variacao_rotacao"] = intensidade * 5.0
		_perfis_pilhas[indice] = ajustes
	_sincronizar_centros_pilhas()
	_aplicar_ajustes_pilhas()
	_mostrar_pilha()
	for mao in _maos_erguidas:
		mao.duracao_reorganizacao = duracao_trajeto
	super._aplicar_teste(perfil, nome)
	_atualizar_iluminacao()
	if _manter_iluminacao.button_pressed:
		_mensagem.text += " · Luz atual mantida para comparação."


func _montar_mao(indice: int) -> void:
	if not _baralho_pronto:
		_baralho_visual.criar_baralho()
		_baralho_pronto = true
	super._montar_mao(indice)
	_poligonos[indice].z_index = ORDEM_MAOS + [3, 0, 1, 2][indice]
	if indice == 0:
		_captura_inferior = SubViewport.new()
		_captura_inferior.name = "CapturaMaoInferior"
		_captura_inferior.disable_3d = true
		_captura_inferior.transparent_bg = true
		_captura_inferior.size_2d_override_stretch = true
		_captura_inferior.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		_composicao.add_child(_captura_inferior)
		_dimensionar_captura_inferior()
		_maos_erguidas[0].reparent(_captura_inferior, false)
		_poligonos[0].texture = _captura_inferior.get_texture()
		_sombras_tampo[0].texture = _captura_inferior.get_texture()
	for carta in _maos_erguidas[indice].obter_cartas():
		var dados := _baralho_visual.comprar_carta().para_dados()
		_dados_por_instancia[carta.get_instance_id()] = dados
		carta.setup_dados(dados)
	_maos_erguidas[indice].duracao_reorganizacao = duracao_trajeto


func _dados_da_carta(carta: Carta, _indice: int, _numero: int) -> Dictionary:
	return _dados_por_instancia.get(carta.get_instance_id(), {})


func _aplicar_avancados(somente: int = -1) -> void:
	super._aplicar_avancados(somente)
	for indice in range(_maos_erguidas.size()):
		if somente == -1 or somente == indice:
			_maos_erguidas[indice].definir_hover_habilitado(indice == 0)
	if somente == -1 or somente == 0:
		_maos_erguidas[0].definir_sombras_visiveis(bool(_avancados_efetivos(0)["sombras"]))
		for carta in _maos_erguidas[0].obter_cartas():
			_configurar_sombra_inferior(carta)


func _configurar_sombra_inferior(carta: Carta) -> void:
	carta.configurar_sombra(Vector2(_sombra_inferior["x"], _sombra_inferior["y"]),
		float(_sombra_inferior["intensidade"]) / 100.0, false)


func _dimensionar_captura_inferior() -> void:
	if is_instance_valid(_captura_inferior):
		_captura_inferior.size_2d_override = Vector2i(_tamanho_captura)
		# A chegada mantém os dois pixels por unidade da captura em trânsito.
		_captura_inferior.size = Vector2i(_tamanho_captura * 2.0)


func _atualizar_captura() -> void:
	super._atualizar_captura()
	_dimensionar_captura_inferior()


func _aplicar_projecao(poligono: Polygon2D, matriz: Basis, indice: int) -> bool:
	var visivel := super._aplicar_projecao(poligono, matriz, indice)
	_configurar_material_iluminacao(poligono.material as ShaderMaterial, true)
	if indice == 0 and is_instance_valid(_captura_inferior):
		(poligono.material as ShaderMaterial).set_shader_parameter("regiao_textura", Vector4(0, 0, 1, 1))
	return visivel


func _viewport_da_mao(indice: int) -> SubViewport:
	return _captura_inferior if indice == 0 and is_instance_valid(_captura_inferior) else _atlas


func _atualizar_indicadores() -> void:
	super._atualizar_indicadores()
	if _edicao_bloqueada:
		(_controles_avancados["frentes"] as CheckBox).disabled = true


func _montar_painel() -> void:
	_texto("Laboratório Perspectiva", 20)
	_texto("Base teste 8. Ajuste a luz em Iluminação e compare seus conjuntos de mesa.")
	_botao("Ocultar controles · Tab", _alternar_painel)
	_seletor = OptionButton.new()
	for nome in NOMES:
		_seletor.add_item("Mão " + nome.to_lower())
	_controles_ui.add_child(_seletor)
	_seletor.item_selected.connect(_selecionar_mao)
	_comandos_trajeto = VBoxContainer.new()
	_controles_ui.add_child(_comandos_trajeto)
	var anterior := _controles_ui
	_controles_ui = _comandos_trajeto
	_botao("Comprar para a mão selecionada · D", _comprar)
	_botao("Jogar da mão selecionada · J", _jogar_carta)
	_escolha_jogada = OptionButton.new()
	for texto in ["Jogar a primeira", "Jogar a carta do meio", "Jogar a última"]:
		_escolha_jogada.add_item(texto)
	_controles_ui.add_child(_escolha_jogada)
	_botao("Esvaziar mãos e descarte · R", _esvaziar)
	_estado_trajeto = _texto("")
	_controles_ui = anterior
	_controles_ui = _criar_secao("Mesa", true)
	_montar_controles_mesa()
	_controles_ui = anterior
	_controles_ui = _criar_secao("Enquadramento", true)
	_montar_controles_enquadramento()
	_controles_ui = anterior
	_controles_ui = _criar_secao("Mãos e cartas")
	_primeiro_plano = CheckBox.new()
	_primeiro_plano.text = "Mão inferior em primeiro plano"
	_primeiro_plano.button_pressed = true
	_controles_ui.add_child(_primeiro_plano)
	_primeiro_plano.toggled.connect(_alterar_modo_visual)
	_texto("Ajustes da mão selecionada", 16)
	_ajuste("posicao_x", "Posição horizontal", 1, "%")
	_ajuste("posicao_y", "Posição vertical", 1, "%")
	_texto("No modo mesa, posições menores afastam para a esquerda ou para o fundo. Valores fora de 0–100% permitem alcançar a área ampliada do tampo.")
	_ajuste("tamanho", "Tamanho uniforme", 0.05)
	_ajuste("giro", "Giro na mesa", 1, "°")
	_ajuste("inclinacao", "Erguer a mão", 1, "°")
	_ajuste("altura", "Altura do apoio", 1)
	_montar_avancados()
	_comparar = CheckBox.new()
	_comparar.text = "Comparar mãos da mesa apoiadas"
	_controles_ui.add_child(_comparar)
	_comparar.toggled.connect(_comparar_planas)
	_botao("Restaurar mão selecionada", _restaurar_mao)
	_controles_ui = anterior
	_controles_ui = _criar_secao("Monte e descarte")
	_montar_controles_pilhas()
	_controles_ui = anterior
	_controles_ui = _criar_secao("Iluminação", true)
	_montar_controles_iluminacao()
	_controles_ui = anterior
	_controles_ui = _criar_secao("Luz e sombras")
	_sombras_melhoradas = CheckBox.new()
	_sombras_melhoradas.text = "Sombras projetadas no tampo"
	_sombras_melhoradas.button_pressed = true
	_controles_ui.add_child(_sombras_melhoradas)
	_sombras_melhoradas.toggled.connect(_alterar_modo_visual)
	_montar_fonte()
	_montar_controles_sombra_inferior()
	_controles_ui = anterior
	_controles_ui = _criar_secao("Conjuntos", true)
	_manter_iluminacao = CheckBox.new()
	_manter_iluminacao.text = "Comparar mantendo a luz atual"
	_manter_iluminacao.button_pressed = false
	_controles_ui.add_child(_manter_iluminacao)
	_texto("Carregar recupera também a iluminação salva. Marque esta opção para comparar composições com a mesma luz. Conjuntos antigos usam a luz inicial.")
	_nome = LineEdit.new()
	_nome.placeholder_text = "Nome do conjunto"
	_nome.max_length = 80
	_controles_ui.add_child(_nome)
	_notas = TextEdit.new()
	_notas.custom_minimum_size.y = 90
	_notas.placeholder_text = "O que funcionou? O que ficou estranho?"
	_notas.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_controles_ui.add_child(_notas)
	_botao("Salvar conjunto completo", _salvar)
	_lista = OptionButton.new()
	_controles_ui.add_child(_lista)
	_carregar = _botao("Carregar conjunto completo", _carregar_teste)
	_botao("Voltar à base teste 8", _restaurar_base)
	_botao("Restaurar padrões completos", _restaurar_todas)
	_mensagem = _texto("Salvar guarda mesa, enquadramento, mãos, pilhas, sombras e iluminação juntos.")
	_texto("Importar conjuntos visuais anteriores", 16)
	_lista_importacoes = OptionButton.new()
	_controles_ui.add_child(_lista_importacoes)
	_botao("Importar conjunto visual selecionado", _importar_visual)
	_controles_ui = anterior


func _criar_secao(titulo: String, aberta: bool = false) -> VBoxContainer:
	var botao := Button.new()
	botao.toggle_mode = true
	botao.button_pressed = aberta
	botao.text = ("▼ " if aberta else "▶ ") + titulo
	botao.set_meta("secao", true)
	_controles_ui.add_child(botao)
	var conteudo := VBoxContainer.new()
	conteudo.visible = aberta
	_controles_ui.add_child(conteudo)
	_secoes[titulo] = conteudo
	botao.toggled.connect(func(ativo: bool):
		conteudo.visible = ativo
		botao.text = ("▼ " if ativo else "▶ ") + titulo)
	return conteudo


func _controle_ambiente(chave: String, legenda: String, limites: Vector2,
		valor: float, destino: Dictionary, callback: Callable, passo: float = 1.0, unidade: String = "") -> void:
	_texto(legenda)
	var numero := SpinBox.new()
	numero.min_value = limites.x
	numero.max_value = limites.y
	numero.step = passo
	numero.suffix = unidade
	_controles_ui.add_child(numero)
	var controle := HSlider.new()
	controle.min_value = limites.x
	controle.max_value = limites.y
	controle.step = passo
	controle.share(numero)
	controle.value = valor
	_controles_ui.add_child(controle)
	destino[chave] = controle
	controle.value_changed.connect(callback.bind(chave))


func _montar_controles_mesa() -> void:
	_formato_mesa = OptionButton.new()
	_formato_mesa.add_item("Tampo retangular")
	_formato_mesa.add_item("Tampo arredondado (círculo/oval)")
	_formato_mesa.select(1)
	_controles_ui.add_child(_formato_mesa)
	_formato_mesa.item_selected.connect(func(indice: int):
		if not _atualizando_ui and _transitos.is_empty():
			_ajustes_mesa["formato"] = float(indice)
			_aplicar_mesa())
	_texto("Largura e profundidade iguais formam um círculo no espaço da mesa. A perspectiva o faz parecer oval. Estes tamanhos não esticam as cartas.")
	var legendas := {"largura": "Largura do tampo", "profundidade": "Profundidade do tampo",
		"x": "Posição horizontal", "y": "Posição vertical", "profundidade_camera": "Profundidade na tela",
		"perspectiva": "Largura distante da projeção", "moldura": "Largura da moldura", "espessura": "Espessura frontal"}
	for chave in LIMITES_MESA:
		_controle_ambiente(chave, legendas[chave], LIMITES_MESA[chave], _ajustes_mesa[chave],
			_controles_mesa, _alterar_mesa, 5.0 if chave in ["largura", "profundidade", "profundidade_camera"] else 1.0,
			"%" if chave in ["x", "y", "perspectiva"] else "")
	_texto("Profundidade na tela e largura distante ajustam a perspectiva compartilhada, incluindo as cartas apoiadas.")
	_botao("Restaurar somente a mesa", _restaurar_mesa)


func _montar_controles_enquadramento() -> void:
	var legendas := {"zoom": "Aproximação", "x": "Deslocamento horizontal", "y": "Deslocamento vertical"}
	for chave in LIMITES_ENQUADRAMENTO:
		_controle_ambiente(chave, legendas[chave], LIMITES_ENQUADRAMENTO[chave], _enquadramento[chave],
			_controles_enquadramento, _alterar_enquadramento, 1.0, "%")
	_ver_inteira = CheckBox.new()
	_ver_inteira.text = "Ver composição inteira"
	_controles_ui.add_child(_ver_inteira)
	_ver_inteira.toggled.connect(func(_ativo: bool):
		_sair_da_mesa()
		_ajustar_enquadramento())
	_texto("100% mantém o enquadramento anterior; 75% abre a visão. Aumentar aproxima a cena e pode cortar suas bordas. A visão inteira preserva a aproximação escolhida e não é salva.")
	_botao("Restaurar somente o enquadramento", _restaurar_enquadramento)


func _montar_controles_iluminacao() -> void:
	_comparar_iluminacao = CheckBox.new()
	_comparar_iluminacao.text = "Aplicar iluminação principal"
	_comparar_iluminacao.button_pressed = bool(_iluminacao["ativa"])
	_controles_ui.add_child(_comparar_iluminacao)
	_comparar_iluminacao.toggled.connect(func(ativa: bool):
		_iluminacao["ativa"] = ativa
		_versao_iluminacao += 1
		_atualizar_iluminacao())
	_texto("Um foco amplo acompanha a perspectiva da mesa. Desligue para comparar com a aparência original. Claridade mínima das cartas em 0% permite que elas escureçam totalmente quando não houver luz.")
	var legendas := {"ambiente": "Claridade ambiente", "intensidade": "Intensidade do foco",
		"minimo_cartas": "Claridade mínima das cartas",
		"abrangencia": "Abrangência do foco", "temperatura": "Aquecimento da luz",
		"x": "Centro horizontal na mesa", "y": "Centro em profundidade na mesa"}
	for chave in LIMITES_ILUMINACAO:
		_controle_ambiente(chave, legendas[chave], LIMITES_ILUMINACAO[chave], _iluminacao[chave],
			_controles_iluminacao, _alterar_iluminacao, 1.0, "%")
	_botao("Restaurar somente a iluminação", _restaurar_iluminacao)


func _mostrar_iluminacao() -> void:
	for chave in _controles_iluminacao:
		(_controles_iluminacao[chave] as HSlider).set_value_no_signal(_iluminacao[chave])
	if is_instance_valid(_comparar_iluminacao):
		_comparar_iluminacao.set_pressed_no_signal(bool(_iluminacao["ativa"]))


func _alterar_iluminacao(valor: float, chave: String) -> void:
	_iluminacao[chave] = valor
	_versao_iluminacao += 1
	_atualizar_iluminacao()


func _restaurar_iluminacao() -> void:
	_iluminacao = PADRAO_ILUMINACAO.duplicate()
	_mostrar_iluminacao()
	_versao_iluminacao += 1
	_atualizar_iluminacao()


func _atualizar_iluminacao() -> void:
	if not is_instance_valid(_mesa):
		return
	var transformacao := _composicao.get_global_transform()
	var canvas := Basis(Vector3(transformacao.x.x, transformacao.x.y, 0),
		Vector3(transformacao.y.x, transformacao.y.y, 0), Vector3(transformacao.origin.x, transformacao.origin.y, 1))
	var plano := _matriz_da_mesa(Vector3.ZERO, Vector3(_mesa.tamanho_plano.x, 0, 0),
		Vector3(0, _mesa.tamanho_plano.y, 0))
	var inversa := (canvas * plano).inverse()
	if inversa != _inversa_iluminacao:
		_inversa_iluminacao = inversa
		_versao_iluminacao += 1
	for material in _mesa.obter_materiais_apresentacao():
		_configurar_material_iluminacao(material, false)
	for poligono in _poligonos:
		_configurar_material_iluminacao(poligono.material as ShaderMaterial, true)
	for visual in _planos_pilhas:
		_configurar_material_iluminacao(visual.face.material as ShaderMaterial, true)
	for registro in _cartas_descarte.values() + _transitos.values():
		_configurar_material_iluminacao(registro["visual"].face.material as ShaderMaterial, true)


func _configurar_material_iluminacao(material: ShaderMaterial, cartas: bool) -> void:
	if material.get_meta("versao_iluminacao", -1) == _versao_iluminacao:
		return
	material.set_meta("versao_iluminacao", _versao_iluminacao)
	_enviar_inversa(material, _inversa_iluminacao, "iluminacao_inversa")
	material.set_shader_parameter("iluminacao_ativa", _iluminacao["ativa"])
	material.set_shader_parameter("iluminacao_cartas", cartas)
	material.set_shader_parameter("iluminacao_centro", Vector2(_iluminacao["x"], _iluminacao["y"]) / 100.0)
	for chave in ["ambiente", "intensidade", "minimo_cartas", "abrangencia", "temperatura"]:
		material.set_shader_parameter("iluminacao_" + chave, float(_iluminacao[chave]) / 100.0)


func _validar_ajustes(dados: Variant, padrao: Dictionary, limites: Dictionary) -> Dictionary:
	var ajustes := padrao.duplicate()
	if dados is Dictionary:
		for chave in limites:
			var valor: Variant = dados.get(chave)
			if (valor is float or valor is int) and is_finite(float(valor)):
				ajustes[chave] = clampf(float(valor), limites[chave].x, limites[chave].y)
	return ajustes


func _mostrar_ajustes_ambiente() -> void:
	var anterior := _atualizando_ui
	_atualizando_ui = true
	_formato_mesa.select(roundi(_ajustes_mesa["formato"]))
	for chave in _controles_mesa:
		(_controles_mesa[chave] as HSlider).value = _ajustes_mesa[chave]
	for chave in _controles_enquadramento:
		(_controles_enquadramento[chave] as HSlider).value = _enquadramento[chave]
	_atualizando_ui = anterior
	_ajustar_enquadramento()


func _alterar_mesa(valor: float, chave: String) -> void:
	if _atualizando_ui or not _transitos.is_empty():
		return
	_sair_da_mesa()
	_ajustes_mesa[chave] = valor
	_aplicar_mesa()


func _aplicar_mesa() -> void:
	_mesa.formato = roundi(_ajustes_mesa["formato"])
	_mesa.dimensoes_tampo = Vector2(_ajustes_mesa["largura"], _ajustes_mesa["profundidade"])
	_mesa.position = REFERENCIA * Vector2(_ajustes_mesa["x"], _ajustes_mesa["y"]) / 100.0
	_mesa.profundidade_aparente = _ajustes_mesa["profundidade_camera"]
	_mesa.largura_distante = float(_ajustes_mesa["perspectiva"]) / 100.0
	_mesa.largura_moldura = _ajustes_mesa["moldura"]
	_mesa.espessura = _ajustes_mesa["espessura"]
	_mesa.atualizar_visual()
	_projetar_maos()
	_ajustar_enquadramento()


func _restaurar_mesa() -> void:
	_ajustes_mesa = PADRAO_MESA.duplicate()
	_aplicar_mesa()
	_mostrar_ajustes_ambiente()


func _alterar_enquadramento(valor: float, chave: String) -> void:
	if _atualizando_ui:
		return
	_sair_da_mesa()
	_enquadramento[chave] = valor
	# Editar volta à visão do jogador para que o efeito do controle seja visível.
	_ver_inteira.set_pressed_no_signal(false)
	_ajustar_enquadramento()


func _restaurar_enquadramento() -> void:
	_enquadramento = PADRAO_ENQUADRAMENTO.duplicate()
	_ver_inteira.set_pressed_no_signal(false)
	_mostrar_ajustes_ambiente()


func _restaurar_base() -> void:
	var perfil: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PRESET_BASE))
	_aplicar_teste(perfil, "Mesa arredondada 1")
	_mensagem.text = "Base teste 8 restaurada. Seus conjuntos salvos foram preservados."


func _ajustar_enquadramento() -> void:
	if not is_instance_valid(_area_enquadramento):
		return
	var margem := _painel.size.x if _painel.visible else 0.0
	_area_enquadramento.offset_left = margem
	var area := Vector2(maxf(size.x - margem, 1.0), maxf(size.y, 1.0))
	var fator := maxf(minf(area.x / REFERENCIA.x, area.y / REFERENCIA.y), 0.001)
	var zoom := float(_enquadramento["zoom"]) / 100.0
	var centro := REFERENCIA / 2.0
	var deslocamento := REFERENCIA * Vector2(_enquadramento["x"], _enquadramento["y"]) / 100.0
	if is_instance_valid(_ver_inteira) and _ver_inteira.button_pressed:
		var limites := _limites_composicao()
		centro = limites.get_center()
		zoom = minf(0.75, minf(maxf(area.x - 40, 1) / limites.size.x,
			maxf(area.y - 40, 1) / limites.size.y) / fator)
		deslocamento = Vector2.ZERO
	_composicao.scale = Vector2.ONE * fator * zoom
	_composicao.position = area / 2.0 - centro * fator * zoom + deslocamento * fator
	($Guia as Label).offset_left = margem + 18.0
	_atualizar_iluminacao()


func _limites_composicao() -> Rect2:
	var limites := Rect2(_mesa.position, Vector2.ONE)
	var dimensoes := _mesa.obter_dimensoes_tampo()
	for indice in range(128):
		var angulo := TAU * indice / 128.0
		var local := Vector2(cos(angulo), sin(angulo)) * dimensoes / 2.0
		if _mesa.formato == 0:
			local = Vector2(signf(local.x), signf(local.y)) * dimensoes / 2.0
		var ponto := _mesa.position + _mesa._projetar_ponto(_mesa.tamanho_plano / 2.0 + local)
		limites = limites.expand(ponto).expand(ponto + Vector2(0, _mesa.espessura))
	for indice in range(_maos_erguidas.size()):
		for carta in _maos_erguidas[indice].obter_cartas():
			limites = _expandir_limites_plano(limites, _plano_carta(carta, indice))
	for registro in _cartas_descarte.values():
		limites = _expandir_limites_plano(limites, _plano_carta(registro["carta"], -1, true))
	for indice in range(_planos_pilhas.size()):
		limites = _expandir_limites_plano(limites, _plano_pilha(0, indice))
	for registro in _transitos.values():
		limites = _expandir_limites_plano(limites, registro["atual"])
	return limites.grow(20)


func _expandir_limites_plano(limites: Rect2, plano: Dictionary) -> Rect2:
	var matriz := _matriz_apresentacao(plano)
	for uv in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		var q: Vector3 = matriz * Vector3(uv.x, uv.y, 1)
		if q.z > 0.00001:
			limites = limites.expand(Vector2(q.x, q.y) / q.z)
	return limites


func _montar_controles_sombra_inferior() -> void:
	var bloco := VBoxContainer.new()
	_controles_ui.add_child(bloco)
	var anterior := _controles_ui
	_controles_ui = bloco
	_texto("Sombra entre cartas da mão inferior", 16)
	_texto("Horizontal negativo leva a sombra para a esquerda; vertical positivo, para baixo. Salvar conjunto guarda estes ajustes.")
	var legendas := {"intensidade": "Intensidade", "x": "Deslocamento horizontal", "y": "Deslocamento vertical"}
	for chave in LIMITES_SOMBRA_INFERIOR:
		_texto(legendas[chave])
		var numero := SpinBox.new()
		numero.min_value = LIMITES_SOMBRA_INFERIOR[chave].x
		numero.max_value = LIMITES_SOMBRA_INFERIOR[chave].y
		numero.step = 1.0 if chave == "intensidade" else 0.5
		numero.suffix = "%" if chave == "intensidade" else ""
		_controles_ui.add_child(numero)
		var controle := HSlider.new()
		controle.min_value = numero.min_value
		controle.max_value = numero.max_value
		controle.step = numero.step
		controle.share(numero)
		_controles_ui.add_child(controle)
		_controles_sombra_inferior[chave] = controle
		controle.value_changed.connect(_alterar_sombra_inferior.bind(chave))
	_controles_ui = anterior
	_mostrar_sombra_inferior()


func _mostrar_sombra_inferior() -> void:
	var anterior := _atualizando_ui
	_atualizando_ui = true
	for chave in _controles_sombra_inferior:
		(_controles_sombra_inferior[chave] as HSlider).value = float(_sombra_inferior[chave])
	_atualizando_ui = anterior


func _alterar_sombra_inferior(valor: float, chave: String) -> void:
	if _atualizando_ui or not _transitos.is_empty():
		return
	_sombra_inferior[chave] = valor
	for carta in _maos_erguidas[0].obter_cartas():
		_configurar_sombra_inferior(carta)


func _montar_controles_pilhas() -> void:
	var bloco := VBoxContainer.new()
	_controles_ui.add_child(bloco)
	var anterior := _controles_ui
	_controles_ui = bloco
	_texto("Monte e descarte", 16)
	_seletor_pilha = OptionButton.new()
	_seletor_pilha.add_item("Ajustar monte de compra")
	_seletor_pilha.add_item("Ajustar descarte")
	_controles_ui.add_child(_seletor_pilha)
	_seletor_pilha.item_selected.connect(func(_indice: int): _mostrar_pilha())
	_texto("As duas pilhas usam a perspectiva da mesa e a fonte das sombras. Na compra, uma camada permite comparar com uma carta única.")
	var legendas := {"x": "Horizontal", "y": "Profundidade", "tamanho": "Tamanho",
		"giro": "Giro sobre a mesa", "espessura": "Altura da pilha", "camadas": "Camadas visíveis",
		"maximo_visiveis": "Máximo de cartas visíveis",
		"desalinhamento": "Desalinhamento", "intensidade_sombra": "Intensidade da sombra",
		"variacao_x": "Variação em X (±)", "variacao_y": "Variação em Y (±)", "variacao_rotacao": "Variação de rotação (±)",
		"suavidade_sombra": "Suavidade da sombra"}
	for chave in LIMITES_PILHAS:
		var campo := VBoxContainer.new()
		_controles_ui.add_child(campo)
		var legenda := Label.new()
		legenda.text = legendas[chave]
		campo.add_child(legenda)
		var numero := SpinBox.new()
		numero.min_value = LIMITES_PILHAS[chave].x
		numero.max_value = LIMITES_PILHAS[chave].y
		numero.step = 1.0 if chave in ["x", "y", "giro", "camadas", "maximo_visiveis"] else 0.05
		numero.suffix = "%" if chave in ["x", "y"] else ("°" if chave == "variacao_rotacao" else "")
		campo.add_child(numero)
		var controle := HSlider.new()
		controle.min_value = numero.min_value
		controle.max_value = numero.max_value
		controle.step = numero.step
		controle.share(numero)
		campo.add_child(controle)
		_controles_pilhas[chave] = controle
		controle.value_changed.connect(_alterar_pilha.bind(chave))
		if chave == "espessura":
			_legenda_espessura = legenda
		elif chave == "camadas":
			_bloco_camadas = campo
		elif chave == "maximo_visiveis":
			_bloco_maximo_visiveis = campo
		elif chave == "desalinhamento":
			_bloco_desalinhamento = campo
		elif chave in ["variacao_x", "variacao_y", "variacao_rotacao"]:
			_blocos_variacao.append(campo)
	_texto("No descarte, cada carta sorteia X, Y e rotação uma vez, dentro dos limites escolhidos. Zero alinha o eixo correspondente. Ao atingir o limite de cartas, cada chegada oculta a mais antiga e as restantes assentam.")
	_comparar_sombras_cartas = CheckBox.new()
	_comparar_sombras_cartas.text = "Sombras sobre as cartas das pilhas"
	_comparar_sombras_cartas.button_pressed = sombras_entre_cartas
	_comparar_sombras_cartas.toggled.connect(_alternar_sombras_cartas)
	_controles_ui.add_child(_comparar_sombras_cartas)
	_botao("Restaurar pilha selecionada", _restaurar_pilha)
	_controles_ui = anterior
	_mostrar_pilha()


func _alternar_sombras_cartas(ativo: bool) -> void:
	sombras_entre_cartas = ativo
	_atualizar_pilhas()


func _mostrar_pilha() -> void:
	if _seletor_pilha == null:
		return
	var anterior := _atualizando_ui
	_atualizando_ui = true
	var indice := _seletor_pilha.selected
	var espessura := _controles_pilhas["espessura"] as HSlider
	espessura.max_value = 40.0 if indice == 0 else 3.0
	_legenda_espessura.text = "Altura da pilha" if indice == 0 else "Espessura por carta"
	_bloco_camadas.visible = indice == 0
	_bloco_maximo_visiveis.visible = indice == 1
	_bloco_desalinhamento.visible = indice == 0
	for bloco in _blocos_variacao:
		bloco.visible = indice == 1
	for chave in LIMITES_PILHAS:
		(_controles_pilhas[chave] as HSlider).value = float(_perfis_pilhas[indice][chave])
	_atualizando_ui = anterior


func _alterar_pilha(valor: float, chave: String) -> void:
	if _atualizando_ui or not _transitos.is_empty():
		return
	_perfis_pilhas[_seletor_pilha.selected][chave] = valor
	_sincronizar_centros_pilhas()
	_aplicar_ajustes_pilhas()
	_atualizar_pilhas()


func _sincronizar_centros_pilhas() -> void:
	centro_compra = Vector2(_perfis_pilhas[0]["x"], _perfis_pilhas[0]["y"]) / 100.0
	centro_jogada = Vector2(_perfis_pilhas[1]["x"], _perfis_pilhas[1]["y"]) / 100.0


func _restaurar_pilha() -> void:
	var indice := _seletor_pilha.selected
	var ajustes := _padrao_pilha(indice)
	ajustes["x"] = 42.0 if indice == 0 else 58.0
	ajustes["y"] = 57.0
	_perfis_pilhas[indice] = ajustes
	_sincronizar_centros_pilhas()
	_aplicar_ajustes_pilhas()
	_mostrar_pilha()
	_atualizar_pilhas()


func _restaurar_todas() -> void:
	_restaurar_iluminacao()
	_ajustes_mesa = PADRAO_MESA.duplicate()
	_enquadramento = PADRAO_ENQUADRAMENTO.duplicate()
	_ver_inteira.set_pressed_no_signal(false)
	_aplicar_mesa()
	_mostrar_ajustes_ambiente()
	_sombra_inferior = PADRAO_SOMBRA_INFERIOR.duplicate()
	_mostrar_sombra_inferior()
	super._restaurar_todas()
	centro_compra = Vector2(0.42, 0.57)
	centro_jogada = Vector2(0.58, 0.57)
	_perfis_pilhas = [_padrao_pilha(0), _padrao_pilha(1)]
	sombras_entre_cartas = true
	_comparar_sombras_cartas.set_pressed_no_signal(true)
	_aplicar_ajustes_pilhas()
	_mostrar_pilha()
	_atualizar_pilhas()


func _ler_importacoes() -> void:
	if FileAccess.file_exists(ARQUIVO_TESTES):
		var arquivo := FileAccess.open(ARQUIVO_TESTES, FileAccess.READ)
		if arquivo != null:
			var dados: Variant = JSON.parse_string(arquivo.get_as_text())
			if dados is Dictionary:
				for nome in dados:
					var perfil: Variant = dados[nome]
					if perfil is Dictionary and perfil.get("maos") is Array and perfil["maos"].size() == 4:
						var valido := true
						for mao in perfil["maos"]:
							valido = valido and mao is Dictionary
						if valido:
							_importacoes[String(nome)] = perfil
	_lista_importacoes.clear()
	var nomes := _importacoes.keys()
	nomes.sort()
	for nome in nomes:
		_lista_importacoes.add_item(String(nome))
	if nomes.is_empty():
		_lista_importacoes.add_item("Nenhum conjunto visual salvo")
		_lista_importacoes.set_item_disabled(0, true)


func _importar_visual() -> void:
	if _importacoes.is_empty() or not _transitos.is_empty():
		return
	var nome := _lista_importacoes.get_item_text(_lista_importacoes.selected)
	_sair_da_mesa()
	_aplicar_teste(_importacoes[nome], nome)
	_mensagem.text = "Importado: " + nome + ". O arquivo visual original foi apenas lido."


func _montar_pilhas() -> void:
	_viewport_pilhas = SubViewport.new()
	_viewport_pilhas.disable_3d = true
	_viewport_pilhas.gui_disable_input = true
	_viewport_pilhas.transparent_bg = true
	_viewport_pilhas.size_2d_override = Vector2i(CAPTURA_PILHA * Vector2(2, 1))
	_viewport_pilhas.size = _viewport_pilhas.size_2d_override * 2
	_viewport_pilhas.size_2d_override_stretch = true
	_viewport_pilhas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_composicao.add_child(_viewport_pilhas)
	_compra = CENA_COMPRA.instantiate() as MonteVisual
	_compra.get_node("background").hide()
	_jogada = CENA_JOGADA.instantiate() as DescarteVisual
	_jogada.perspectiva_habilitada = true
	_jogada.duracao_animacao = duracao_trajeto
	for indice in range(2):
		var pilha: Control = _compra if indice == 0 else _jogada
		pilha.set_anchors_preset(Control.PRESET_TOP_LEFT)
		pilha.size = Vector2(110, 145) if indice == 0 else Vector2(152, 180)
		pilha.pivot_offset = Vector2.ZERO
		pilha.position = Vector2(indice * CAPTURA_PILHA.x, 0) + (CAPTURA_PILHA - pilha.size) / 2.0
		pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_viewport_pilhas.add_child(pilha)
	var verso := _compra.criar_carta()
	verso.animacao_2_5d_habilitada = true
	verso.aplicar_estado_visual(_estado_compra(), false)
	verso.definir_sombra_visivel(false)
	verso.definir_hover_habilitado(false)
	_aplicar_ajustes_pilhas()
	for _indice in range(3):
		var carta := _compra.criar_carta()
		var dados := _baralho_visual.comprar_carta().para_dados()
		_dados_por_instancia[carta.get_instance_id()] = dados
		carta.setup_dados(dados)
		_jogada.receber_carta(carta)
		carta.aplicar_estado_visual(_estado_descarte(carta), false)
		carta.definir_sombra_visivel(false)
		carta.definir_hover_habilitado(false)
		var visual := PLANO_CARTA.new()
		_composicao.add_child(visual)
		visual.capturar_carta(carta)
		_manter_visual_descarte(carta, visual)
	_jogada.cartas_visiveis_alteradas.connect(_acomodar_descarte)
	RenderingServer.frame_post_draw.connect(_ao_desenhar_pilhas, CONNECT_ONE_SHOT)


func _ao_desenhar_pilhas() -> void:
	_pilhas_prontas = true
	_viewport_pilhas.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_atualizar_pilhas()


func _aplicar_ajustes_pilhas() -> void:
	if not is_instance_valid(_jogada):
		return
	_jogada.variacao_x = float(_perfis_pilhas[1]["variacao_x"])
	_jogada.variacao_y = float(_perfis_pilhas[1]["variacao_y"])
	_jogada.variacao_rotacao = float(_perfis_pilhas[1]["variacao_rotacao"])
	_jogada.maximo_cartas_visiveis = roundi(float(_perfis_pilhas[1]["maximo_visiveis"]))
	for carta in _jogada.get_children():
		if not _transitos.has(carta.get_instance_id()):
			var id := carta.get_instance_id()
			if _cartas_descarte.has(id):
				_cartas_descarte[id]["acomodando"] = false
			carta.aplicar_estado_visual(_estado_descarte(carta), false)
	_acomodar_descarte(false)
	var quantidade := roundi(float(_perfis_pilhas[0]["camadas"]))
	while _planos_pilhas.size() > quantidade:
		var visual: Node2D = _planos_pilhas.pop_back()
		visual.hide()
		visual.queue_free()
	while _planos_pilhas.size() < quantidade:
		var visual := PLANO_CARTA.new()
		_composicao.add_child(visual)
		visual.face.z_index = 3
		visual.usar_textura(_viewport_pilhas.get_texture(), CAPTURA_PILHA, Vector4(0, 0, 0.5, 1))
		_planos_pilhas.append(visual)
	for indice in range(_planos_pilhas.size()):
		var material := _planos_pilhas[indice].face.material as ShaderMaterial
		var tom := 0.72 if indice % 2 == 0 else 0.87
		material.set_shader_parameter("cor_camada", Color(tom, tom * 0.98, tom * 0.92, 1.0)
			if indice < quantidade - 1 else Color.TRANSPARENT)


func _estado_compra() -> Dictionary:
	return {"posicao": (_compra.size - Carta.SIZE) / 2.0, "rotacao": 0.0,
		"escala": Vector2(1.5, 1.5), "inclinacao": Vector2.ZERO, "deformacao": 0.0}


func _plano_pilha(indice: int, camada: int = -1) -> Dictionary:
	var centro := (centro_compra if indice == 0 else centro_jogada) * Vector2(_mesa.tamanho_plano)
	var perfil := _perfis_pilhas[indice]
	var altura := 0.5
	if indice == 0:
		var quantidade := roundi(float(perfil["camadas"]))
		if camada < 0:
			camada = quantidade - 1
		if quantidade > 1:
			altura += float(perfil["espessura"]) * camada / float(quantidade - 1)
		centro += DESLOCAMENTOS_COMPRA[camada % DESLOCAMENTOS_COMPRA.size()] * float(perfil["desalinhamento"])
	else:
		altura = _altura_descarte(camada)
	var giro := deg_to_rad(float(perfil["giro"]))
	var u := Vector2(CAPTURA_PILHA.x, 0).rotated(giro) * float(perfil["tamanho"])
	var v := Vector2(0, CAPTURA_PILHA.y).rotated(giro) * float(perfil["tamanho"])
	var inicio := centro - (u + v) / 2.0
	return {"ponto": Vector3(inicio.x, inicio.y, altura),
		"u": Vector3(u.x, u.y, 0), "v": Vector3(v.x, v.y, 0), "frontal": 0.0}


func _atualizar_pilhas() -> void:
	for indice in range(_planos_pilhas.size()):
		var plano := _plano_pilha(0, indice)
		var visual: Node2D = _planos_pilhas[indice]
		_configurar_material_iluminacao(visual.face.material as ShaderMaterial, true)
		visual.apresentar(_matriz_da_mesa(plano["ponto"], plano["u"], plano["v"]))
		visual.face.visible = visual.face.visible and _pilhas_prontas
		_sombra_pilha(visual, plano, 0, 1.0 if indice == _planos_pilhas.size() - 1 and _pilhas_prontas else 0.0)
	var topo := -1
	for id in _cartas_descarte:
		var carta: Carta = _cartas_descarte[id]["carta"]
		topo = maxi(topo, carta.get_index())
	var descarte := _cartas_descarte.values()
	descarte.sort_custom(func(a: Dictionary, b: Dictionary): return a["carta"].get_index() < b["carta"].get_index())
	for indice in range(descarte.size()):
		var registro: Dictionary = descarte[indice]
		var carta: Carta = registro["carta"]
		var visual: Node2D = registro["visual"]
		_configurar_material_iluminacao(visual.face.material as ShaderMaterial, true)
		# Cada face e sua sombra recebida têm ordens distintas, também após pousar.
		visual.face.z_index = ORDEM_DESCARTE + indice * 2
		var plano := _plano_carta(carta, -1, true)
		registro["plano_atual"] = plano
		visual.sincronizar_carta()
		visual.apresentar(_matriz_apresentacao(plano))
		# Uma sombra do topo evita escurecer o feltro a cada carta acumulada.
		_sombra_pilha(visual, plano, 1, 1.0 if carta.get_index() == topo else 0.0)
	_atualizar_sombras_entre_cartas()


func _atualizar_sombras_entre_cartas() -> void:
	var descarte := _cartas_descarte.values()
	descarte.sort_custom(func(a: Dictionary, b: Dictionary): return a["carta"].get_index() < b["carta"].get_index())
	var receptores: Array[Dictionary] = []
	for registro in descarte:
		var visual: Node2D = registro["visual"]
		visual.iniciar_sombras_recebidas()
		receptores.append({"visual": visual, "plano": registro["plano_atual"]})
	for visual in _planos_pilhas:
		visual.iniciar_sombras_recebidas()
	if _pilhas_prontas and not _planos_pilhas.is_empty():
		var visual: Node2D = _planos_pilhas.back()
		receptores.append({"visual": visual, "plano": _plano_pilha(0)})
	if sombras_entre_cartas:
		var ajustes := _sombra_do_destino(1)
		# Pousar conserva os mesmos receptores do trajeto, incluindo cartas não adjacentes.
		for registro in descarte:
			_projetar_sombra_nas_pilhas(registro["visual"], registro["plano_atual"], ajustes, 1.0, receptores)
		for trajeto in _transitos.values():
			var plano: Dictionary = trajeto["atual"]
			var opacidade := 1.0 - float(plano["frontal"])
			var sombra: Dictionary = trajeto["sombra_atual"]
			_projetar_sombra_nas_pilhas(trajeto["visual"], plano, sombra, opacidade, receptores)
	for registro in descarte:
		registro["visual"].concluir_sombras_recebidas()
	for visual in _planos_pilhas:
		visual.concluir_sombras_recebidas()


func _projetar_sombra_nas_pilhas(visual: Node2D, plano: Dictionary, ajustes: Dictionary,
		opacidade: float, receptores: Array[Dictionary]) -> void:
	for receptor in receptores:
		receptor["visual"].receber_sombra(self, receptor["plano"], visual, plano,
			opacidade, float(ajustes["intensidade"]), float(ajustes["suavidade"]))


func _sombra_pilha(visual: Node2D, plano: Dictionary, indice: int, opacidade: float) -> void:
	var perfil := _perfis_pilhas[indice]
	visual.projetar_sombra(self, plano, opacidade, float(perfil["intensidade_sombra"]), float(perfil["suavidade_sombra"]))


func _manter_visual_descarte(carta: Carta, visual: Node2D, altura: float = -1.0) -> void:
	carta.definir_apresentacao_externa(true)
	visual.face.z_index = ORDEM_DESCARTE
	if altura < 0.0:
		altura = _altura_descarte(_camada_descarte(carta))
	_cartas_descarte[carta.get_instance_id()] = {"carta": carta, "visual": visual,
		"altura_atual": altura, "acomodando": false}
	carta.reorganizacao_atualizada.connect(_ao_atualizar_acomodacao.bind(carta))
	carta.reorganizacao_concluida.connect(_ao_concluir_acomodacao.bind(carta))
	# A ordem é a de entrada no descarte, mesmo se os trajetos terminarem fora de ordem.
	for existente in _jogada.get_children():
		var id := existente.get_instance_id()
		if _cartas_descarte.has(id):
			_composicao.move_child(_cartas_descarte[id]["visual"], _composicao.get_child_count() - 1)
	_atualizar_pilhas()


func _altura_descarte(camada: int) -> float:
	var espessura := float(_perfis_pilhas[1]["espessura"])
	# Distribuir o limite de altura entre as camadas, sem achatar as do topo.
	var passo := minf(espessura, ALTURA_MAXIMA_DESCARTE / float(_jogada.maximo_cartas_visiveis - 1))
	return 0.5 + maxi(camada, 0) * passo


func _camada_descarte(carta: Carta) -> int:
	var visiveis := _jogada.obter_cartas_visiveis()
	var camada := 0
	for anterior in _jogada.get_children():
		if anterior == carta:
			break
		if visiveis.has(anterior) or _transitos.has(anterior.get_instance_id()):
			camada += 1
	return camada


func _acomodar_descarte(animar: bool = true) -> void:
	if not is_instance_valid(_jogada):
		return
	var visiveis := _jogada.obter_cartas_visiveis()
	for id in _cartas_descarte.keys():
		var registro: Dictionary = _cartas_descarte[id]
		if not visiveis.has(registro["carta"]):
			_liberar_visual_descarte(registro)
			_cartas_descarte.erase(id)
	for indice in range(visiveis.size()):
		var carta := visiveis[indice]
		var id := carta.get_instance_id()
		var altura := _altura_descarte(indice)
		if not _cartas_descarte.has(id):
			var visual := PLANO_CARTA.new()
			_composicao.add_child(visual)
			visual.capturar_carta(carta)
			_manter_visual_descarte(carta, visual, altura)
		var registro: Dictionary = _cartas_descarte[id]
		if not animar:
			registro["acomodando"] = false
			registro["altura_atual"] = altura
		elif not is_equal_approx(float(registro["altura_atual"]), altura):
			registro["altura_inicio"] = registro["altura_atual"]
			registro["altura_destino"] = altura
			registro["acomodando"] = true
			# A carta conduz também o assentamento; não há outro relógio no laboratório.
			carta.aplicar_estado_visual(_estado_descarte(carta), true, _jogada.duracao_acomodacao)
	_atualizar_pilhas()


func _ao_atualizar_acomodacao(progresso: float, carta: Carta) -> void:
	var id := carta.get_instance_id()
	if not _cartas_descarte.has(id):
		return
	var registro: Dictionary = _cartas_descarte[id]
	if registro["acomodando"]:
		registro["altura_atual"] = lerpf(float(registro["altura_inicio"]), float(registro["altura_destino"]), progresso)


func _ao_concluir_acomodacao(carta: Carta) -> void:
	var id := carta.get_instance_id()
	if _cartas_descarte.has(id):
		_cartas_descarte[id]["acomodando"] = false


func _liberar_visual_descarte(registro: Dictionary) -> void:
	var carta: Carta = registro["carta"]
	carta.reorganizacao_atualizada.disconnect(_ao_atualizar_acomodacao.bind(carta))
	carta.reorganizacao_concluida.disconnect(_ao_concluir_acomodacao.bind(carta))
	if registro["acomodando"]:
		carta.aplicar_estado_visual(_estado_descarte(carta), false)
	registro["visual"].hide()
	registro["visual"].queue_free()


func _projetar_maos() -> void:
	super._projetar_maos()
	_atualizar_pilhas()
	if is_instance_valid(_ver_inteira) and _ver_inteira.button_pressed:
		_ajustar_enquadramento()


func _estado_descarte(carta: Carta) -> Dictionary:
	return _jogada.estado_destino_carta(carta)


func _transformacao_destino(carta: Carta, mao: int) -> Transform2D:
	if mao >= 0:
		return _maos_erguidas[mao].transformacao_destino_carta(_maos_erguidas[mao].obter_cartas().find(carta))
	var estado := _estado_descarte(carta)
	var t := Transform2D(deg_to_rad(float(estado["rotacao"])), estado["escala"], 0.0, Vector2.ZERO)
	t.origin = estado["posicao"] + carta.pivot_offset - t.basis_xform(carta.pivot_offset)
	return _jogada.get_global_transform() * t


func _plano_carta(carta: Carta, mao: int, destino: bool = false, pilha: int = 1) -> Dictionary:
	var t := _transformacao_destino(carta, mao) if destino else carta.transformacao_da_aparencia()
	var captura: Vector2 = PLANO_CARTA.CAPTURA
	var q := t * ((Carta.SIZE - captura) / 2.0)
	var u := t.basis_xform(Vector2(captura.x, 0))
	var v := t.basis_xform(Vector2(0, captura.y))
	if mao < 0:
		var pousada := pilha == 1 and _cartas_descarte.has(carta.get_instance_id())
		var base := _plano_pilha(pilha, _camada_descarte(carta) if pilha == 1 and not pousada else -1)
		if pousada:
			base["ponto"].z = float(_cartas_descarte[carta.get_instance_id()]["altura_atual"])
		q -= Vector2(pilha * CAPTURA_PILHA.x, 0)
		var p: Vector3 = base["ponto"]
		var eixo_u: Vector3 = base["u"] / CAPTURA_PILHA.x
		var eixo_v: Vector3 = base["v"] / CAPTURA_PILHA.y
		return {"ponto": p + eixo_u * q.x + eixo_v * q.y, "u": eixo_u * u.x + eixo_v * u.y,
			"v": eixo_u * v.x + eixo_v * v.y, "frontal": 0.0}
	q -= _origens_atlas[mao] + _tamanho_captura / 2.0
	var perfil := _perfis[mao]
	if mao == 0 and _primeiro_plano.button_pressed:
		var local := Basis(Vector3(u.x / _tamanho_captura.x, u.y / _tamanho_captura.y, 0),
			Vector3(v.x / _tamanho_captura.x, v.y / _tamanho_captura.y, 0),
			Vector3(q.x / _tamanho_captura.x + 0.5, q.y / _tamanho_captura.y + 0.5, 1))
		var tela := _matriz_primeiro_plano(perfil["primeiro_plano"]) * local
		return _plano_frontal_virtual(tela)
	var p := _ponto_no_mundo(q, perfil)
	return {"ponto": p, "u": _ponto_no_mundo(q + u, perfil) - p,
		"v": _ponto_no_mundo(q + v, perfil) - p, "frontal": 0.0}


func _plano_frontal_virtual(tela: Basis) -> Dictionary:
	# A mão frontal não tem uma posição física única na câmera da mesa.
	# Usar um plano virtual alto só no trajeto; sua sombra desaparece ao segurá-la.
	var altura := 180.0
	var inversa := _matriz_da_mesa(Vector3(0, 0, altura), Vector3.RIGHT, Vector3.UP).inverse()
	var mundo := inversa * tela
	var pontos: Array[Vector3] = []
	for uv in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN]:
		var q: Vector3 = mundo * Vector3(uv.x, uv.y, 1)
		pontos.append(Vector3(q.x / q.z, q.y / q.z, altura))
	return {"ponto": pontos[0], "u": pontos[1] - pontos[0], "v": pontos[2] - pontos[0],
		"frontal": 1.0, "tela_frontal": tela}


func _comprar() -> void:
	if not is_instance_valid(_compra) or _virando_maos[_selecionada]:
		return
	_sair_da_mesa()
	var carta := _compra.criar_carta()
	var dados := _baralho_visual.comprar_carta().para_dados()
	_dados_por_instancia[carta.get_instance_id()] = dados
	carta.setup_dados(dados)
	carta.animacao_2_5d_habilitada = true
	carta.aplicar_estado_visual(_estado_compra(), false)
	carta.definir_sombra_visivel(false)
	var inicio := _plano_carta(carta, -1, false, 0)
	_preparar_visual(carta, inicio, _selecionada)
	var mao := _maos_erguidas[_selecionada]
	mao.duracao_reorganizacao = duracao_trajeto
	mao.receber_carta_do_monte(carta)
	# Respeitar frente/verso escolhidos no perfil atual, mantendo os dados externos.
	if bool(_perfis[_selecionada]["avancados"]["frentes"]):
		carta.setup_dados(dados)
	carta.definir_hover_habilitado(false)
	_atualizar_captura()
	_projetar_maos()
	_atualizar_estado_trajeto()


func _jogar_carta() -> void:
	if not is_instance_valid(_jogada) or _virando_maos[_selecionada]:
		return
	var cartas := _maos_erguidas[_selecionada].obter_cartas()
	if cartas.is_empty():
		return
	_sair_da_mesa()
	var indice := 0
	if _escolha_jogada.selected == 1:
		indice = floori(cartas.size() / 2.0)
	elif _escolha_jogada.selected == 2:
		indice = cartas.size() - 1
	var carta := cartas[indice]
	var id := carta.get_instance_id()
	var inicio: Dictionary = _transitos[id]["atual"] if _transitos.has(id) else _plano_carta(carta, _selecionada)
	_preparar_visual(carta, inicio, -1)
	carta.setup_dados(_dados_por_instancia[id])
	_jogada.duracao_animacao = duracao_trajeto
	_jogada.receber_carta(carta)
	carta.definir_sombra_visivel(false)
	_atualizar_captura()
	_projetar_maos()
	_atualizar_estado_trajeto()


func _preparar_visual(carta: Carta, inicio: Dictionary, destino: int) -> void:
	var id := carta.get_instance_id()
	var visual: Node2D
	var sombra_atual := _sombra_do_destino(-1)
	var contato_atual := 0.0
	if _transitos.has(id):
		visual = _transitos[id]["visual"]
		sombra_atual = _transitos[id]["sombra_atual"]
		contato_atual = float(_transitos[id]["contato_atual"])
	else:
		if _maos_erguidas[0].obter_cartas().has(carta) and _maos_erguidas[0].sombras_visiveis:
			contato_atual = 1.0
		if carta.get_parent() == _compra:
			sombra_atual = _sombra_do_destino(0)
		visual = PLANO_CARTA.new()
		_composicao.add_child(visual)
		visual.face.z_index = ORDEM_TRANSITO
		visual.capturar_carta(carta)
		carta.reorganizacao_iniciada.connect(_ao_iniciar_reorganizacao.bind(carta))
		carta.reorganizacao_atualizada.connect(_ao_atualizar_reorganizacao.bind(carta))
		carta.reorganizacao_concluida.connect(_ao_concluir_reorganizacao.bind(carta))
	if destino == 0:
		_configurar_sombra_inferior(carta)
	# A carta muda de pai agora. Só a apresentação atravessa os dois canvases.
	carta.definir_apresentacao_externa(true)
	_transitos[id] = {"carta": carta, "visual": visual, "inicio": inicio, "atual": inicio,
		"destino": destino, "novo_trajeto": true, "altura_arco": altura_trajeto,
		"sombra_atual": sombra_atual, "contato_atual": contato_atual, "pousada": false}
	_apresentar_trajeto(_transitos[id], inicio)
	_travar_edicao(true)


func _ao_iniciar_reorganizacao(_estado: Dictionary, carta: Carta) -> void:
	var id := carta.get_instance_id()
	if not _transitos.has(id):
		return
	var registro: Dictionary = _transitos[id]
	registro["pousada"] = false
	# A mão reiniciou o tween da carta: preservar também sua aparência projetada.
	registro["inicio"] = registro["atual"]
	registro["sombra_inicio"] = registro["sombra_atual"].duplicate()
	registro["sombra_fim"] = _sombra_do_destino(1 if int(registro["destino"]) < 0 else -1)
	registro["contato_inicio"] = registro["contato_atual"]
	registro["contato_fim"] = 1.0 if int(registro["destino"]) == 0 and _maos_erguidas[0].sombras_visiveis else 0.0
	registro["fim"] = _plano_carta(carta, int(registro["destino"]), true)
	registro["altura_arco"] = altura_trajeto if registro["novo_trajeto"] else 0.0
	registro["novo_trajeto"] = false


func _ao_atualizar_reorganizacao(progresso: float, carta: Carta) -> void:
	var id := carta.get_instance_id()
	if not _transitos.has(id):
		return
	var registro: Dictionary = _transitos[id]
	if not registro.has("fim"):
		return
	var atual := _interpolar_planos(registro["inicio"], registro["fim"], progresso,
		float(registro["altura_arco"]))
	registro["atual"] = atual
	for chave in ["intensidade", "suavidade"]:
		registro["sombra_atual"][chave] = lerpf(float(registro["sombra_inicio"][chave]), float(registro["sombra_fim"][chave]), progresso)
	var chegada := float(registro["contato_fim"]) > 0.0
	var contato := smoothstep(0.55, 1.0, progresso) if chegada else smoothstep(0.0, 0.45, progresso)
	registro["contato_atual"] = lerpf(float(registro["contato_inicio"]), float(registro["contato_fim"]), contato)
	_apresentar_trajeto(registro, atual)


func _ao_concluir_reorganizacao(carta: Carta) -> void:
	var id := carta.get_instance_id()
	if not _transitos.has(id):
		return
	var destino := int(_transitos[id]["destino"])
	var visual: Node2D = _transitos[id]["visual"]
	var plano_atual: Dictionary = _transitos[id]["atual"]
	if destino == 0:
		# As compras sobrepostas permanecem intercaladas no mesmo canvas até pousar.
		_transitos[id]["pousada"] = true
		_transitos[id]["contato_atual"] = 1.0 if _maos_erguidas[0].sombras_visiveis else 0.0
		_apresentar_trajeto(_transitos[id], plano_atual)
		_devolver_apresentacao_inferior.call_deferred()
		return
	carta.definir_apresentacao_externa(destino < 0)
	carta.definir_hover_habilitado(false)
	_desconectar_apresentacao(carta)
	_transitos.erase(id)
	if destino < 0:
		visual.sombra_contato.hide()
		_manter_visual_descarte(carta, visual, float(plano_atual["ponto"].z))
	else:
		carta.definir_sombra_visivel(_maos_erguidas[destino].sombras_visiveis)
		visual.hide()
		visual.queue_free()
	_devolver_apresentacao_inferior.call_deferred()


func _devolver_apresentacao_inferior() -> void:
	for registro in _transitos.values():
		if int(registro["destino"]) == 0 and not bool(registro["pousada"]):
			return
	# Trocar o grupo no mesmo quadro evita colocar uma face entre duas camadas.
	for id in _transitos.keys():
		var registro: Dictionary = _transitos[id]
		if int(registro["destino"]) != 0:
			continue
		var carta: Carta = registro["carta"]
		_configurar_sombra_inferior(carta)
		carta.definir_sombra_visivel(_maos_erguidas[0].sombras_visiveis)
		carta.definir_apresentacao_externa(false)
		carta.definir_hover_habilitado(not _maos_erguidas[0].mao_adversaria)
		_desconectar_apresentacao(carta)
		registro["visual"].hide()
		registro["visual"].queue_free()
		_transitos.erase(id)


func _ordem_apresentacao_trajeto(registro: Dictionary) -> int:
	if int(registro["destino"]) == 0:
		var indice := _maos_erguidas[0].obter_cartas().find(registro["carta"])
		return ORDEM_TRANSITO + maxi(indice, 0) * 2
	return ORDEM_TRANSITO + _maos_erguidas[0].quantidade_cartas() * 2 + 2


func _desconectar_apresentacao(carta: Carta) -> void:
	carta.reorganizacao_iniciada.disconnect(_ao_iniciar_reorganizacao.bind(carta))
	carta.reorganizacao_atualizada.disconnect(_ao_atualizar_reorganizacao.bind(carta))
	carta.reorganizacao_concluida.disconnect(_ao_concluir_reorganizacao.bind(carta))


func _decompor(plano: Dictionary) -> Dictionary:
	var u: Vector3 = plano["u"]
	var v: Vector3 = plano["v"]
	var x := u.normalized()
	var z := u.cross(v).normalized()
	var y := z.cross(x).normalized()
	return {"centro": plano["ponto"] + (u + v) / 2.0,
		"rotacao": Basis(x, y, z).get_rotation_quaternion(),
		"largura": u.length(), "altura": v.dot(y), "cisalhamento": v.dot(x)}


func _interpolar_planos(inicio: Dictionary, fim: Dictionary, progresso: float, altura_arco: float = -1.0) -> Dictionary:
	var a := _decompor(inicio)
	var b := _decompor(fim)
	var qa: Quaternion = a["rotacao"]
	var qb: Quaternion = b["rotacao"]
	var orientacao := Basis(qa.slerp(qb, progresso))
	var u := orientacao.x * lerpf(float(a["largura"]), float(b["largura"]), progresso)
	var v := orientacao.y * lerpf(float(a["altura"]), float(b["altura"]), progresso)
	v += orientacao.x * lerpf(float(a["cisalhamento"]), float(b["cisalhamento"]), progresso)
	var centro_a: Vector3 = a["centro"]
	var centro_b: Vector3 = b["centro"]
	var centro := centro_a.lerp(centro_b, progresso)
	centro.z += sin(progresso * PI) * (altura_trajeto if altura_arco < 0.0 else altura_arco)
	var atual := {"ponto": centro - (u + v) / 2.0, "u": u, "v": v,
		"frontal": lerpf(float(inicio["frontal"]), float(fim["frontal"]), progresso)}
	if inicio.has("tela_frontal") or fim.has("tela_frontal"):
		var frontal_a: Basis = inicio.get("tela_frontal", fim.get("tela_frontal"))
		var frontal_b: Basis = fim.get("tela_frontal", frontal_a)
		atual["tela_frontal"] = Basis(frontal_a.x.lerp(frontal_b.x, progresso),
			frontal_a.y.lerp(frontal_b.y, progresso), frontal_a.z.lerp(frontal_b.z, progresso))
	return atual


func _normalizar_matriz(matriz: Basis) -> Basis:
	var centro: Vector3 = matriz * Vector3(0.5, 0.5, 1)
	return Basis(matriz.x / centro.z, matriz.y / centro.z, matriz.z / centro.z)


func _matriz_apresentacao(plano: Dictionary) -> Basis:
	var matriz := _normalizar_matriz(_matriz_da_mesa(plano["ponto"], plano["u"], plano["v"]))
	var peso := float(plano["frontal"])
	if peso > 0.0:
		var frontal := _normalizar_matriz(plano["tela_frontal"])
		matriz = Basis(matriz.x.lerp(frontal.x, peso), matriz.y.lerp(frontal.y, peso), matriz.z.lerp(frontal.z, peso))
	return matriz


func _apresentar_trajeto(registro: Dictionary, plano: Dictionary) -> void:
	var visual: Node2D = registro["visual"]
	visual.face.z_index = _ordem_apresentacao_trajeto(registro)
	_configurar_material_iluminacao(visual.face.material as ShaderMaterial, true)
	visual.sincronizar_carta()
	var matriz := _matriz_apresentacao(plano)
	visual.apresentar(matriz)
	visual.apresentar_sombra_contato(matriz, float(registro["contato_atual"]))
	var ajustes: Dictionary = registro["sombra_atual"]
	visual.projetar_sombra(self, plano, 1.0 - float(plano["frontal"]), float(ajustes["intensidade"]), float(ajustes["suavidade"]))


func _sombra_do_destino(pilha: int) -> Dictionary:
	if pilha < 0:
		return {"intensidade": intensidade_sombra, "suavidade": suavidade_sombra}
	return {"intensidade": _perfis_pilhas[pilha]["intensidade_sombra"],
		"suavidade": _perfis_pilhas[pilha]["suavidade_sombra"]}


func _process(delta: float) -> void:
	_atualizar_iluminacao()
	for id in _transitos.keys():
		var registro: Dictionary = _transitos[id]
		var carta: Carta = registro["carta"]
		if not is_instance_valid(carta):
			registro["visual"].queue_free()
			_transitos.erase(id)
			continue
		# Só sincroniza virada/captura e luz; o tween da Carta avança o trajeto.
		_apresentar_trajeto(registro, registro["atual"])
	_devolver_apresentacao_inferior()
	if _transitos.is_empty():
		_travar_edicao(false)
	_atualizar_pilhas()
	super._process(delta)
	_atualizar_estado_trajeto()


func _travar_edicao(ativo: bool) -> void:
	if _edicao_bloqueada == ativo:
		return
	_edicao_bloqueada = ativo
	if ativo:
		var foco := get_viewport().gui_get_focus_owner()
		if foco != null:
			foco.release_focus()
		for controle in _controles_ui.find_children("*", "Control", true, false):
			if controle.has_meta("secao") or _secoes["Enquadramento"].is_ancestor_of(controle) or _secoes["Iluminação"].is_ancestor_of(controle) or _comandos_trajeto.is_ancestor_of(controle) or _campos_fonte.is_ancestor_of(controle) or controle == _fonte_localizada or controle == _seletor:
				continue
			var propriedade := "disabled" if controle is BaseButton else "editable"
			if controle is BaseButton or controle is Slider or controle is SpinBox:
				_controles_bloqueados.append({"controle": controle, "propriedade": propriedade, "valor": controle.get(propriedade)})
				controle.set(propriedade, controle is BaseButton)
	else:
		for registro in _controles_bloqueados:
			registro["controle"].set(registro["propriedade"], registro["valor"])
		_controles_bloqueados.clear()
		_atualizar_indicadores()


func _atualizar_estado_trajeto() -> void:
	if _estado_trajeto == null:
		return
	var quantidades := PackedStringArray()
	for mao in _maos_erguidas:
		quantidades.append(str(mao.quantidade_cartas()))
	_estado_trajeto.text = "Mãos: %s · descarte: %d\nEm trânsito: %d. %s" % [" / ".join(quantidades),
		_jogada.get_child_count() if is_instance_valid(_jogada) else 0, _transitos.size(),
		"Comprar/jogar continuam disponíveis." if not _transitos.is_empty() else "Hover e ajustes disponíveis."]


func _esvaziar() -> void:
	_sair_da_mesa()
	for registro in _transitos.values():
		if is_instance_valid(registro["carta"]):
			_desconectar_apresentacao(registro["carta"])
		registro["visual"].hide()
		registro["visual"].queue_free()
	_transitos.clear()
	for registro in _cartas_descarte.values():
		_liberar_visual_descarte(registro)
	_cartas_descarte.clear()
	for indice in range(_maos_erguidas.size()):
		_maos_erguidas[indice].limpar()
		_versoes_virada[indice] += 1
		_virando_maos[indice] = false
	if is_instance_valid(_jogada):
		_jogada.limpar()
	_dados_por_instancia.clear()
	_baralho_visual.criar_baralho()
	_travar_edicao(false)
	_atualizar_estado_trajeto()


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		var foco := get_viewport().gui_get_focus_owner()
		if not (foco is LineEdit or foco is TextEdit or foco is SpinBox):
			match evento.physical_keycode:
				KEY_D: _comprar()
				KEY_J: _jogar_carta()
				KEY_R: _esvaziar()
			if evento.physical_keycode in [KEY_D, KEY_J, KEY_R]:
				get_viewport().set_input_as_handled()
				return
	super._input(evento)
