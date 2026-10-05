extends Control

const ESTANTE = preload("res://scenes/desenvolvimento/laboratorios/estante_laboratorio.tscn")
const PROJECAO = preload("res://scripts/desenvolvimento/laboratorios/interno/projecao_laboratorio.gd")
const PRESETS = preload("res://scripts/desenvolvimento/laboratorios/interno/presets_moveis.gd")
const REFERENCIA_INICIAL := "res://scripts/desenvolvimento/laboratorios/presets/teste_ambiente_2_moveis.json"
const TEMA = preload("res://scenes/desenvolvimento/laboratorios/painel_laboratorio.tres")
const REFERENCIA := Vector2(1280, 720)
const PADRAO_MESA := {"formato": 1.0, "largura": 2150.0, "profundidade": 950.0,
	"moldura": 35.0, "espessura": 100.0, "perspectiva": 50.0, "profundidade_camera": 335.0, "x": 50.0, "y": 58.0}
const LIMITES_MESA := {"largura": Vector2(400, 2400), "profundidade": Vector2(300, 1050),
	"moldura": Vector2(0, 120), "espessura": Vector2(0, 100), "perspectiva": Vector2(35, 100),
	"profundidade_camera": Vector2(60, 650), "x": Vector2(-25, 125), "y": Vector2(-25, 125)}
const PADRAO_VISAO := {"zoom": 75.0, "x": 0.0, "y": 0.0}
const LIMITES_VISAO := {"zoom": Vector2(25, 180), "x": Vector2(-150, 150), "y": Vector2(-150, 150)}
const PADRAO_LUZ := {"ativa": true, "ambiente": 100.0, "x": -1500.0,
	"distancia": 450.0, "altura": 700.0, "intensidade": 130.0, "alcance": 1100.0, "cor": "ffc16b"}
const LIMITES_LUZ := {"ambiente": Vector2(0, 150), "x": Vector2(-3000, 3000),
	"distancia": Vector2(-1200, 2400), "altura": Vector2(-800, 1600),
	"intensidade": Vector2(0, 300), "alcance": Vector2(100, 2400)}
const PADRAO_VISTA := {"mesa": true, "outra": false, "focar": false, "ver_luz": true}

@onready var _composicao: Node2D = $Composicao
@onready var _mesa: MesaVisual = $Composicao/Mesa

var _estantes: Array[Node2D] = []
var _perfis: Array[Dictionary] = []
var _mesa_ajustes := PADRAO_MESA.duplicate()
var _camera_moveis := PRESETS.PADRAO_CAMERA.duplicate()
var _visao := PADRAO_VISAO.duplicate()
var _luz := PADRAO_LUZ.duplicate()
var _vista := PADRAO_VISTA.duplicate()
var _selecionada := 0
var _area_ui: Control
var _painel: PanelContainer
var _rolagem: ScrollContainer
var _categorias: Dictionary = {}
var _botoes: Dictionary = {}
var _campos: Dictionary = {}
var _projecao: OptionButton
var _seletor: OptionButton
var _marcador: Polygon2D
var _nome_movel: LineEdit
var _nome_composicao: LineEdit
var _lista_moveis: OptionButton
var _lista_composicoes: OptionButton
var _mensagem: Label
var _atualizando_ui := false


func _ready() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCIA_INICIAL))
	_mesa_ajustes = _validar(base.get("mesa"), PADRAO_MESA, LIMITES_MESA)
	_camera_moveis = PRESETS.validar_camera(base.get("camera_moveis"))
	_visao = _validar(base.get("enquadramento"), PADRAO_VISAO, LIMITES_VISAO)
	for indice in range(2):
		_perfis.append(PRESETS.validar(base["estantes"][indice], indice))
		var estante: Node2D = ESTANTE.instantiate()
		_composicao.add_child(estante)
		_estantes.append(estante)
	_marcador = Polygon2D.new()
	_marcador.z_index = 20
	var circulo := PackedVector2Array()
	for indice in range(20):
		circulo.append(Vector2(cos(TAU * indice / 20.0), sin(TAU * indice / 20.0)) * 7)
	_marcador.polygon = circulo
	_composicao.add_child(_marcador)
	_montar_painel()
	resized.connect(_ajustar_enquadramento)
	_atualizar_cena()
	_mostrar_ajustes()


