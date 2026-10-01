extends Control

const CENA_CARTA = preload("res://scenes/main/componentes/carta.tscn")
const ARQUIVO_TESTES = "user://laboratorio_mao.json"
const CORES = ["VERMELHO", "AZUL", "VERDE", "AMARELO"]
const PADRAO = {
	"posicao_x": 50.0, "posicao_y": 50.0,
	"tamanho": 1.25, "altura": 1.0, "giro": 0.0, "deformacao": 0.0,
	"largura": 560.0, "separacao": -20.0, "curvatura": -30.0, "abertura": 12.0,
	"inclinacao_x": 0.0, "inclinacao_y": 0.0, "variacao_tamanho": 0.0
}

@onready var _area: Control = $Layout/AreaVisual
@onready var _grupo: Node2D = $Layout/AreaVisual/Grupo
@onready var _mao: MaoVisual = $Layout/AreaVisual/Grupo/Leque
@onready var _painel: PanelContainer = $Layout/Painel
@onready var _rolagem: ScrollContainer = $Layout/Painel/Margem/Rolagem
@onready var _conteudo: VBoxContainer = $Layout/Painel/Margem/Rolagem/Controles

var _ajustes: Dictionary = PADRAO.duplicate()
var _controles: Dictionary = {}
var _testes: Dictionary = {}
var _cartas: Array[Carta] = []
var _dados_cartas: Array[Dictionary] = []
var _frentes: CheckBox
var _sombras: CheckBox
var _deformacao_progressiva: CheckBox
var _inclinacao_x_progressiva: CheckBox
var _inclinacao_y_progressiva: CheckBox
var _nome: LineEdit
var _notas: TextEdit
var _lista: OptionButton
var _mensagem: Label
var _salvar: Button
var _carregar: Button
var _restaurar: Button
var _arrastando: bool = false
var _posicao_arrasto := Vector2.ZERO
var _em_virada: bool = false
var _atualizando_painel: bool = false


func _ready() -> void:
	_montar_cartas()
	_montar_painel()
	_ler_testes()
	_aplicar_ajustes()
	_area.resized.connect(_reposicionar)
	_area.gui_input.connect(_entrada_area)


func _montar_cartas() -> void:
	_mao.custom_minimum_size = Vector2(180, 140)
	for indice in range(7):
		var carta := CENA_CARTA.instantiate() as Carta
		var dados := {"id": indice + 1, "cor": CORES[indice % CORES.size()], "valor": str(indice + 1)}
		_mao.add_child(carta)
		carta.setup_dados(dados)
		carta.definir_hover_habilitado(false)
		carta.definir_sombra_visivel(false)
		_cartas.append(carta)
		_dados_cartas.append(dados)


