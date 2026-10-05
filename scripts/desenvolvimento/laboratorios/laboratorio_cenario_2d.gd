extends Control

const CATALOGO = preload("res://scripts/desenvolvimento/laboratorios/interno/catalogo_cenario_2d.gd")
const ASSET = preload("res://scripts/desenvolvimento/laboratorios/asset_cenario_2d.gd")
const CARTAS = preload("res://scripts/desenvolvimento/laboratorios/cartas_cenario_2d.gd")
const LUZ = preload("res://scripts/desenvolvimento/laboratorios/interno/luz_cenario_2d.gd")
const HALOS = preload("res://scripts/desenvolvimento/laboratorios/halos_cenario_2d.gd")
const TEMA = preload("res://scenes/desenvolvimento/laboratorios/painel_laboratorio.tres")
const ARQUIVO := "user://laboratorio_cenario_2d.json"
const REFERENCIA := Vector2(1280, 720)
const LARGURA_PAINEL := 350.0

@onready var _composicao: Node2D = $Composicao

var _pecas: Array[Dictionary] = []
var _nos: Dictionary = {}
var _selecionada := -1
var _proximo_id := 1
var _painel: PanelContainer
var _area_ui: Control
var _guias: Node2D
var _seletor: OptionButton
var _catalogo: OptionButton
var _nome: LineEdit
var _nome_conjunto: LineEdit
var _lista_conjuntos: OptionButton
var _mensagem: Label
var _rolagem: ScrollContainer
var _categorias: Dictionary = {}
var _botoes: Dictionary = {}
var _campos: Dictionary = {}
var _atualizando_ui := false
var _editar_cantos := false
var _mostrar_moldura := true
var _zoom := 100.0
var _pan := Vector2.ZERO
var _arrasto := ""
var _canto := -1
var _inicio_mouse := Vector2.ZERO
var _inicio_posicao := Vector2.ZERO
var _historico: Array[Dictionary] = []
var _refazer: Array[Dictionary] = []
var _biblioteca: Dictionary = {}
var _biblioteca_corrompida := false
var _ajuste_continuo := false
var _cartas := CARTAS.padrao()
var _referencia_cartas: CARTAS
var _campos_cartas: Dictionary = {}
var _seletor_cartas: OptionButton
var _conjuntos_cartas: Dictionary = {}
var _categoria_ativa := "Peças"
var _luz := LUZ.padrao()
var _fonte_selecionada := -1
var _lista_fontes: OptionButton
var _contagem_fontes: Label
var _alvos_fontes: VBoxContainer
var _campos_luz: Array[Dictionary] = []
var _paginas_luz: Dictionary = {}
var _pagina_luz := "Peça selecionada"
var _mostrar_fontes := true
var _halos: HALOS
var _lista_halos: OptionButton
var _bloco_brilho: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pecas = CATALOGO.composicao_inicial()
	_proximo_id = _pecas.size() + 1
	_selecionada = 3
	_ler_biblioteca()
	if _biblioteca.get("ultima") is Dictionary:
		_aplicar_estado(_biblioteca["ultima"])
	_referencia_cartas = CARTAS.new()
	_composicao.add_child(_referencia_cartas)
	_halos = HALOS.new()
	_composicao.add_child(_halos)
	_montar_painel()
	_guias = Node2D.new()
	_guias.z_index = 200
	_guias.draw.connect(_desenhar_guias)
	_composicao.add_child(_guias)
	resized.connect(_ajustar_enquadramento)
	_atualizar_cena()
	_sincronizar_ui()
	_listar_conjuntos()
	_ajustar_enquadramento()
	if _biblioteca_corrompida:
		_mensagem.text = "O arquivo salvo não pôde ser lido. Ele foi preservado."


func _montar_painel() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 1
	add_child(camada)
	_area_ui = Control.new()
	_area_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_area_ui)
	_painel = PanelContainer.new()
	_painel.theme = TEMA
	_area_ui.add_child(_painel)
	_painel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_painel.offset_right = LARGURA_PAINEL
	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 12)
	_painel.add_child(margem)
	var coluna := VBoxContainer.new()
	margem.add_child(coluna)
	_texto(coluna, "Laboratório de Cenário 2D", 18)
	_botao(coluna, "Ocultar painel · Tab", _alternar_painel)
	_botao(coluna, "Voltar ao Laboratório de Móveis", func():
		get_tree().change_scene_to_file("res://scenes/desenvolvimento/laboratorios/laboratorio_moveis.tscn"))
	_seletor = OptionButton.new()
	coluna.add_child(_seletor)
	_seletor.item_selected.connect(func(indice: int):
		_selecionada = indice
		_sincronizar_ui()
		_guias.queue_redraw())
	var navegacao := GridContainer.new()
	navegacao.columns = 2
	coluna.add_child(navegacao)
	for titulo in ["Peças", "Encaixe", "Recorte", "Cartas", "Luz", "Conjuntos"]:
		var botao := Button.new()
		botao.text = titulo
		botao.toggle_mode = true
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navegacao.add_child(botao)
		_botoes[titulo] = botao
		botao.pressed.connect(_categoria.bind(titulo))
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
	_montar_pecas(_categorias["Peças"])
	_montar_encaixe(_categorias["Encaixe"])
	_montar_recorte(_categorias["Recorte"])
	_montar_cartas(_categorias["Cartas"])
	_montar_luz(_categorias["Luz"])
	_montar_conjuntos(_categorias["Conjuntos"])
	var acoes := HBoxContainer.new()
	coluna.add_child(acoes)
	_botao(acoes, "Desfazer", _desfazer)
	_botao(acoes, "Refazer", _refazer_acao)
	_mensagem = _texto(coluna, "Arraste a peça · roda: zoom · botão do meio: mover vista", 13)
	_categoria("Peças")


func _montar_pecas(grupo: VBoxContainer) -> void:
	_texto(grupo, "Adicionar uma imagem ou um recorte")
	_catalogo = OptionButton.new()
	for modelo in CATALOGO.PECAS:
		_catalogo.add_item(str(modelo["nome"]))
	grupo.add_child(_catalogo)
	_botao(grupo, "Adicionar à cena", _adicionar)
	_texto(grupo, "Peça selecionada", 16)
	_nome = LineEdit.new()
	_nome.placeholder_text = "Nome da peça"
	grupo.add_child(_nome)
	_nome.text_submitted.connect(_renomear)
	_nome.focus_exited.connect(func(): _renomear(_nome.text))
	_opcao(grupo, "visivel", "Mostrar peça")
	_opcao(grupo, "travada", "Travar peça na cena")
	_opcao(grupo, "espelhar", "Espelhar imagem")
	_numero(grupo, "camada", "Camada (maior = à frente)", Vector2(-100, 100), 1)
	_botao(grupo, "Duplicar peça", _duplicar)
	_botao(grupo, "Remover peça", _remover)
	_botao(grupo, "Mostrar / ocultar a mesa", _alternar_mesa)
	_texto(grupo, "A mesa e seu ornamento podem ser ocultados juntos. Travar impede seleção pelo mouse e arrasto; os campos continuam disponíveis. Use a aba Cartas para comparar o cenário com mãos e pilhas.")


