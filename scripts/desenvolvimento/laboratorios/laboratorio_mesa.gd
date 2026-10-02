extends Control

const REFERENCIA := Vector2(1280, 720)
const ARQUIVO_TESTES = "user://laboratorio_mesa.json"
const PADRAO = {
	"posicao_x": 50.0, "posicao_y": 55.0,
	"largura": 1000.0, "profundidade": 420.0, "largura_distante": 56.0,
	"giro": 0.0, "moldura": 36.0, "espessura": 28.0
}

@onready var _area: Control = $Layout/AreaVisual
@onready var _composicao: Node2D = $Layout/AreaVisual/Composicao
@onready var _mesa: MesaVisual = $Layout/AreaVisual/Composicao/Mesa
@onready var _painel: PanelContainer = $Layout/Painel
@onready var _rolagem: ScrollContainer = $Layout/Painel/Margem/Rolagem
@onready var _conteudo: VBoxContainer = $Layout/Painel/Margem/Rolagem/Controles

var _ajustes: Dictionary = PADRAO.duplicate()
var _controles: Dictionary = {}
var _testes: Dictionary = {}
var _grade: CheckBox
var _cartas: CheckBox
var _nome: LineEdit
var _notas: TextEdit
var _lista: OptionButton
var _carregar: Button
var _mensagem: Label
var _arrastando := false
var _offset_arrasto := Vector2.ZERO
var _atualizando_painel := false


func _ready() -> void:
	_montar_painel()
	_ler_testes()
	_aplicar_ajustes()
	_area.resized.connect(_ajustar_enquadramento)
	_area.gui_input.connect(_entrada_area)
	_ajustar_enquadramento()


func _montar_painel() -> void:
	_titulo("Uma mesa, várias perspectivas", 20)
	_texto("Ajuste a forma, compare as referências e salve suas observações.")
	_botao("Ocultar painel · Tab", _alternar_painel)
	_titulo("Posição e tamanho")
	_ajuste("posicao_x", "Posição horizontal", -25, 125, 1, "%")
	_ajuste("posicao_y", "Posição vertical", -25, 125, 1, "%")
	_ajuste("largura", "Largura próxima", 200, 1600, 10)
	_ajuste("profundidade", "Profundidade na tela", 60, 900, 5)
	_titulo("Perspectiva")
	_ajuste("largura_distante", "Largura distante", 15, 100, 1, "%")
	_texto("100% deixa as bordas com a mesma largura. Reduzir estreita o lado distante; profundidade comprime o tampo na tela.")
	_ajuste("giro", "Girar o conjunto", -180, 180, 1, "°")
	_titulo("Moldura e espessura")
	_ajuste("moldura", "Largura da moldura", 0, 120, 1)
	_ajuste("espessura", "Espessura frontal", 0, 100, 1)
	_texto("A moldura acompanha a perspectiva do tampo. A faixa frontal mais escura sugere espessura.")
	_titulo("Referências de profundidade")
	_grade = CheckBox.new()
	_grade.text = "Mostrar grade"
	_conteudo.add_child(_grade)
	_grade.toggled.connect(_alternar_referencia)
	_cartas = CheckBox.new()
	_cartas.text = "Mostrar duas cartas apoiadas"
	_cartas.button_pressed = true
	_conteudo.add_child(_cartas)
	_cartas.toggled.connect(_alternar_referencia)
	_texto("A grade e as duas cartas têm tamanhos iguais no plano original. Tudo recebe a mesma projeção.")
	_titulo("Guardar comparação")
	_nome = LineEdit.new()
	_nome.placeholder_text = "Nome do teste"
	_nome.max_length = 80
	_conteudo.add_child(_nome)
	_notas = TextEdit.new()
	_notas.custom_minimum_size = Vector2(0, 100)
	_notas.placeholder_text = "O que funcionou? O que parece estranho?"
	_notas.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_conteudo.add_child(_notas)
	_botao("Salvar teste", _salvar_teste)
	_lista = OptionButton.new()
	_conteudo.add_child(_lista)
	_carregar = _botao("Carregar teste selecionado", _carregar_teste)
	_botao("Copiar valores e anotações", _copiar_valores)
	_botao("Restaurar ajustes iniciais", _restaurar_inicio)
	_mensagem = _texto("Arraste na área escura para posicionar a mesa. A roda apenas rola o painel.")


func _titulo(texto: String, tamanho: int = 18) -> void:
	var titulo := Label.new()
	titulo.text = texto
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.add_theme_font_size_override("font_size", tamanho)
	_conteudo.add_child(titulo)


func _texto(texto: String) -> Label:
	var legenda := Label.new()
	legenda.text = texto
	legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legenda.modulate = Color(0.7, 0.75, 0.8)
	_conteudo.add_child(legenda)
	return legenda