func _montar_painel() -> void:
	_titulo("Uma mão, vários pontos de vista", 20)
	_texto("Ajuste ao vivo. Salve cada combinação com um nome e suas observações.")
	_botao("Ocultar painel · Tab", _alternar_painel)
	_titulo("Posição e tamanho")
	_ajuste("posicao_x", "Posição horizontal", 0, 100, 1, "%")
	_ajuste("posicao_y", "Posição vertical", 0, 100, 1, "%")
	_ajuste("tamanho", "Tamanho do conjunto", 0.3, 2.5, 0.05)
	_ajuste("altura", "Altura das cartas", 0.3, 1.5, 0.05)
	_ajuste("giro", "Girar o leque", -180, 180, 1, "°")
	_ajuste("deformacao", "Deformar o conjunto", -25, 25, 1, "°")
	_deformacao_progressiva = CheckBox.new()
	_deformacao_progressiva.text = "Deformação gradual por carta"
	_conteudo.add_child(_deformacao_progressiva)
	_deformacao_progressiva.toggled.connect(_alternar_gradual)
	_texto("Gradual: pontas com sinais opostos e zero no centro. Um valor negativo inverte os lados. Desmarcado: deforma o conjunto inteiro.")
	_titulo("Forma do leque")
	_ajuste("largura", "Largura disponível", 180, 900, 5)
	_ajuste("separacao", "Separação das cartas", -60, 25, 1)
	_ajuste("curvatura", "Curvatura", -90, 90, 1)
	_ajuste("abertura", "Abertura das cartas", -35, 35, 1, "°")
	_ajuste("variacao_tamanho", "Variação entre as pontas", -0.5, 0.5, 0.05)
	_texto("A largura limita o espaço do leque. A variação deixa uma ponta maior que a outra.")
	_titulo("Perspectiva das faces")
	_ajuste("inclinacao_x", "Inclinar cima/baixo", -45, 45, 1, "°")
	_inclinacao_x_progressiva = CheckBox.new()
	_inclinacao_x_progressiva.text = "Inclinação cima/baixo gradual"
	_conteudo.add_child(_inclinacao_x_progressiva)
	_inclinacao_x_progressiva.toggled.connect(_alternar_gradual)
	_ajuste("inclinacao_y", "Inclinar esquerda/direita", -45, 45, 1, "°")
	_inclinacao_y_progressiva = CheckBox.new()
	_inclinacao_y_progressiva.text = "Inclinação esquerda/direita gradual"
	_conteudo.add_child(_inclinacao_y_progressiva)
	_inclinacao_y_progressiva.toggled.connect(_alternar_gradual)
	_texto("Esses dois controles usam o shader das cartas. O giro acima muda a orientação do leque na tela.")
	_texto("Cada eixo pode ser gradual: sinais opostos nas pontas e zero no centro. Um valor negativo inverte os lados.")
	_frentes = CheckBox.new()
	_frentes.text = "Mostrar frentes"
	_conteudo.add_child(_frentes)
	_frentes.toggled.connect(_mudar_faces)
	_sombras = CheckBox.new()
	_sombras.text = "Mostrar sombras das cartas"
	_conteudo.add_child(_sombras)
	_sombras.toggled.connect(_mudar_sombras)
	_titulo("Guardar comparação")
	_nome = LineEdit.new()
	_nome.placeholder_text = "Nome: lateral esquerda A"
	_nome.max_length = 80
	_conteudo.add_child(_nome)
	_notas = TextEdit.new()
	_notas.custom_minimum_size = Vector2(0, 100)
	_notas.placeholder_text = "O que funcionou? O que parece estranho?"
	_notas.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_conteudo.add_child(_notas)
	_salvar = _botao("Salvar teste", _salvar_teste)
	_lista = OptionButton.new()
	_conteudo.add_child(_lista)
	_carregar = _botao("Carregar teste selecionado", _carregar_teste)
	_botao("Copiar valores e anotações", _copiar_valores)
	_restaurar = _botao("Restaurar ajustes iniciais", _restaurar_inicio)
	_mensagem = _texto("Os testes salvos continuam disponíveis após fechar a cena.")


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
	legenda.add_theme_font_size_override("font_size", 13)
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


func _aplicar_ajustes() -> void:
	if _em_virada:
		return
	_reposicionar()
	var tamanho := float(_ajustes["tamanho"])
	_grupo.scale = Vector2(tamanho, tamanho * float(_ajustes["altura"]))
	_grupo.rotation_degrees = float(_ajustes["giro"])
	var deformacao := float(_ajustes["deformacao"])
	var progressiva := _deformacao_progressiva.button_pressed
	_grupo.skew = 0.0 if progressiva else deg_to_rad(deformacao)
	var largura := float(_ajustes["largura"])
	_mao.size = Vector2(largura, 140)
	_mao.position = Vector2(-largura / 2.0, -Carta.SIZE.y / 2.0)
	_mao.configurar_leque(int(_ajustes["separacao"]), int(_ajustes["curvatura"]), int(_ajustes["abertura"]), false)
	var variacao := float(_ajustes["variacao_tamanho"])
	for indice in range(_cartas.size()):
		var carta := _cartas[indice]
		var fator := lerpf(1.0 - variacao / 2.0, 1.0 + variacao / 2.0, indice / 6.0)
		carta.SCALE = Vector2.ONE * 1.5 * fator
		carta.scale = carta.SCALE
		var centro := (_cartas.size() - 1) / 2.0
		var posicao_relativa := (indice - centro) / maxf(centro, 1.0)
		carta.definir_deformacao(deformacao * posicao_relativa if progressiva else 0.0)
		var inclinacao := Vector2(float(_ajustes["inclinacao_x"]), float(_ajustes["inclinacao_y"]))
		if _inclinacao_x_progressiva.button_pressed:
			inclinacao.x *= posicao_relativa
		if _inclinacao_y_progressiva.button_pressed:
			inclinacao.y *= posicao_relativa
		carta.inclinacao_base = inclinacao


func _alternar_gradual(_ativada: bool) -> void:
	_aplicar_ajustes()


func _reposicionar() -> void:
	_grupo.position = _area.size * Vector2(float(_ajustes["posicao_x"]), float(_ajustes["posicao_y"])) / 100.0