func _montar_encaixe(grupo: VBoxContainer) -> void:
	_texto(grupo, "Posição e dimensões", 16)
	_texto(grupo, "Medidas na composição de 1280 × 720. O zoom da vista não altera o tamanho das peças.")
	for dados in [["x", "Horizontal"], ["y", "Vertical"], ["largura", "Largura"],
		["altura", "Altura"], ["giro", "Giro como volante"]]:
		_numero(grupo, str(dados[0]), str(dados[1]), CATALOGO.LIMITES[dados[0]], 1)
	_opcao(grupo, "proporcional", "Manter proporção ao redimensionar")
	_botao(grupo, "Restaurar proporção do recorte", _restaurar_proporcao)
	_texto(grupo, "Perspectiva da imagem", 16)
	var cantos := CheckBox.new()
	cantos.text = "Arrastar os quatro cantos"
	grupo.add_child(cantos)
	cantos.toggled.connect(func(ativa: bool):
		_editar_cantos = ativa
		_guias.queue_redraw())
	_texto(grupo, "Desligue para mover a peça inteira. Os cantos mudam o encaixe de cada imagem; sua profundidade pintada continua sendo a do asset.")
	for indice in range(4):
		_texto(grupo, ["Superior esquerdo", "Superior direito", "Inferior direito", "Inferior esquerdo"][indice])
		_numero(grupo, "canto_%d_x" % indice, "Horizontal (%)", Vector2(-100, 200), 1)
		_numero(grupo, "canto_%d_y" % indice, "Vertical (%)", Vector2(-100, 200), 1)
	_botao(grupo, "Restaurar os quatro cantos", _restaurar_cantos)
	_texto(grupo, "Vista", 16)
	var moldura := CheckBox.new()
	moldura.text = "Mostrar limite da composição"
	moldura.button_pressed = true
	grupo.add_child(moldura)
	moldura.toggled.connect(func(ativa: bool):
		_mostrar_moldura = ativa
		_guias.queue_redraw())
	_botao(grupo, "Enquadrar a composição inteira", _restaurar_vista)


func _montar_recorte(grupo: VBoxContainer) -> void:
	_texto(grupo, "Região da imagem original", 16)
	_texto(grupo, "Origem no canto superior esquerdo, em pixels. Ajuste para separar qualquer vela, hera ou ornamento da folha. O original permanece intacto.")
	for indice in range(4):
		_numero(grupo, "recorte_%d" % indice, ["Origem X", "Origem Y", "Largura do recorte", "Altura do recorte"][indice],
			Vector2(0 if indice < 2 else 1, 4096), 1)
	_botao(grupo, "Usar imagem completa", _recorte_completo)
	_texto(grupo, "O tamanho na cena é separado do recorte. Depois de recortar, use Restaurar proporção se quiser recuperar a forma original da peça.")


func _montar_conjuntos(grupo: VBoxContainer) -> void:
	_texto(grupo, "Composições salvas", 16)
	_nome_conjunto = LineEdit.new()
	_nome_conjunto.placeholder_text = "Nome da composição"
	grupo.add_child(_nome_conjunto)
	_botao(grupo, "Salvar composição", _salvar)
	_lista_conjuntos = OptionButton.new()
	grupo.add_child(_lista_conjuntos)
	_botao(grupo, "Carregar composição selecionada", _carregar)
	_botao(grupo, "Voltar à composição inicial", _composicao_inicial)
	_botao(grupo, "Começar uma cena vazia", _esvaziar)
	_texto(grupo, "Peças, recortes, cantos, cartas, luzes, sombras e enquadramento são salvos neste laboratório. Ao reabrir, aparece a última composição salva/carregada. Os presets dos outros laboratórios são preservados.")


func _montar_cartas(grupo: VBoxContainer) -> void:
	_texto(grupo, "Mesa do Laboratório Perspectiva", 16)
	_opcao_cartas(grupo, "visivel", "Mostrar conjunto com as cartas")
	_opcao_cartas(grupo, "mesa_visivel", "Mostrar a mesa de referência")
	_texto(grupo, "Ocultar a mesa de referência conserva as cartas e suas sombras no mesmo lugar. A mesa em imagem continua independente, na lista de peças.")
	_conjuntos_cartas = CARTAS.conjuntos()
	_seletor_cartas = OptionButton.new()
	var nomes := _conjuntos_cartas.keys()
	nomes.sort()
	for nome in nomes:
		_seletor_cartas.add_item(str(nome))
	grupo.add_child(_seletor_cartas)
	_botao(grupo, "Carregar preset selecionado", _carregar_referencia_cartas)
	_texto(grupo, "A base é Teste ambiente 2: a própria cena de perspectiva, com mãos, pilhas, câmera e sombras. Os ajustes de luz ficam na aba Luz > Luz da mesa; a vela procedural permanece oculta.")
	for item in [["x", "Deslocamento horizontal"], ["y", "Deslocamento vertical"],
		["tamanho", "Tamanho do conjunto (%)"], ["camada", "Camada do conjunto"]]:
		_numero_cartas(grupo, str(item[0]), str(item[1]))
	_botao(grupo, "Restaurar encaixe do conjunto", func():
		_registrar()
		_cartas["x"] = 0.0
		_cartas["y"] = 0.0
		_cartas["tamanho"] = 100.0
		_atualizar_cena()
		_sincronizar_cartas())
	_texto(grupo, "Nesta aba, o arrasto move mesa e cartas juntas. O tamanho também muda o conjunto inteiro, conservando a projeção original. Nas outras abas você continua editando os assets.")


func _carregar_referencia_cartas() -> void:
	if _seletor_cartas.selected < 0:
		return
	var nome := _seletor_cartas.get_item_text(_seletor_cartas.selected)
	if not _conjuntos_cartas.has(nome):
		return
	_registrar()
	_cartas["preset"] = nome
	_cartas["perfil"] = _conjuntos_cartas[nome].duplicate(true)
	_atualizar_cena()
	_sincronizar_cartas()
	_mensagem.text = "Mesa e cartas: " + nome


func _opcao_cartas(pai: Node, chave: String, texto: String) -> void:
	var check := CheckBox.new()
	check.text = texto
	pai.add_child(check)
	_campos_cartas[chave] = check
	check.toggled.connect(func(ativa: bool):
		if _atualizando_ui:
			return
		_registrar()
		_cartas[chave] = ativa
		_atualizar_cena())


func _numero_cartas(pai: Node, chave: String, texto: String) -> void:
	_texto(pai, texto)
	var linha := HBoxContainer.new()
	pai.add_child(linha)
	var limites: Vector2 = CARTAS.LIMITES[chave]
	var spin := SpinBox.new()
	spin.min_value = limites.x
	spin.max_value = limites.y
	spin.step = 1
	spin.custom_minimum_size.x = 100
	var slider := HSlider.new()
	slider.min_value = limites.x
	slider.max_value = limites.y
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(slider)
	linha.add_child(spin)
	slider.share(spin)
	_campos_cartas[chave] = spin
	slider.drag_started.connect(func():
		_registrar()
		_ajuste_continuo = true)
	slider.drag_ended.connect(func(_mudou: bool): _ajuste_continuo = false)
	spin.value_changed.connect(func(valor: float):
		if _atualizando_ui:
			return
		_registrar()
		_cartas[chave] = valor
		_atualizar_cena())