func _montar_painel() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 1
	add_child(camada)
	_area_ui = Control.new()
	_area_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area_ui.size = size
	camada.add_child(_area_ui)
	_painel = PanelContainer.new()
	_painel.theme = TEMA
	_area_ui.add_child(_painel)
	_painel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_painel.offset_right = 350
	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	_painel.add_child(margem)
	var coluna := VBoxContainer.new()
	margem.add_child(coluna)
	_texto(coluna, "Laboratório de Móveis", 18)
	_botao(coluna, "Ocultar painel · Tab", _alternar_painel)
	_botao(coluna, "Abrir Laboratório de Cenário 2D", func():
		get_tree().change_scene_to_file("res://scenes/desenvolvimento/laboratorios/laboratorio_cenario_2d.tscn"))
	_botao(coluna, "Voltar ao laboratório da mesa", func():
		get_tree().change_scene_to_file("res://scenes/desenvolvimento/laboratorios/laboratorio_perspectiva.tscn"))
	_seletor = OptionButton.new()
	_seletor.add_item("Estante esquerda")
	_seletor.add_item("Estante direita")
	coluna.add_child(_seletor)
	_seletor.item_selected.connect(func(indice: int):
		_selecionada = indice
		_mostrar_ajustes()
		_atualizar_cena())
	var navegacao := GridContainer.new()
	navegacao.columns = 3
	coluna.add_child(navegacao)
	for titulo in ["Estrutura", "Livros", "Posição", "Luz", "Composição", "Conjuntos"]:
		var botao := Button.new()
		botao.text = titulo
		botao.toggle_mode = true
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navegacao.add_child(botao)
		_botoes[titulo] = botao
		botao.pressed.connect(_selecionar_categoria.bind(titulo))
	_rolagem = ScrollContainer.new()
	_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(_rolagem)
	var conteudo := VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem.add_child(conteudo)
	for titulo in _botoes:
		var grupo := VBoxContainer.new()
		grupo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		conteudo.add_child(grupo)
		_categorias[titulo] = grupo
	_montar_estrutura(_categorias["Estrutura"])
	_montar_livros(_categorias["Livros"])
	_montar_posicao(_categorias["Posição"])
	_montar_luz(_categorias["Luz"])
	_montar_composicao(_categorias["Composição"])
	_montar_conjuntos(_categorias["Conjuntos"])
	_mensagem = _texto(coluna, "Referência: Teste ambiente 2 · mesa e câmera.")
	_selecionar_categoria("Estrutura")


func _montar_estrutura(grupo: VBoxContainer) -> void:
	_texto(grupo, "Dimensões e volume", 16)
	for chave in ["largura", "altura", "profundidade", "espessura", "prateleiras", "contraste", "claridade"]:
		var legendas := {"largura": "Largura", "altura": "Altura", "profundidade": "Profundidade",
			"espessura": "Espessura da estrutura", "prateleiras": "Quantidade de prateleiras",
			"contraste": "Contraste entre faces", "claridade": "Claridade do móvel"}
		_numero(grupo, "movel", chave, legendas[chave], PRESETS.LIMITES[chave],
			1.0 if chave in ["espessura", "prateleiras", "contraste", "claridade"] else 10.0,
			"%" if chave in ["contraste", "claridade"] else "")
	_cor(grupo, "movel", "cor_estrutura", "Cor da estrutura")
	_cor(grupo, "movel", "cor_fundo", "Cor do interior")
	_texto(grupo, "Ampliar o móvel abre espaço sem aumentar livros ou espessura das tábuas. Acrescente prateleiras para manter os vãos menores numa estante alta.")
	_botao(grupo, "Restaurar móvel selecionado", _restaurar_movel)