func _botao(texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.pressed.connect(acao)
	_conteudo.add_child(botao)
	return botao


func _ajuste(chave: String, texto: String, minimo: float, maximo: float, passo: float, unidade: String = "") -> void:
	var bloco := VBoxContainer.new()
	var linha := HBoxContainer.new()
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.add_theme_font_size_override("font_size", 13)
	linha.add_child(rotulo)
	var numero := SpinBox.new()
	numero.custom_minimum_size.x = 90
	numero.min_value = minimo
	numero.max_value = maximo
	numero.step = passo
	numero.suffix = unidade
	linha.add_child(numero)
	bloco.add_child(linha)
	var controle := HSlider.new()
	controle.min_value = minimo
	controle.max_value = maximo
	controle.step = passo
	controle.share(numero)
	controle.value = float(_ajustes[chave])
	bloco.add_child(controle)
	_conteudo.add_child(bloco)
	_controles[chave] = controle
	controle.value_changed.connect(_alterar_ajuste.bind(chave))


func _alterar_ajuste(valor: float, chave: String) -> void:
	if _atualizando_painel:
		return
	_ajustes[chave] = valor
	_aplicar_ajustes()


func _alternar_referencia(_ativada: bool) -> void:
	_aplicar_ajustes()


func _aplicar_ajustes() -> void:
	_mesa.position = REFERENCIA * Vector2(float(_ajustes["posicao_x"]), float(_ajustes["posicao_y"])) / 100.0
	_mesa.configurar_visual(_ajustes, _grade.button_pressed, _cartas.button_pressed)


func _ajustar_enquadramento() -> void:
	var fator := maxf(minf(_area.size.x / REFERENCIA.x, _area.size.y / REFERENCIA.y), 0.001)
	_composicao.scale = Vector2.ONE * fator
	_composicao.position = (_area.size - REFERENCIA * fator) / 2.0


func _entrada_area(evento: InputEvent) -> void:
	if not _painel.visible:
		return
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = evento.pressed
		_offset_arrasto = _composicao.get_local_mouse_position() - _mesa.position
	elif evento is InputEventMouseMotion and _arrastando:
		var destino := (_composicao.get_local_mouse_position() - _offset_arrasto) / REFERENCIA * 100.0
		(_controles["posicao_x"] as HSlider).value = destino.x
		(_controles["posicao_y"] as HSlider).value = destino.y
	_area.accept_event()


func _input(evento: InputEvent) -> void:
	# A roda é consumida antes de chegar ao Slider ou ao campo numérico.
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
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed:
		_arrastando = false


func _alternar_painel() -> void:
	var foco := get_viewport().gui_get_focus_owner()
	if foco != null:
		foco.release_focus()
	_painel.visible = not _painel.visible
	_arrastando = false


func _perfil_atual() -> Dictionary:
	return {"ajustes": _ajustes.duplicate(), "grade": _grade.button_pressed,
		"cartas": _cartas.button_pressed, "notas": _notas.text}


func _ler_testes() -> void:
	if FileAccess.file_exists(ARQUIVO_TESTES):
		var arquivo := FileAccess.open(ARQUIVO_TESTES, FileAccess.READ)
		if arquivo != null:
			var dados: Variant = JSON.parse_string(arquivo.get_as_text())
			if dados is Dictionary:
				for nome in dados:
					if dados[nome] is Dictionary and dados[nome].get("ajustes") is Dictionary:
						_testes[String(nome)] = dados[nome]
			else:
				_mensagem.text = "O arquivo de testes não pôde ser lido."
	_atualizar_lista()


func _atualizar_lista(selecionar: String = "") -> void:
	_lista.clear()
	var nomes := _testes.keys()
	nomes.sort()
	for nome in nomes:
		_lista.add_item(String(nome))
		if nome == selecionar:
			_lista.select(_lista.item_count - 1)
	_carregar.disabled = nomes.is_empty()
	if nomes.is_empty():
		_lista.add_item("Nenhum teste salvo")
		_lista.set_item_disabled(0, true)


func _salvar_teste() -> void:
	var nome := _nome.text.strip_edges()
	if nome.is_empty():
		_mensagem.text = "Dê um nome ao teste antes de salvar."
		return
	var arquivo := FileAccess.open(ARQUIVO_TESTES, FileAccess.WRITE)
	if arquivo == null:
		_mensagem.text = "Não foi possível salvar os testes."
		return
	_testes[nome] = _perfil_atual()
	arquivo.store_string(JSON.stringify(_testes, "\t"))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	_atualizar_lista(nome)
	_mensagem.text = "Salvo: " + nome if erro == OK else "Falha ao gravar. O teste está disponível apenas nesta sessão."


func _carregar_teste() -> void:
	if _testes.is_empty():
		return
	var nome := _lista.get_item_text(_lista.selected)
	var teste: Dictionary = _testes[nome]
	_nome.text = nome
	_notas.text = String(teste.get("notas", ""))
	_grade.set_pressed_no_signal(bool(teste.get("grade", false)))
	_cartas.set_pressed_no_signal(bool(teste.get("cartas", true)))
	_preencher_ajustes(teste["ajustes"])
	_mensagem.text = "Carregado: " + nome


func _preencher_ajustes(valores: Dictionary) -> void:
	_atualizando_painel = true
	for chave in PADRAO:
		var controle := _controles[chave] as HSlider
		var valor: Variant = valores.get(chave, PADRAO[chave])
		if not (valor is float or valor is int) or not is_finite(float(valor)):
			valor = PADRAO[chave]
		controle.value = clampf(float(valor), controle.min_value, controle.max_value)
		_ajustes[chave] = controle.value
	_atualizando_painel = false
	_aplicar_ajustes()


func _restaurar_inicio() -> void:
	_grade.set_pressed_no_signal(false)
	_cartas.set_pressed_no_signal(true)
	_preencher_ajustes(PADRAO)
	_mensagem.text = "Ajustes iniciais restaurados. Os testes salvos foram mantidos."


func _copiar_valores() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_perfil_atual(), "\t"))
	_mensagem.text = "Valores e anotações copiados."