func _sincronizar_cartas() -> void:
	_atualizando_ui = true
	var nome := str(_cartas["preset"])
	var encontrado := false
	for indice in range(_seletor_cartas.item_count):
		if _seletor_cartas.get_item_text(indice) == nome:
			_seletor_cartas.select(indice)
			encontrado = true
			break
	if not encontrado:
		_seletor_cartas.add_item(nome)
		_seletor_cartas.select(_seletor_cartas.item_count - 1)
		_conjuntos_cartas[nome] = _cartas["perfil"].duplicate(true)
	for chave in _campos_cartas:
		var campo: Control = _campos_cartas[chave]
		if campo is CheckBox:
			var check := campo as CheckBox
			check.set_pressed_no_signal(bool(_cartas[chave]))
		else:
			var spin := campo as SpinBox
			spin.set_value_no_signal(float(_cartas[chave]))
	_atualizando_ui = false


func _montar_luz(grupo: VBoxContainer) -> void:
	_campo_luz(grupo, "geral", "ativa", "Ativar efeitos · desligue para comparar", "opcao")
	var paginas := OptionButton.new()
	grupo.add_child(paginas)
	for titulo in ["Peça selecionada", "Pontos e sombras", "Halo da luz", "Luz da mesa"]:
		paginas.add_item(titulo)
		var pagina := VBoxContainer.new()
		grupo.add_child(pagina)
		pagina.visible = titulo == _pagina_luz
		_paginas_luz[titulo] = pagina
	paginas.item_selected.connect(func(indice: int):
		_pagina_luz = paginas.get_item_text(indice)
		for titulo in _paginas_luz:
			_paginas_luz[titulo].visible = titulo == _pagina_luz
		_rolagem.scroll_vertical = 0
		_guias.queue_redraw())
	var peca: VBoxContainer = _paginas_luz["Peça selecionada"]
	_texto(peca, "Aparência da peça escolhida no topo", 16)
	for item in [["claridade", "Claridade ambiente (%)"], ["contraste", "Contraste (%)"], ["saturacao", "Saturação (%)"]]:
		_campo_luz(peca, "peca", item[0], item[1], "numero", LUZ.LIMITES_PECA[item[0]])
	_campo_luz(peca, "peca", "mesa", "Receber também a luz principal da mesa", "opcao")
	_botao(peca, "Restaurar aparência da peça", func():
		if _selecionada < 0:
			return
		_registrar()
		var p: Dictionary = _pecas[_selecionada]
		p["aparencia"] = LUZ.validar_peca({}, p["arquivo"] in ["mesa.png", "deco_mesa.png"])
		_atualizar_cena()
		_sincronizar_luz())
	_texto(peca, "100% conserva a imagem original. Reduza a claridade do fundo/chão e experimente o contraste. Os pontos de luz podem recuperar claridade localmente.")
	var fontes: VBoxContainer = _paginas_luz["Pontos e sombras"]
	_contagem_fontes = _texto(fontes, "")
	_lista_fontes = OptionButton.new()
	fontes.add_child(_lista_fontes)
	_lista_fontes.item_selected.connect(func(indice: int):
		_fonte_selecionada = indice
		_sincronizar_luz()
		_guias.queue_redraw())
	var adicionar := HBoxContainer.new()
	fontes.add_child(adicionar)
	_botao(adicionar, "+ Luz", _adicionar_fonte.bind(false))
	_botao(adicionar, "+ Sombra", _adicionar_fonte.bind(true))
	_botao(adicionar, "+ Brilho", _adicionar_fonte.bind(false, true))
	_botao(fontes, "Duplicar fonte selecionada", _duplicar_fonte)
	_botao(fontes, "Remover fonte selecionada", _remover_fonte)
	_campo_luz(fontes, "fonte", "nome", "Nome", "texto")
	_campo_luz(fontes, "fonte", "visivel", "Mostrar esta luz / sombra", "opcao")
	for item in [["x", "Horizontal"], ["y", "Vertical"], ["largura", "Alcance horizontal (diâmetro)"],
		["altura", "Alcance vertical (diâmetro)"], ["giro", "Giro da área"],
		["intensidade", "Intensidade (%)"], ["suavidade", "Suavidade (%)"]]:
		_campo_luz(fontes, "fonte", item[0], item[1], "numero", LUZ.LIMITES[item[0]])
	_campo_luz(fontes, "fonte", "cor", "Cor da luz (sombras escurecem)", "cor")
	_bloco_brilho = VBoxContainer.new()
	fontes.add_child(_bloco_brilho)
	_texto(_bloco_brilho, "Brilho de superfície", 16)
	_campo_luz(_bloco_brilho, "brilho", "concentracao", "Concentrar o brilho (%)", "numero", LUZ.LIMITES_BRILHO["concentracao"])
	_campo_luz(_bloco_brilho, "brilho", "material", "Preservar detalhes da imagem (%)", "numero", LUZ.LIMITES_BRILHO["material"])
	_texto(_bloco_brilho, "Ajuste a faixa sobre a borda ou o metal. Preservar detalhes reduz o brilho nas partes escuras da textura; não detecta madeira ou metal automaticamente.")
	_campo_luz(fontes, "fonte", "todas", "Afetar todas as imagens", "opcao")
	_texto(fontes, "Imagens afetadas (desmarque Todas para escolher)")
	_alvos_fontes = VBoxContainer.new()
	fontes.add_child(_alvos_fontes)
	_campo_luz(fontes, "fonte", "cartas", "Afetar também mesa de referência e cartas", "opcao")
	var marcas := CheckBox.new()
	marcas.text = "Mostrar centros e alcance no painel"
	marcas.button_pressed = true
	fontes.add_child(marcas)
	marcas.toggled.connect(func(ativa: bool):
		_mostrar_fontes = ativa
		_guias.queue_redraw())
	_texto(fontes, "Arraste o centro de uma fonte nesta página. Para apoiar um móvel no chão, adicione uma sombra alongada e escolha o chão como receptor. Para reflexos, use + Brilho e selecione a imagem. As áreas não calculam obstáculos ou reflexos físicos.")
	var halo: VBoxContainer = _paginas_luz["Halo da luz"]
	_lista_halos = OptionButton.new()
	halo.add_child(_lista_halos)
	_lista_halos.item_selected.connect(func(indice: int):
		_fonte_selecionada = indice
		_sincronizar_luz()
		_guias.queue_redraw())
	_texto(halo, "Halo da fonte selecionada", 16)
	_botao(halo, "Duplicar só o halo", _duplicar_fonte.bind(true))
	_texto(halo, "A cópia mantém o halo e começa com intensidade de luz zero. Você pode mover e ajustar a cópia separadamente; ela ocupa uma vaga na lista de fontes.")
	_texto(halo, "Disponível nos pontos de luz. Encaixe o halo na chama usando o deslocamento ou arrastando seu centro nesta página. O halo acompanha a luz quando ela se move, mas tem tamanho, cor e camada próprios.")
	_campo_luz(halo, "halo", "halo_ativo", "Mostrar halo", "opcao")
	for item in [["halo_x", "Deslocamento horizontal"], ["halo_y", "Deslocamento vertical"],
		["halo_largura", "Largura do halo"], ["halo_altura", "Altura do halo"], ["halo_giro", "Giro do halo"],
		["halo_intensidade", "Intensidade do halo (%)"], ["halo_camada", "Camada do halo"]]:
		_campo_luz(halo, "halo", item[0], item[1], "numero", LUZ.LIMITES_HALO[item[0]])
	_campo_luz(halo, "halo", "halo_cor", "Cor do halo", "cor")
	_texto(halo, "O halo aparece também no ar, sem depender das imagens que recebem a luz. Use intensidade baixa; a camada controla sobre quais peças ele aparece. A comparação global também desliga o halo.")
	var mesa: VBoxContainer = _paginas_luz["Luz da mesa"]
	_campo_luz(mesa, "mesa", "ativa", "Aplicar iluminação principal da mesa", "opcao")
	var legendas := {"ambiente": "Claridade ambiente (%)", "intensidade": "Intensidade do foco (%)",
		"minimo_cartas": "Claridade mínima das cartas (%)", "abrangencia": "Abrangência do foco (%)",
		"temperatura": "Aquecimento da luz (%)", "x": "Centro horizontal na mesa (%)", "y": "Centro em profundidade (%)"}
	for chave in CARTAS.LIMITES_LUZ_MESA:
		_campo_luz(mesa, "mesa", chave, legendas[chave], "numero", CARTAS.LIMITES_LUZ_MESA[chave])
	_botao(mesa, "Usar iluminação do preset das cartas", func():
		_registrar()
		_cartas["luz_mesa"] = CARTAS.validar_luz(_cartas["perfil"].get("iluminacao", {}))
		_atualizar_cena()
		_sincronizar_luz())
	_botao(mesa, "Restaurar luz da mesa", func():
		_registrar()
		_cartas["luz_mesa"] = CARTAS.luz_padrao()
		_atualizar_cena()
		_sincronizar_luz())
	_texto(mesa, "O mesmo foco ilumina as cartas e as imagens marcadas para receber a luz da mesa. Mesa e ornamento recebem por padrão. Os pontos de luz continuam independentes; 0% de claridade mínima permite escurecer totalmente as cartas.")