func _montar_livros(grupo: VBoxContainer) -> void:
	_opcao(grupo, "movel", "livros", "Mostrar livros")
	var legendas := {"quantidade_livros": "Livros por prateleira (máximo)",
		"largura_livros": "Largura das lombadas", "altura_livros": "Altura dos livros",
		"profundidade_livros": "Profundidade dos livros", "ocupacao_livros": "Faixa ocupada na prateleira"}
	for chave in legendas:
		_numero(grupo, "movel", chave, legendas[chave], PRESETS.LIMITES[chave], 1.0,
			"%" if chave == "ocupacao_livros" else "")
	_texto(grupo, "As medidas dos livros são independentes do móvel, com pequenas variações entre exemplares. Se faltar espaço, entram menos livros; altura e profundidade são limitadas ao vão disponível.")


func _montar_posicao(grupo: VBoxContainer) -> void:
	_opcao(grupo, "movel", "visivel", "Mostrar móvel selecionado")
	for chave in ["x", "distancia", "altura_base", "angulo", "inclinacao"]:
		var legendas := {"x": "Posição horizontal", "distancia": "Distância da mesa",
			"altura_base": "Altura da base", "angulo": "Ângulo na sala",
			"inclinacao": "Inclinação na tela (volante)"}
		_numero(grupo, "movel", chave, legendas[chave], PRESETS.LIMITES[chave],
			1.0 if chave in ["angulo", "inclinacao"] else 10.0,
			"°" if chave in ["angulo", "inclinacao"] else "")
	_texto(grupo, "Inclinação gira o móvel inteiro em torno do centro na tela. Positivo abaixa a direita; negativo abaixa a esquerda. Zero recupera a orientação original.")
	_botao(grupo, "Zerar somente a inclinação", func():
		_alterar_valor(0.0, "movel", "inclinacao")
		_mostrar_ajustes())
	_texto(grupo, "Projeção do móvel")
	_projecao = OptionButton.new()
	_projecao.add_item("Perspectiva atual")
	_projecao.add_item("Verticais retas")
	grupo.add_child(_projecao)
	_projecao.item_selected.connect(func(indice: int):
		_alterar_opcao(indice == 1, "movel", "verticais_retas"))
	_texto(grupo, "Distância maior afasta o móvel. Altura da base 0 corresponde ao nível do tampo.")
	_botao(grupo, "Espelhar na outra estante", _espelhar)


func _montar_luz(grupo: VBoxContainer) -> void:
	_texto(grupo, "Luz dos móveis", 16)
	_opcao(grupo, "luz", "ativa", "Ligar luz local")
	_opcao(grupo, "vista", "ver_luz", "Mostrar posição da luz")
	var legendas := {"ambiente": "Claridade geral", "x": "Posição horizontal da luz",
		"distancia": "Distância da luz", "altura": "Altura da luz",
		"intensidade": "Intensidade local", "alcance": "Alcance da luz"}
	for chave in LIMITES_LUZ:
		_numero(grupo, "luz", chave, legendas[chave], LIMITES_LUZ[chave],
			1.0 if chave in ["ambiente", "intensidade"] else 10.0,
			"%" if chave in ["ambiente", "intensidade"] else "")
	_cor(grupo, "luz", "cor", "Cor da luz local")
	_texto(grupo, "A luz afeta tampo, laterais, prateleiras e livros conforme a distância e a face. A mesa é uma referência; esta luz não cria sombras projetadas.")
	_botao(grupo, "Restaurar iluminação", func():
		_luz = PADRAO_LUZ.duplicate()
		_mostrar_ajustes()
		_atualizar_cena())