func _mudar_faces(mostrar: bool) -> void:
	if _em_virada or _cartas[0].verso == (not mostrar):
		return
	_em_virada = true
	_frentes.disabled = true
	_salvar.disabled = true
	_carregar.disabled = true
	_restaurar.disabled = true
	for indice in range(_cartas.size()):
		_cartas[indice].definir_hover_habilitado(false)
		if mostrar:
			# A virada para o verso limpa a arte; os dados do teste ficam fora da carta.
			_cartas[indice].setup_dados(_dados_cartas[indice])
		_cartas[indice].verso = not mostrar
	await get_tree().create_timer(0.75).timeout
	_em_virada = false
	_frentes.disabled = false
	_salvar.disabled = false
	_carregar.disabled = _testes.is_empty()
	_restaurar.disabled = false
	_aplicar_ajustes()
	for carta in _cartas:
		carta.definir_hover_habilitado(not _painel.visible, true)


func _mudar_sombras(mostrar: bool) -> void:
	for carta in _cartas:
		carta.definir_sombra_visivel(mostrar)


func _entrada_area(evento: InputEvent) -> void:
	if not _painel.visible:
		return
	if evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			_arrastando = evento.pressed
			_posicao_arrasto = Vector2(float(_ajustes["posicao_x"]), float(_ajustes["posicao_y"]))
	elif evento is InputEventMouseMotion and _arrastando:
		_posicao_arrasto += evento.relative / Vector2(maxf(_area.size.x, 1.0), maxf(_area.size.y, 1.0)) * 100.0
		_posicao_arrasto = _posicao_arrasto.clamp(Vector2.ZERO, Vector2.ONE * 100.0)
		(_controles["posicao_x"] as HSlider).value = _posicao_arrasto.x
		(_controles["posicao_y"] as HSlider).value = _posicao_arrasto.y
	_area.accept_event()


func _input(evento: InputEvent) -> void:
	# Consumir a roda antes dos controles impede Slider/SpinBox de alterar os valores.
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
	_painel.visible = not _painel.visible
	_arrastando = false
	for carta in _cartas:
		carta.definir_hover_habilitado(not _painel.visible and not _em_virada, true)


func _perfil_atual() -> Dictionary:
	return {
		"ajustes": _ajustes.duplicate(), "frentes": _frentes.button_pressed,
		"sombras": _sombras.button_pressed, "notas": _notas.text,
		"deformacao_progressiva": _deformacao_progressiva.button_pressed,
		"inclinacao_x_progressiva": _inclinacao_x_progressiva.button_pressed,
		"inclinacao_y_progressiva": _inclinacao_y_progressiva.button_pressed
	}


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
	_carregar.disabled = nomes.is_empty() or _em_virada
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
	if erro != OK:
		_mensagem.text = "Falha ao gravar. O teste está disponível apenas nesta sessão."
		return
	_mensagem.text = "Salvo: %s. Salvar com o mesmo nome atualiza esse teste." % nome


func _carregar_teste() -> void:
	if _testes.is_empty() or _em_virada:
		return
	var nome := _lista.get_item_text(_lista.selected)
	var teste: Dictionary = _testes[nome]
	_nome.text = nome
	_notas.text = String(teste.get("notas", ""))
	_deformacao_progressiva.set_pressed_no_signal(bool(teste.get("deformacao_progressiva", false)))
	_inclinacao_x_progressiva.set_pressed_no_signal(bool(teste.get("inclinacao_x_progressiva", false)))
	_inclinacao_y_progressiva.set_pressed_no_signal(bool(teste.get("inclinacao_y_progressiva", false)))
	_preencher_ajustes(teste["ajustes"])
	_aplicar_exibicao(bool(teste.get("frentes", false)), bool(teste.get("sombras", false)))
	_mensagem.text = "Carregado: " + nome


func _preencher_ajustes(valores: Dictionary) -> void:
	_atualizando_painel = true
	for chave in PADRAO:
		var controle := _controles[chave] as HSlider
		var valor: Variant = valores.get(chave, PADRAO[chave])
		if not (valor is float or valor is int):
			valor = PADRAO[chave]
		controle.value = clampf(float(valor), controle.min_value, controle.max_value)
		_ajustes[chave] = controle.value
	_atualizando_painel = false
	_aplicar_ajustes()


func _aplicar_exibicao(frentes: bool, sombras: bool) -> void:
	_sombras.set_pressed_no_signal(sombras)
	_mudar_sombras(sombras)
	_frentes.set_pressed_no_signal(frentes)
	_mudar_faces(frentes)


func _restaurar_inicio() -> void:
	if _em_virada:
		return
	_deformacao_progressiva.set_pressed_no_signal(false)
	_inclinacao_x_progressiva.set_pressed_no_signal(false)
	_inclinacao_y_progressiva.set_pressed_no_signal(false)
	_preencher_ajustes(PADRAO)
	_aplicar_exibicao(false, false)
	_mensagem.text = "Ajustes iniciais restaurados. Os testes salvos foram mantidos."


func _copiar_valores() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_perfil_atual(), "\t"))
	_mensagem.text = "Valores e anotações copiados."