func _dados_luz(grupo: String) -> Dictionary:
	match grupo:
		"geral": return _luz
		"mesa": return _cartas["luz_mesa"]
		"peca": return _pecas[_selecionada]["aparencia"] if _selecionada >= 0 else {}
		"fonte": return _luz["fontes"][_fonte_selecionada] if _fonte_selecionada >= 0 else {}
		"halo":
			var f := _dados_luz("fonte")
			return f if not f.is_empty() and not bool(f["sombra"]) and not bool(f["brilho"]) else {}
		"brilho":
			var f := _dados_luz("fonte")
			return f if not f.is_empty() and bool(f["brilho"]) else {}
	return {}


func _campo_luz(pai: Node, grupo: String, chave: String, legenda: String,
		tipo: String, limites: Vector2 = Vector2.ZERO) -> void:
	var campo: Control
	match tipo:
		"opcao":
			var check := CheckBox.new()
			check.text = legenda
			pai.add_child(check)
			check.toggled.connect(_alterar_luz.bind(grupo, chave))
			campo = check
		"texto":
			_texto(pai, legenda)
			var entrada := LineEdit.new()
			pai.add_child(entrada)
			entrada.text_submitted.connect(_alterar_luz.bind(grupo, chave))
			entrada.focus_exited.connect(func(): _alterar_luz(entrada.text, grupo, chave))
			campo = entrada
		"cor":
			_texto(pai, legenda)
			var seletor := ColorPickerButton.new()
			seletor.edit_alpha = false
			pai.add_child(seletor)
			seletor.color_changed.connect(func(cor: Color): _alterar_luz([cor.r, cor.g, cor.b], grupo, chave))
			campo = seletor
		"numero":
			_texto(pai, legenda)
			var linha := HBoxContainer.new()
			pai.add_child(linha)
			var slider := HSlider.new()
			slider.min_value = limites.x
			slider.max_value = limites.y
			slider.step = 1
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			linha.add_child(slider)
			var spin := SpinBox.new()
			spin.min_value = limites.x
			spin.max_value = limites.y
			spin.step = 1
			spin.custom_minimum_size.x = 100
			linha.add_child(spin)
			slider.share(spin)
			slider.drag_started.connect(func():
				_registrar()
				_ajuste_continuo = true)
			slider.drag_ended.connect(func(_mudou: bool): _ajuste_continuo = false)
			spin.value_changed.connect(_alterar_luz.bind(grupo, chave))
			campo = spin
	_campos_luz.append({"campo": campo, "grupo": grupo, "chave": chave})


func _alterar_luz(valor: Variant, grupo: String, chave: String) -> void:
	if _atualizando_ui:
		return
	var dados := _dados_luz(grupo)
	if dados.is_empty() or dados[chave] == valor:
		return
	if chave == "nome":
		valor = str(valor).strip_edges().left(100)
		if str(valor).is_empty():
			return
	_registrar()
	dados[chave] = valor
	_atualizar_cena()
	if chave in ["todas", "nome"]:
		_sincronizar_luz()


func _sincronizar_luz() -> void:
	_atualizando_ui = true
	_contagem_fontes.text = "%d / %d fontes (luzes, sombras e brilhos)" % [_luz["fontes"].size(), LUZ.MAXIMO]
	if _fonte_selecionada >= _luz["fontes"].size():
		_fonte_selecionada = _luz["fontes"].size() - 1
	_lista_fontes.clear()
	_lista_halos.clear()
	for f in _luz["fontes"]:
		var prefixo := "Sombra · " if bool(f["sombra"]) else ("Brilho · " if bool(f["brilho"]) else "Luz · ")
		_lista_fontes.add_item(prefixo + str(f["nome"]))
		_lista_halos.add_item(prefixo + str(f["nome"]))
	_lista_fontes.disabled = _luz["fontes"].is_empty()
	_lista_halos.disabled = _lista_fontes.disabled
	_lista_fontes.select(_fonte_selecionada)
	_lista_halos.select(_fonte_selecionada)
	_bloco_brilho.visible = not _dados_luz("brilho").is_empty()
	for item in _campos_luz:
		var campo: Control = item["campo"]
		var dados := _dados_luz(item["grupo"])
		var ativo := not dados.is_empty()
		var chave: String = item["chave"]
		if campo is SpinBox:
			var spin := campo as SpinBox
			spin.editable = ativo
			if ativo:
				spin.set_value_no_signal(float(dados[chave]))
		elif campo is CheckBox:
			var check := campo as CheckBox
			check.disabled = not ativo
			check.set_pressed_no_signal(bool(dados[chave]) if ativo else false)
		elif campo is LineEdit:
			var entrada := campo as LineEdit
			entrada.editable = ativo
			entrada.text = str(dados[chave]) if ativo else ""
		elif campo is ColorPickerButton:
			var seletor := campo as ColorPickerButton
			seletor.disabled = not ativo
			if ativo:
				var cor: Array = dados[chave]
				seletor.color = Color(float(cor[0]), float(cor[1]), float(cor[2]))
	for filho in _alvos_fontes.get_children():
		_alvos_fontes.remove_child(filho)
		filho.queue_free()
	var fonte := _dados_luz("fonte")
	for peca in _pecas:
		var check := CheckBox.new()
		check.text = str(peca["nome"])
		check.disabled = fonte.is_empty() or bool(fonte.get("todas", true))
		check.set_pressed_no_signal(not fonte.is_empty() and (bool(fonte["todas"]) or fonte["alvos"].has(int(peca["id"]))))
		_alvos_fontes.add_child(check)
		check.toggled.connect(_alternar_alvo.bind(int(peca["id"])))
	_atualizando_ui = false