func _montar_composicao(grupo: VBoxContainer) -> void:
	_opcao(grupo, "vista", "mesa", "Mostrar mesa de referência")
	_opcao(grupo, "vista", "outra", "Mostrar também a outra estante")
	_opcao(grupo, "vista", "focar", "Focar móvel selecionado")
	_texto(grupo, "Enquadramento", 16)
	for chave in LIMITES_VISAO:
		_numero(grupo, "visao", chave, {"zoom": "Aproximação", "x": "Deslocamento horizontal", "y": "Deslocamento vertical"}[chave],
			LIMITES_VISAO[chave], 1.0, "%")
	_texto(grupo, "Perspectiva dos móveis", 16)
	_numero(grupo, "camera_moveis", "profundidade_camera", "Profundidade na tela dos móveis",
		PRESETS.LIMITES_CAMERA["profundidade_camera"], 5.0)
	_numero(grupo, "camera_moveis", "perspectiva", "Largura distante dos móveis",
		PRESETS.LIMITES_CAMERA["perspectiva"], 1.0, "%")
	_texto(grupo, "Os dois móveis usam esta perspectiva. A mesa tem ajustes próprios; zoom e deslocamento geral continuam compartilhados.")
	_botao(grupo, "Restaurar perspectiva dos móveis (200)", func():
		_camera_moveis = PRESETS.PADRAO_CAMERA.duplicate()
		_mostrar_ajustes()
		_atualizar_cena())
	_texto(grupo, "Perspectiva da mesa", 16)
	_numero(grupo, "mesa", "profundidade_camera", "Profundidade na tela", LIMITES_MESA["profundidade_camera"], 5.0)
	_numero(grupo, "mesa", "perspectiva", "Largura distante", LIMITES_MESA["perspectiva"], 1.0, "%")
	_texto(grupo, "Mesa de referência", 16)
	for chave in ["largura", "profundidade", "moldura", "espessura", "x", "y"]:
		var legendas := {"largura": "Largura do tampo", "profundidade": "Profundidade do tampo",
			"moldura": "Moldura", "espessura": "Espessura da mesa", "x": "Posição X da mesa", "y": "Posição Y da mesa"}
		_numero(grupo, "mesa", chave, legendas[chave], LIMITES_MESA[chave],
			1.0 if chave in ["x", "y"] else 5.0, "%" if chave in ["x", "y"] else "")
	_botao(grupo, "Recuperar mesa e câmera: Teste ambiente 2", _restaurar_referencia)


func _montar_conjuntos(grupo: VBoxContainer) -> void:
	_texto(grupo, "Biblioteca de móveis", 16)
	_texto(grupo, "Compartilhada com o laboratório da mesa. Carregar recupera estrutura e aparência, mantendo a posição, o ângulo e a inclinação atuais.")
	_nome_movel = LineEdit.new()
	_nome_movel.placeholder_text = "Nome do móvel"
	_nome_movel.max_length = 80
	grupo.add_child(_nome_movel)
	_botao(grupo, "Salvar móvel", _salvar_movel)
	_lista_moveis = OptionButton.new()
	grupo.add_child(_lista_moveis)
	_botao(grupo, "Carregar móvel selecionado", _carregar_movel)
	_texto(grupo, "Composição deste laboratório", 16)
	_texto(grupo, "Guarda os dois móveis, suas posições, mesa, as duas perspectivas e luz juntos.")
	_nome_composicao = LineEdit.new()
	_nome_composicao.placeholder_text = "Nome da composição"
	_nome_composicao.max_length = 80
	grupo.add_child(_nome_composicao)
	_botao(grupo, "Salvar composição completa", _salvar_composicao)
	_lista_composicoes = OptionButton.new()
	grupo.add_child(_lista_composicoes)
	_botao(grupo, "Carregar composição completa", _carregar_composicao)
	_botao(grupo, "Atualizar listas", _atualizar_listas)
	_atualizar_listas()


