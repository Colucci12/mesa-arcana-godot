extends RefCounted

const MENU = preload("res://scripts/main/componentes/tema_menu.gd")


static func painel(margem: float = 12.0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.018, 0.062, 0.066, 0.94)
	estilo.border_color = Color(0.72, 0.56, 0.30, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		estilo.set_content_margin(lado, margem)
	return estilo


static func tema() -> Theme:
	var resultado := MENU.tema()
	resultado.default_font_size = 20
	resultado.set_font_size("normal_font_size", "RichTextLabel", 19)
	resultado.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.85))
	resultado.set_constant("shadow_offset_x", "Label", 1)
	resultado.set_constant("shadow_offset_y", "Label", 2)
	resultado.set_type_variation("AcaoPartida", "Button")
	resultado.set_font_size("font_size", "AcaoPartida", 20)
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		var estilo := resultado.get_stylebox(estado, "Button").duplicate() as StyleBoxTexture
		estilo.content_margin_left = 32
		estilo.content_margin_right = 32
		estilo.content_margin_top = 8
		estilo.content_margin_bottom = 8
		resultado.set_stylebox(estado, "AcaoPartida", estilo)
	resultado.set_stylebox("panel", "PanelContainer", painel())
	return resultado


static func aplicar_mesa(mesa: Control) -> void:
	var visual := tema()
	for nome in ["IndicadorTurno", "Mensagem", "NomeJogador", "QuantidadeJogador",
		"NomeOponente", "QuantidadeOponente", "NomeEsquerda", "QuantidadeEsquerda",
		"NomeDireita", "QuantidadeDireita", "ComprarCarta", "PassarVez",
		"EscolhaCor", "EscolhaAlvo", "EditarEnquadramento"]:
		var controle := mesa.get_node(nome) as Control
		controle.theme = visual
		controle.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for nome in ["ComprarCarta", "PassarVez"]:
		var botao := mesa.get_node(nome) as Button
		botao.theme_type_variation = &"AcaoPartida"
	mesa.get_node("EditarEnquadramento").theme_type_variation = &"AbaMenu"
	for sufixo in ["Jogador", "Oponente", "Esquerda", "Direita"]:
		var nome := mesa.get_node("Nome" + sufixo) as Label
		var quantidade := mesa.get_node("Quantidade" + sufixo) as Label
		nome.add_theme_font_size_override("font_size", 24)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		quantidade.add_theme_font_size_override("font_size", 18)
		quantidade.add_theme_color_override("font_color", MENU.SUAVE)
		quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fundo_rotulo(nome, 44)
		var ornamento := TextureRect.new()
		ornamento.texture = MENU.divisor()
		ornamento.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ornamento.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ornamento.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nome.add_child(ornamento)
		ornamento.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		ornamento.offset_left = 20
		ornamento.offset_right = -20
		ornamento.offset_top = 30
		ornamento.offset_bottom = 42
	var turno := mesa.get_node("IndicadorTurno") as Label
	turno.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fundo_rotulo(turno, 6)
	for direita in [false, true]:
		var emblema := TextureRect.new()
		emblema.texture = MENU.emblema()
		emblema.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblema.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblema.mouse_filter = Control.MOUSE_FILTER_IGNORE
		turno.add_child(emblema)
		emblema.anchor_left = 1.0 if direita else 0.0
		emblema.anchor_right = emblema.anchor_left
		emblema.offset_left = -4 if direita else -24
		emblema.offset_right = 24 if direita else 4
		emblema.offset_top = 4
		emblema.offset_bottom = 32
	var mensagem := mesa.get_node("Mensagem") as Label
	mensagem.add_theme_font_size_override("font_size", 19)
	mensagem.add_theme_color_override("font_color", MENU.CREME)
	var cores := {"Azul": Color("#92c9f3"), "Verde": Color("#9ce0b0"),
		"Amarelo": Color("#f5da81"), "Vermelho": Color("#f5aaa0")}
	for nome in cores:
		var botao := mesa.get_node("EscolhaCor/" + nome) as Button
		botao.theme_type_variation = &"AcaoPartida"
		botao.custom_minimum_size = Vector2(220, 44)
		for propriedade in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			botao.add_theme_color_override(propriedade, cores[nome])
	for nome in ["EscolhaCor", "EscolhaAlvo"]:
		var escolha := mesa.get_node(nome) as VBoxContainer
		escolha.custom_minimum_size.x = 220
		escolha.add_theme_constant_override("separation", 8)
		_moldura_escolha(mesa, escolha)


static func _fundo_rotulo(rotulo: Label, extensao_inferior: float) -> void:
	var fundo := Panel.new()
	fundo.z_index = -1
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_theme_stylebox_override("panel", painel(0))
	rotulo.add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.offset_left = -12
	fundo.offset_right = 12
	fundo.offset_top = -8
	fundo.offset_bottom = extensao_inferior


static func _moldura_escolha(mesa: Control, escolha: Control) -> void:
	var fundo := Panel.new()
	fundo.z_index = 199
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_theme_stylebox_override("panel", painel(0))
	mesa.add_child(fundo)
	var sincronizar := func() -> void:
		fundo.visible = escolha.visible
		fundo.position = escolha.position - Vector2(14, 14)
		fundo.size = escolha.size + Vector2(28, 28)
	escolha.visibility_changed.connect(sincronizar)
	escolha.item_rect_changed.connect(sincronizar)
	sincronizar.call()


static func aplicar_chat(chat: Control) -> void:
	chat.theme = tema()
	chat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for caminho in ["Abrir", "Conteudo/Itens/Compor/Enviar"]:
		var botao := chat.get_node(caminho) as Button
		botao.theme_type_variation = &"AbaMenu"
		botao.add_theme_font_size_override("font_size", 18)
	chat.get_node("Conteudo").add_theme_stylebox_override("panel", painel())