func _alternar_alvo(ativa: bool, id: int) -> void:
	var fonte := _dados_luz("fonte")
	if _atualizando_ui or fonte.is_empty():
		return
	_registrar()
	if ativa:
		if not fonte["alvos"].has(id): fonte["alvos"].append(id)
	else:
		fonte["alvos"].erase(id)
	_atualizar_cena()


func _adicionar_fonte(sombra: bool, brilho: bool = false) -> void:
	if _luz["fontes"].size() >= LUZ.MAXIMO:
		_mensagem.text = "Limite de %d luzes/sombras/brilhos por composição." % LUZ.MAXIMO
		return
	_registrar()
	var f := LUZ.brilho() if brilho else LUZ.fonte(sombra)
	if _selecionada >= 0:
		f["x"] = _pecas[_selecionada]["x"]
		f["y"] = _pecas[_selecionada]["y"]
		if brilho:
			f["alvos"].append(int(_pecas[_selecionada]["id"]))
	_luz["fontes"].append(f)
	_fonte_selecionada = _luz["fontes"].size() - 1
	_atualizar_cena()
	_sincronizar_luz()


func _duplicar_fonte(so_halo: bool = false) -> void:
	var original := _dados_luz("halo" if so_halo else "fonte")
	if original.is_empty():
		_mensagem.text = "Selecione um ponto de luz para copiar o halo." if so_halo else "Selecione uma fonte para duplicar."
		return
	if _luz["fontes"].size() >= LUZ.MAXIMO:
		_mensagem.text = "Limite de %d luzes/sombras/brilhos por composição." % LUZ.MAXIMO
		return
	_registrar()
	var copia := original.duplicate(true)
	var sufixo := " · halo copiado" if so_halo else " · cópia"
	copia["nome"] = str(original["nome"]).left(100 - sufixo.length()) + sufixo
	if so_halo:
		copia["intensidade"] = 0.0
	_luz["fontes"].append(copia)
	_fonte_selecionada = _luz["fontes"].size() - 1
	_atualizar_cena()
	_sincronizar_luz()
	_mensagem.text = "Cópia criada na mesma posição. Ajuste a posição ou arraste o centro para separar."


func _remover_fonte() -> void:
	if _fonte_selecionada < 0:
		return
	_registrar()
	_luz["fontes"].remove_at(_fonte_selecionada)
	_fonte_selecionada = mini(_fonte_selecionada, _luz["fontes"].size() - 1)
	_atualizar_cena()
	_sincronizar_luz()


func _texto(pai: Node, texto: String, tamanho: int = 14) -> Label:
	var label := Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", tamanho)
	pai.add_child(label)
	return label


func _botao(pai: Node, texto: String, acao: Callable) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pai.add_child(botao)
	botao.pressed.connect(acao)


func _numero(pai: Node, chave: String, texto: String, limites: Vector2, passo: float) -> void:
	_texto(pai, texto)
	var linha := HBoxContainer.new()
	pai.add_child(linha)
	var slider := HSlider.new()
	slider.min_value = limites.x
	slider.max_value = limites.y
	slider.step = passo
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = limites.x
	spin.max_value = limites.y
	spin.step = passo
	spin.custom_minimum_size.x = 100
	linha.add_child(spin)
	slider.share(spin)
	_campos[chave] = spin
	slider.drag_started.connect(func():
		if _selecionada >= 0:
			_registrar()
			_ajuste_continuo = true)
	slider.drag_ended.connect(func(_mudou: bool): _ajuste_continuo = false)
	spin.value_changed.connect(_alterar_numero.bind(chave))


func _opcao(pai: Node, chave: String, texto: String) -> void:
	var check := CheckBox.new()
	check.text = texto
	pai.add_child(check)
	_campos[chave] = check
	check.toggled.connect(func(valor: bool):
		if _atualizando_ui or _selecionada < 0:
			return
		_registrar()
		_pecas[_selecionada][chave] = valor
		_atualizar_cena()
		_sincronizar_ui())


func _categoria(titulo: String) -> void:
	_categoria_ativa = titulo
	for nome in _categorias:
		_categorias[nome].visible = nome == titulo
		_botoes[nome].set_pressed_no_signal(nome == titulo)
	_rolagem.scroll_vertical = 0
	if is_instance_valid(_guias):
		_guias.queue_redraw()


func _sincronizar_ui() -> void:
	_atualizando_ui = true
	_seletor.clear()
	for peca in _pecas:
		var prefixo := "" if bool(peca["visivel"]) else "[oculta] "
		_seletor.add_item(prefixo + str(peca["nome"]))
	if _selecionada >= _pecas.size():
		_selecionada = -1
	_seletor.disabled = _pecas.is_empty()
	if _selecionada >= 0:
		_seletor.select(_selecionada)
	else:
		_seletor.select(-1)
	_nome.editable = _selecionada >= 0
	_nome.text = str(_pecas[_selecionada]["nome"]) if _selecionada >= 0 else ""
	for chave in _campos:
		var campo: Control = _campos[chave]
		if campo is CheckBox:
			var check := campo as CheckBox
			check.disabled = _selecionada < 0
			check.set_pressed_no_signal(bool(_pecas[_selecionada][chave]) if _selecionada >= 0 else false)
		else:
			var spin := campo as SpinBox
			spin.editable = _selecionada >= 0
			if _selecionada >= 0:
				spin.set_value_no_signal(_valor_campo(chave))
	_atualizando_ui = false
	_sincronizar_cartas()
	_sincronizar_luz()


func _valor_campo(chave: String) -> float:
	var peca: Dictionary = _pecas[_selecionada]
	if chave.begins_with("canto_"):
		var partes := chave.split("_")
		return float(peca["cantos"][int(partes[1])][0 if partes[2] == "x" else 1]) * 100.0
	if chave.begins_with("recorte_"):
		return float(peca["recorte"][int(chave.get_slice("_", 1))])
	return float(peca[chave])


func _alterar_numero(valor: float, chave: String) -> void:
	if _atualizando_ui or _selecionada < 0:
		return
	var peca: Dictionary = _pecas[_selecionada]
	if is_equal_approx(valor, _valor_campo(chave)):
		return
	var cantos: Array = peca["cantos"].duplicate(true)
	if chave.begins_with("canto_"):
		var partes := chave.split("_")
		cantos[int(partes[1])][0 if partes[2] == "x" else 1] = valor / 100.0
		if not CATALOGO.cantos_validos(cantos):
			_mensagem.text = "Esse ajuste cruza os cantos. Reduza o deslocamento."
			_sincronizar_ui()
			return
	_registrar()
	if chave.begins_with("canto_"):
		peca["cantos"] = cantos
	elif chave.begins_with("recorte_"):
		peca["recorte"][int(chave.get_slice("_", 1))] = valor
	else:
		if bool(peca["proporcional"]) and chave in ["largura", "altura"]:
			var outra := "altura" if chave == "largura" else "largura"
			peca[outra] = clampf(float(peca[outra]) * valor / float(peca[chave]), 5, 4000)
		peca[chave] = valor
	_atualizar_cena()
	_sincronizar_ui()