func _numero(grupo: VBoxContainer, familia: String, chave: String, legenda: String,
		limites: Vector2, passo: float, unidade: String = "") -> void:
	var linha := HBoxContainer.new()
	grupo.add_child(linha)
	var rotulo := _texto(linha, legenda)
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var numero := SpinBox.new()
	numero.custom_minimum_size.x = 96
	numero.min_value = limites.x
	numero.max_value = limites.y
	numero.step = passo
	numero.suffix = unidade
	linha.add_child(numero)
	var slider := HSlider.new()
	slider.min_value = limites.x
	slider.max_value = limites.y
	slider.step = passo
	slider.share(numero)
	grupo.add_child(slider)
	_campos[familia + "/" + chave] = slider
	slider.value_changed.connect(_alterar_valor.bind(familia, chave))


func _opcao(grupo: VBoxContainer, familia: String, chave: String, legenda: String) -> void:
	var opcao := CheckBox.new()
	opcao.text = legenda
	grupo.add_child(opcao)
	_campos[familia + "/" + chave] = opcao
	opcao.toggled.connect(_alterar_opcao.bind(familia, chave))


func _cor(grupo: VBoxContainer, familia: String, chave: String, legenda: String) -> void:
	_texto(grupo, legenda)
	var campo := ColorPickerButton.new()
	campo.edit_alpha = false
	campo.custom_minimum_size.y = 32
	grupo.add_child(campo)
	_campos[familia + "/" + chave] = campo
	campo.color_changed.connect(_alterar_cor.bind(familia, chave))


func _texto(pai: Node, texto: String, tamanho: int = 14) -> Label:
	var legenda := Label.new()
	legenda.text = texto
	legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legenda.add_theme_font_size_override("font_size", tamanho)
	pai.add_child(legenda)
	return legenda


func _botao(pai: Node, texto: String, acao: Callable) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.tooltip_text = texto
	botao.clip_text = true
	botao.custom_minimum_size.y = 32
	pai.add_child(botao)
	botao.pressed.connect(acao)


func _selecionar_categoria(titulo: String) -> void:
	for categoria in _categorias:
		(_categorias[categoria] as VBoxContainer).visible = categoria == titulo
		(_botoes[categoria] as Button).set_pressed_no_signal(categoria == titulo)
	_rolagem.scroll_vertical = 0


func _dados(familia: String) -> Dictionary:
	match familia:
		"movel": return _perfis[_selecionada]
		"mesa": return _mesa_ajustes
		"camera_moveis": return _camera_moveis
		"visao": return _visao
		"luz": return _luz
		_: return _vista


func _mostrar_ajustes() -> void:
	_atualizando_ui = true
	_seletor.select(_selecionada)
	for identificador in _campos:
		var partes: PackedStringArray = identificador.split("/")
		var valor: Variant = _dados(partes[0])[partes[1]]
		var campo: Control = _campos[identificador]
		if campo is HSlider:
			campo.set_value_no_signal(float(valor))
		elif campo is CheckBox:
			campo.set_pressed_no_signal(bool(valor))
		elif campo is ColorPickerButton:
			campo.color = Color.html(str(valor))
	_projecao.select(1 if bool(_perfis[_selecionada]["verticais_retas"]) else 0)
	_atualizando_ui = false


func _alterar_valor(valor: float, familia: String, chave: String) -> void:
	if _atualizando_ui:
		return
	_dados(familia)[chave] = valor
	_atualizar_cena()


func _alterar_opcao(valor: bool, familia: String, chave: String) -> void:
	if _atualizando_ui:
		return
	_dados(familia)[chave] = valor
	_atualizar_cena()


func _alterar_cor(valor: Color, familia: String, chave: String) -> void:
	if _atualizando_ui:
		return
	_dados(familia)[chave] = valor.to_html(false)
	_atualizar_cena()


func _projetar(ponto: Vector3) -> Vector2:
	return PROJECAO.ponto_sala(_mesa, ponto, _camera_moveis)