func _atualizar_cena() -> void:
	var presentes: Array[int] = []
	for peca in _pecas:
		var id := int(peca["id"])
		presentes.append(id)
		if not _nos.has(id):
			var novo := ASSET.new()
			_composicao.add_child(novo)
			_nos[id] = novo
		var asset: ASSET = _nos[id]
		asset.aplicar(peca)
		# A ordem da lista desempata peças na mesma camada, inclusive após desfazer.
		_composicao.move_child(asset, -1)
	for id in _nos.keys():
		if not presentes.has(int(id)):
			_nos[id].queue_free()
			_nos.erase(id)
	if is_instance_valid(_referencia_cartas):
		_referencia_cartas.atualizar(_cartas, _luz)
		for peca in _pecas:
			var asset: ASSET = _nos[int(peca["id"])]
			asset.aplicar_luz(_luz, _referencia_cartas)
	if is_instance_valid(_halos):
		_halos.atualizar(_luz)
	if is_instance_valid(_guias):
		_guias.queue_redraw()


func _adicionar() -> void:
	_registrar()
	var peca := CATALOGO.criar(_catalogo.selected, _proximo_id)
	_proximo_id += 1
	_pecas.append(peca)
	_selecionada = _pecas.size() - 1
	_atualizar_cena()
	_sincronizar_ui()
	_categoria("Encaixe")


func _duplicar() -> void:
	if _selecionada < 0:
		return
	_registrar()
	var peca: Dictionary = _pecas[_selecionada].duplicate(true)
	peca["id"] = _proximo_id
	_proximo_id += 1
	peca["nome"] = str(peca["nome"]) + " (cópia)"
	peca["x"] = float(peca["x"]) + 25
	peca["y"] = float(peca["y"]) + 25
	peca["travada"] = false
	for f in _luz["fontes"]:
		if f["alvos"].has(int(_pecas[_selecionada]["id"])):
			f["alvos"].append(int(peca["id"]))
	_pecas.append(peca)
	_selecionada = _pecas.size() - 1
	_atualizar_cena()
	_sincronizar_ui()


func _remover() -> void:
	if _selecionada < 0:
		return
	_registrar()
	var id := int(_pecas[_selecionada]["id"])
	for f in _luz["fontes"]:
		f["alvos"].erase(id)
	_pecas.remove_at(_selecionada)
	_selecionada = mini(_selecionada, _pecas.size() - 1)
	_atualizar_cena()
	_sincronizar_ui()


func _renomear(nome: String) -> void:
	if _atualizando_ui or _selecionada < 0 or nome.strip_edges().is_empty():
		return
	if str(_pecas[_selecionada]["nome"]) == nome.strip_edges():
		return
	_registrar()
	_pecas[_selecionada]["nome"] = nome.strip_edges().left(100)
	_sincronizar_ui()


func _alternar_mesa() -> void:
	var mostrar := true
	for peca in _pecas:
		if peca["arquivo"] == "mesa.png":
			mostrar = not bool(peca["visivel"])
			break
	_registrar()
	for peca in _pecas:
		if peca["arquivo"] in ["mesa.png", "deco_mesa.png"]:
			peca["visivel"] = mostrar
	_atualizar_cena()
	_sincronizar_ui()


func _restaurar_proporcao() -> void:
	if _selecionada < 0:
		return
	_registrar()
	var peca: Dictionary = _pecas[_selecionada]
	peca["altura"] = clampf(float(peca["largura"]) * float(peca["recorte"][3]) / float(peca["recorte"][2]), 5, 4000)
	_atualizar_cena()
	_sincronizar_ui()


func _restaurar_cantos() -> void:
	if _selecionada < 0:
		return
	_registrar()
	_pecas[_selecionada]["cantos"] = [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]
	_atualizar_cena()
	_sincronizar_ui()


func _recorte_completo() -> void:
	if _selecionada < 0:
		return
	_registrar()
	var asset: ASSET = _nos[int(_pecas[_selecionada]["id"])]
	var textura: Texture2D = load(CATALOGO.PASTA + str(asset.perfil["arquivo"]))
	var tamanho := textura.get_size()
	_pecas[_selecionada]["recorte"] = [0.0, 0.0, tamanho.x, tamanho.y]
	_atualizar_cena()
	_sincronizar_ui()


func _ajustar_enquadramento() -> void:
	_area_ui.size = size
	var inicio := LARGURA_PAINEL if _painel.visible else 0.0
	var disponivel := Vector2(maxf(100, size.x - inicio), size.y)
	var fator := minf(disponivel.x / REFERENCIA.x, disponivel.y / REFERENCIA.y) * _zoom / 100.0
	_composicao.scale = Vector2.ONE * fator
	_composicao.position = Vector2(inicio, 0) + disponivel * 0.5 - REFERENCIA * fator * 0.5 + _pan * fator
	_guias.queue_redraw()


func _alternar_painel() -> void:
	_painel.visible = not _painel.visible
	_ajustar_enquadramento()


func _restaurar_vista() -> void:
	_zoom = 100
	_pan = Vector2.ZERO
	_ajustar_enquadramento()


func _desenhar_guias() -> void:
	if not _painel.visible:
		return
	var escala := maxf(_composicao.scale.x, 0.01)
	if _mostrar_moldura:
		_guias.draw_rect(Rect2(Vector2.ZERO, REFERENCIA), Color(0.65, 0.72, 0.7, 0.6), false, 1 / escala)
	if _categoria_ativa == "Luz" and _pagina_luz == "Halo da luz":
		var f := _dados_luz("halo")
		if _mostrar_fontes and not f.is_empty() and bool(f["visivel"]) and bool(f["halo_ativo"]):
			var centro := Vector2(float(f["x"]) + float(f["halo_x"]), float(f["y"]) + float(f["halo_y"]))
			_desenhar_area_luz(centro, Vector2(float(f["halo_largura"]), float(f["halo_altura"])),
				float(f["halo_giro"]), Color(1, 0.5, 0.7), escala)
		return
	if _categoria_ativa == "Luz" and _pagina_luz == "Pontos e sombras":
		if _mostrar_fontes:
			for indice in range(_luz["fontes"].size()):
				var f: Dictionary = _luz["fontes"][indice]
				if not bool(f["visivel"]):
					continue
				var cor := Color(0.6, 0.7, 1.0) if bool(f["sombra"]) else (Color(1, 1, 0.65) if bool(f["brilho"]) else Color(1, 0.75, 0.3))
				var centro := Vector2(float(f["x"]), float(f["y"]))
				if indice == _fonte_selecionada:
					_desenhar_area_luz(centro, Vector2(float(f["largura"]), float(f["altura"])), float(f["giro"]), cor, escala)
				else:
					_guias.draw_circle(centro, 6 / escala, cor)
		return
	if _categoria_ativa == "Cartas":
		if _referencia_cartas.visible:
			var tamanho := float(_cartas["tamanho"]) / 100.0
			var origem := REFERENCIA * 0.5 * (1.0 - tamanho) + Vector2(float(_cartas["x"]), float(_cartas["y"]))
			_guias.draw_rect(Rect2(origem, REFERENCIA * tamanho), Color(1, 0.8, 0.35), false, 1.5 / escala)
		return
	if _selecionada < 0 or not bool(_pecas[_selecionada]["visivel"]):
		return
	var asset: ASSET = _nos.get(int(_pecas[_selecionada]["id"]))
	if asset == null:
		return
	var pontos: PackedVector2Array = asset.pontos_na_cena()
	var contorno := pontos.duplicate()
	contorno.append(pontos[0])
	_guias.draw_polyline(contorno, Color(0.4, 0.95, 0.75), 1.5 / escala, true)
	if _editar_cantos and not bool(_pecas[_selecionada]["travada"]):
		for ponto in pontos:
			_guias.draw_circle(ponto, 6 / escala, Color(0.4, 0.95, 0.75))


func _desenhar_area_luz(centro: Vector2, dimensoes: Vector2, giro: float, cor: Color, escala: float) -> void:
	_guias.draw_circle(centro, 6 / escala, cor)
	var pontos := PackedVector2Array()
	for i in range(65):
		var angulo := TAU * i / 64.0
		var local := Vector2(cos(angulo), sin(angulo)) * dimensoes / 2.0
		pontos.append(centro + local.rotated(deg_to_rad(giro)))
	_guias.draw_polyline(pontos, cor, 1.5 / escala, true)


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_TAB:
		_arrasto = ""
		_alternar_painel()
		get_viewport().set_input_as_handled()
		return
	# Termina o arrasto mesmo quando o mouse cruza o painel ou sai da área da cena.
	if _arrasto.is_empty():
		return
	if evento is InputEventMouseButton and not evento.pressed:
		if evento.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_arrasto = ""
			_sincronizar_ui()
			get_viewport().set_input_as_handled()
	elif evento is InputEventMouseMotion:
		_arrastar(evento.position)
		get_viewport().set_input_as_handled()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.ctrl_pressed and evento.keycode == KEY_Z:
			if evento.shift_pressed:
				_refazer_acao()
			else:
				_desfazer()
		else:
			return
		get_viewport().set_input_as_handled()
	if not evento is InputEventMouseButton or not evento.pressed:
		return
	if _painel.visible and evento.position.x < LARGURA_PAINEL:
		return
	var ponto: Vector2 = _composicao.get_global_transform().affine_inverse() * evento.position
	if evento.button_index == MOUSE_BUTTON_MIDDLE:
		_arrasto = "vista"
		_inicio_mouse = evento.position
		_inicio_posicao = _pan
	elif evento.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom = clampf(_zoom * (1.1 if evento.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.1), 20, 400)
		_ajustar_enquadramento()
		# Conserva sob o mouse o ponto escolhido antes do zoom.
		_pan += (_composicao.get_global_transform().affine_inverse() * evento.position - ponto)
		_ajustar_enquadramento()
	elif evento.button_index == MOUSE_BUTTON_LEFT:
		_iniciar_arrasto(ponto)
	else:
		return
	get_viewport().set_input_as_handled()


func _iniciar_arrasto(ponto: Vector2) -> void:
	if _categoria_ativa == "Luz" and _pagina_luz == "Halo da luz":
		var f := _dados_luz("halo")
		if _mostrar_fontes and not f.is_empty() and bool(f["visivel"]) and bool(f["halo_ativo"]):
			var deslocamento := Vector2(float(f["halo_x"]), float(f["halo_y"]))
			var centro := Vector2(float(f["x"]), float(f["y"])) + deslocamento
			if ponto.distance_to(centro) * _composicao.scale.x < 14:
				_registrar()
				_inicio_mouse = ponto
				_inicio_posicao = deslocamento
				_arrasto = "halo"
		return
	if _categoria_ativa == "Luz" and _pagina_luz == "Pontos e sombras":
		if not _mostrar_fontes:
			return
		var melhor := -1
		var distancia := 14.0 / maxf(_composicao.scale.x, 0.01)
		for i in range(_luz["fontes"].size()):
			var f: Dictionary = _luz["fontes"][i]
			var d := ponto.distance_to(Vector2(float(f["x"]), float(f["y"])))
			if bool(f["visivel"]) and d < distancia:
				melhor = i
				distancia = d
		if melhor >= 0:
			_fonte_selecionada = melhor
			_registrar()
			_inicio_mouse = ponto
			var f: Dictionary = _luz["fontes"][melhor]
			_inicio_posicao = Vector2(float(f["x"]), float(f["y"]))
			_arrasto = "fonte"
			_sincronizar_luz()
			_guias.queue_redraw()
		return
	if _categoria_ativa == "Cartas":
		if _referencia_cartas.visible:
			_registrar()
			_inicio_mouse = ponto
			_inicio_posicao = Vector2(float(_cartas["x"]), float(_cartas["y"]))
			_arrasto = "cartas"
			_guias.queue_redraw()
		return
	_canto = -1
	if _editar_cantos and _selecionada >= 0 and not bool(_pecas[_selecionada]["travada"]):
		var asset: ASSET = _nos[int(_pecas[_selecionada]["id"])]
		var pontos: PackedVector2Array = asset.pontos_na_cena()
		for i in range(4):
			if pontos[i].distance_to(ponto) * _composicao.scale.x < 12:
				_canto = i
				break
	if _canto < 0:
		var melhor := -1
		for i in range(_pecas.size()):
			var peca: Dictionary = _pecas[i]
			if not bool(peca["visivel"]) or bool(peca["travada"]):
				continue
			var asset: ASSET = _nos[int(peca["id"])]
			if asset.contem(ponto) and (melhor < 0 or float(peca["camada"]) >= float(_pecas[melhor]["camada"])):
				melhor = i
		_selecionada = melhor
		_sincronizar_ui()
		_guias.queue_redraw()
	if _selecionada < 0:
		return
	_registrar()
	_inicio_mouse = ponto
	_inicio_posicao = Vector2(float(_pecas[_selecionada]["x"]), float(_pecas[_selecionada]["y"]))
	_arrasto = "canto" if _canto >= 0 else "peca"