func _atualizar_cena() -> void:
	_mesa.formato = roundi(_mesa_ajustes["formato"])
	_mesa.largura_proxima = 1600.0
	_mesa.dimensoes_tampo = Vector2(_mesa_ajustes["largura"], _mesa_ajustes["profundidade"])
	_mesa.position = REFERENCIA * Vector2(_mesa_ajustes["x"], _mesa_ajustes["y"]) / 100.0
	_mesa.profundidade_aparente = _mesa_ajustes["profundidade_camera"]
	_mesa.largura_distante = float(_mesa_ajustes["perspectiva"]) / 100.0
	_mesa.largura_moldura = _mesa_ajustes["moldura"]
	_mesa.espessura = _mesa_ajustes["espessura"]
	_mesa.definir_tamanho_plano(Vector2(1600, 700))
	_mesa.visible = bool(_vista["mesa"])
	var iluminacao := _luz.duplicate()
	iluminacao["posicao"] = Vector3(800.0 + float(_luz["x"]), -float(_luz["distancia"]), float(_luz["altura"]))
	iluminacao["cor"] = Color.html(_luz["cor"])
	for indice in range(2):
		_estantes[indice].configurar(_perfis[indice], _mesa.tamanho_plano, _projetar,
			iluminacao, PROJECAO.posicao_camera(_mesa, _camera_moveis))
		_estantes[indice].visible = _estantes[indice].visible and (indice == _selecionada or bool(_vista["outra"]))
	var posicao := _projetar(iluminacao["posicao"])
	_marcador.visible = bool(_vista["ver_luz"]) and bool(_luz["ativa"]) and posicao.is_finite()
	if posicao.is_finite():
		_marcador.position = posicao
	_marcador.color = iluminacao["cor"]
	_ajustar_enquadramento()


func _ajustar_enquadramento() -> void:
	if not is_instance_valid(_area_ui):
		return
	_area_ui.size = size
	var fator := maxf(minf(size.x / REFERENCIA.x, size.y / REFERENCIA.y), 0.001)
	var zoom := float(_visao["zoom"]) / 100.0
	var centro := REFERENCIA / 2.0
	if bool(_vista["focar"]) and _estantes[_selecionada].visible:
		centro = _estantes[_selecionada].obter_limites().get_center()
	var deslocamento := REFERENCIA * Vector2(_visao["x"], _visao["y"]) / 100.0
	_composicao.scale = Vector2.ONE * fator * zoom
	_composicao.position = size / 2.0 - centro * fator * zoom + deslocamento * fator


func _alternar_painel() -> void:
	_painel.visible = not _painel.visible
	var foco := get_viewport().gui_get_focus_owner()
	if foco != null:
		foco.release_focus()


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_TAB:
		_alternar_painel()
		get_viewport().set_input_as_handled()


func _espelhar() -> void:
	var perfil := _perfis[_selecionada].duplicate()
	perfil["x"] = -float(perfil["x"])
	perfil["angulo"] = -float(perfil["angulo"])
	perfil["inclinacao"] = -float(perfil["inclinacao"])
	_perfis[1 - _selecionada] = perfil
	_atualizar_cena()


func _restaurar_movel() -> void:
	_perfis[_selecionada] = PRESETS.aplicar_movel(PRESETS.padrao(_selecionada), _perfis[_selecionada], _selecionada)
	_mostrar_ajustes()
	_atualizar_cena()


func _restaurar_referencia() -> void:
	_mesa_ajustes = PADRAO_MESA.duplicate()
	_visao = PADRAO_VISAO.duplicate()
	_vista["focar"] = false
	_mostrar_ajustes()
	_atualizar_cena()


func _validar(dados: Variant, padrao: Dictionary, limites: Dictionary) -> Dictionary:
	var resultado := padrao.duplicate()
	if dados is Dictionary:
		for chave in limites:
			var valor: Variant = dados.get(chave)
			if (valor is float or valor is int) and is_finite(float(valor)):
				resultado[chave] = clampf(float(valor), limites[chave].x, limites[chave].y)
	return resultado