func _arrastar(mouse: Vector2) -> void:
	if _arrasto == "vista":
		_pan = _inicio_posicao + (mouse - _inicio_mouse) / _composicao.scale.x
		_ajustar_enquadramento()
		return
	if _arrasto == "halo":
		var ponto_halo: Vector2 = _composicao.get_global_transform().affine_inverse() * mouse
		var posicao_halo := _inicio_posicao + ponto_halo - _inicio_mouse
		var f: Dictionary = _luz["fontes"][_fonte_selecionada]
		f["halo_x"] = clampf(posicao_halo.x, LUZ.LIMITES_HALO["halo_x"].x, LUZ.LIMITES_HALO["halo_x"].y)
		f["halo_y"] = clampf(posicao_halo.y, LUZ.LIMITES_HALO["halo_y"].x, LUZ.LIMITES_HALO["halo_y"].y)
		_atualizar_cena()
		return
	if _arrasto == "fonte":
		var ponto_fonte: Vector2 = _composicao.get_global_transform().affine_inverse() * mouse
		var posicao_fonte := _inicio_posicao + ponto_fonte - _inicio_mouse
		var f: Dictionary = _luz["fontes"][_fonte_selecionada]
		f["x"] = clampf(posicao_fonte.x, LUZ.LIMITES["x"].x, LUZ.LIMITES["x"].y)
		f["y"] = clampf(posicao_fonte.y, LUZ.LIMITES["y"].x, LUZ.LIMITES["y"].y)
		_atualizar_cena()
		return
	if _arrasto == "cartas":
		var ponto_cartas: Vector2 = _composicao.get_global_transform().affine_inverse() * mouse
		var posicao_cartas := _inicio_posicao + ponto_cartas - _inicio_mouse
		_cartas["x"] = clampf(posicao_cartas.x, -1280, 1280)
		_cartas["y"] = clampf(posicao_cartas.y, -720, 720)
		_atualizar_cena()
		return
	if _selecionada < 0:
		return
	var ponto: Vector2 = _composicao.get_global_transform().affine_inverse() * mouse
	var peca: Dictionary = _pecas[_selecionada]
	if _arrasto == "canto":
		var asset: ASSET = _nos[int(peca["id"])]
		var canto: Vector2 = asset.canto_normalizado(ponto).clamp(Vector2(-1, -1), Vector2(2, 2))
		var cantos: Array = peca["cantos"].duplicate(true)
		cantos[_canto] = [canto.x, canto.y]
		if CATALOGO.cantos_validos(cantos):
			peca["cantos"] = cantos
	else:
		var posicao := _inicio_posicao + ponto - _inicio_mouse
		peca["x"] = clampf(posicao.x, -2560, 3840)
		peca["y"] = clampf(posicao.y, -1440, 2160)
	_atualizar_cena()


func _estado() -> Dictionary:
	return {"pecas": _pecas.duplicate(true), "zoom": _zoom, "pan": [_pan.x, _pan.y],
		"cartas": _cartas.duplicate(true), "luz": _luz.duplicate(true)}


func _aplicar_estado(dados: Dictionary) -> void:
	if not dados.get("pecas") is Array:
		return
	_cartas = CARTAS.validar(dados.get("cartas"))
	_luz = LUZ.validar(dados.get("luz"))
	var novas: Array[Dictionary] = []
	var id := 1
	var usados: Dictionary = {}
	for entrada in dados["pecas"]:
		var peca: Dictionary = CATALOGO.validar(entrada)
		if peca.is_empty():
			continue
		# Preserva os IDs: as luzes guardam os receptores por peça, não pela posição na lista.
		var identificador := int(peca["id"])
		if identificador < 1 or usados.has(identificador):
			while usados.has(id):
				id += 1
			identificador = id
		peca["id"] = identificador
		usados[identificador] = true
		id = maxi(id, identificador + 1)
		novas.append(peca)
	_pecas = novas
	_proximo_id = id
	_selecionada = -1
	var zoom: Variant = dados.get("zoom", 100)
	_zoom = clampf(float(zoom), 20, 400) if (zoom is float or zoom is int) and is_finite(float(zoom)) else 100.0
	_pan = Vector2.ZERO
	var pan: Variant = dados.get("pan")
	if pan is Array and pan.size() == 2:
		if (pan[0] is float or pan[0] is int) and (pan[1] is float or pan[1] is int):
			if is_finite(float(pan[0])) and is_finite(float(pan[1])):
				_pan = Vector2(float(pan[0]), float(pan[1])).clamp(Vector2(-5000, -5000), Vector2(5000, 5000))


func _registrar() -> void:
	if _ajuste_continuo:
		return
	_historico.append(_estado())
	if _historico.size() > 80:
		_historico.pop_front()
	_refazer.clear()


func _desfazer() -> void:
	if _historico.is_empty():
		return
	_refazer.append(_estado())
	_aplicar_estado(_historico.pop_back())
	_atualizar_cena()
	_sincronizar_ui()
	_ajustar_enquadramento()


func _refazer_acao() -> void:
	if _refazer.is_empty():
		return
	_historico.append(_estado())
	_aplicar_estado(_refazer.pop_back())
	_atualizar_cena()
	_sincronizar_ui()
	_ajustar_enquadramento()


func _ler_biblioteca() -> void:
	if not FileAccess.file_exists(ARQUIVO):
		return
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if dados is Dictionary and dados.get("conjuntos") is Dictionary:
		_biblioteca = dados
	else:
		_biblioteca_corrompida = true


func _gravar_biblioteca() -> bool:
	if _biblioteca_corrompida:
		_mensagem.text = "Arquivo salvo ilegível; gravação bloqueada para preservar seus dados."
		return false
	var arquivo := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if arquivo == null:
		_mensagem.text = "Não foi possível salvar: " + error_string(FileAccess.get_open_error())
		return false
	arquivo.store_string(JSON.stringify(_biblioteca, "\t"))
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		_mensagem.text = "Falha na gravação: " + error_string(erro)
		return false
	return true


func _salvar() -> void:
	var nome := _nome_conjunto.text.strip_edges()
	if nome.is_empty():
		_mensagem.text = "Dê um nome à composição antes de salvar."
		return
	if not _biblioteca.has("conjuntos"):
		_biblioteca["conjuntos"] = {}
	_biblioteca["conjuntos"][nome] = _estado()
	_biblioteca["ultima"] = _estado()
	if _gravar_biblioteca():
		_listar_conjuntos(nome)
		_mensagem.text = "Composição salva: " + nome


func _listar_conjuntos(selecionar: String = "") -> void:
	_lista_conjuntos.clear()
	var nomes: Array = _biblioteca.get("conjuntos", {}).keys()
	nomes.sort()
	for nome in nomes:
		_lista_conjuntos.add_item(str(nome))
		if nome == selecionar:
			_lista_conjuntos.select(_lista_conjuntos.item_count - 1)
	_lista_conjuntos.disabled = nomes.is_empty()


func _carregar() -> void:
	if _lista_conjuntos.selected < 0:
		return
	var nome := _lista_conjuntos.get_item_text(_lista_conjuntos.selected)
	var dados: Variant = _biblioteca.get("conjuntos", {}).get(nome)
	if not dados is Dictionary or not dados.get("pecas") is Array:
		_mensagem.text = "Essa composição não pôde ser lida."
		return
	_registrar()
	_aplicar_estado(dados)
	_atualizar_cena()
	_sincronizar_ui()
	_ajustar_enquadramento()
	_nome_conjunto.text = nome
	_biblioteca["ultima"] = _estado()
	if _gravar_biblioteca():
		_mensagem.text = "Composição carregada: " + nome


func _composicao_inicial() -> void:
	_registrar()
	_aplicar_estado({"pecas": CATALOGO.composicao_inicial()})
	_atualizar_cena()
	_sincronizar_ui()
	_restaurar_vista()


func _esvaziar() -> void:
	_registrar()
	_pecas.clear()
	_luz = LUZ.padrao()
	_fonte_selecionada = -1
	_selecionada = -1
	_atualizar_cena()
	_sincronizar_ui()