func _atualizar_listas() -> void:
	for grupo in ["moveis", "composicoes"]:
		var lista := _lista_moveis if grupo == "moveis" else _lista_composicoes
		lista.clear()
		var nomes: Array = PRESETS.ler(grupo).keys()
		nomes.sort()
		for nome in nomes:
			lista.add_item(str(nome))


func _salvar_movel() -> void:
	_salvar("moveis", _nome_movel.text, _perfis[_selecionada])


func _salvar_composicao() -> void:
	_salvar("composicoes", _nome_composicao.text, {"mesa": _mesa_ajustes.duplicate(),
		"camera_moveis": _camera_moveis.duplicate(),
		"enquadramento": _visao.duplicate(), "estantes": _perfis.duplicate(true),
		"luz": _luz.duplicate(), "vista": _vista.duplicate(), "selecionada": _selecionada})


func _salvar(grupo: String, texto: String, perfil: Dictionary) -> void:
	var nome := texto.strip_edges()
	if nome.is_empty():
		_mensagem.text = "Dê um nome antes de salvar."
		return
	var erro: Error = PRESETS.salvar(grupo, nome, perfil)
	_mensagem.text = "Salvo: " + nome if erro == OK else "Não foi possível salvar: " + error_string(erro)
	_atualizar_listas()


func _carregar_movel() -> void:
	if _lista_moveis.selected < 0:
		return
	var nome := _lista_moveis.get_item_text(_lista_moveis.selected)
	var dados: Dictionary = PRESETS.ler("moveis")
	if not dados.has(nome):
		return
	_perfis[_selecionada] = PRESETS.aplicar_movel(dados[nome], _perfis[_selecionada], _selecionada)
	_mostrar_ajustes()
	_atualizar_cena()
	_mensagem.text = "Móvel carregado: " + nome + ". Posição, ângulo e inclinação preservados."


func _carregar_composicao() -> void:
	if _lista_composicoes.selected < 0:
		return
	var nome := _lista_composicoes.get_item_text(_lista_composicoes.selected)
	var arquivo: Dictionary = PRESETS.ler("composicoes")
	var dados: Variant = arquivo.get(nome)
	if not dados is Dictionary:
		return
	_mesa_ajustes = _validar(dados.get("mesa"), PADRAO_MESA, LIMITES_MESA)
	_camera_moveis = PRESETS.validar_camera(dados.get("camera_moveis"), _mesa_ajustes)
	_visao = _validar(dados.get("enquadramento"), PADRAO_VISAO, LIMITES_VISAO)
	_luz = _validar(dados.get("luz"), PADRAO_LUZ, LIMITES_LUZ)
	var luz_salva: Variant = dados.get("luz", {})
	if luz_salva is Dictionary:
		if luz_salva.get("ativa") is bool:
			_luz["ativa"] = luz_salva["ativa"]
		if luz_salva.get("cor") is String and Color.html_is_valid(luz_salva["cor"]):
			_luz["cor"] = Color.html(luz_salva["cor"]).to_html(false)
	var estantes: Variant = dados.get("estantes")
	for indice in range(2):
		_perfis[indice] = PRESETS.validar(estantes[indice] if estantes is Array and estantes.size() == 2 else {}, indice)
	_vista = PADRAO_VISTA.duplicate()
	var vista: Variant = dados.get("vista")
	if vista is Dictionary:
		for chave in _vista:
			if vista.get(chave) is bool:
				_vista[chave] = vista[chave]
	var selecionada: Variant = dados.get("selecionada")
	_selecionada = 0
	if (selecionada is int or selecionada is float) and is_finite(float(selecionada)):
		_selecionada = roundi(clampf(float(selecionada), 0.0, 1.0))
	_mostrar_ajustes()
	_atualizar_cena()
	_mensagem.text = "Composição carregada: " + nome
