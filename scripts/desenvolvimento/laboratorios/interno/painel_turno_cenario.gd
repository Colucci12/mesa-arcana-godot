extends VBoxContainer

signal configuracao_alterada(dados: Dictionary)
signal referencia_solicitada
signal compra_solicitada(mao: int)
signal jogada_solicitada(mao: int)
signal restauracao_solicitada

const INDICADORES = preload("res://scripts/main/componentes/indicadores_turno.gd")
var _dados := INDICADORES.padrao()
var _campos: Dictionary = {}
var _sincronizando := false
var _proxima: Button


func montar(dados: Dictionary) -> void:
	_texto("Sentido e mão da vez", 18)
	_botao("Carregar referência · Turno visual v1", referencia_solicitada.emit)
	_texto("Teste sem rede. Salve um novo conjunto quando gostar do encaixe. Tab oculta os controles.")
	_opcao("ornamento", "Mostrar ornamento na mesa")
	_lista("fonte", "Desenho", ["Ornamento antigo", "Medalhão do pack"], 0)
	_opcao("girar", "Animar giro")
	_opcao("seta", "Pequena seta para indicar o sentido")
	_lista("sentido", "Sentido na mesa", ["Horário · inferior → esquerda", "Anti-horário · inferior → direita"], 0)
	_botao("Inverter sentido", func(): _alterar("sentido", -int(_dados["sentido"])))
	for campo in [["x", "Centro horizontal (%)", 1.0], ["y", "Centro em profundidade (%)", 1.0],
		["largura", "Largura no plano da mesa", 10.0], ["profundidade", "Profundidade no plano", 10.0],
		["circularizacao", "Compensar achatamento do desenho (%)", 1.0],
		["velocidade", "Velocidade (graus por segundo)", 1.0],
		["giro", "Giro inicial (graus)", 1.0], ["opacidade", "Opacidade do ornamento (%)", 1.0]]:
		_numero(str(campo[0]), str(campo[1]), float(campo[2]))
	_texto("Contorno único da mão", 18)
	_opcao("contorno", "Destacar silhueta da mão inteira")
	_lista("mao", "Mão inicial / selecionada", ["Sem destaque", "Inferior · você", "Superior", "Esquerda", "Direita"], 1)
	_proxima = _botao("Passar para a próxima mão", _proxima_mao)
	_opcao("simular_passagem", "Simular turnos automaticamente")
	_texto("A simulação percorre as quatro mãos. Desligue para escolher uma mão específica.")
	_numero("tempo_vez", "Segundos por mão", 0.5)
	_texto("Cor do contorno")
	var cor := ColorPickerButton.new()
	cor.custom_minimum_size.y = 32
	add_child(cor)
	_campos["cor"] = cor
	cor.color_changed.connect(func(valor: Color): _alterar("cor", valor.to_html()))
	var cores := HBoxContainer.new()
	add_child(cores)
	_botao("Dourado", func(): _alterar("cor", "ffca4fff"), cores)
	_botao("Verde", func(): _alterar("cor", "74f0b6ff"), cores)
	_numero("espessura", "Espessura do contorno", 0.5)
	_numero("intensidade", "Intensidade (%)", 5)
	_numero("transicao", "Transição entre mãos (segundos)", 0.05)
	_texto("Sem brilho nas divisões internas e sem clarear as cartas. Comprar/jogar permite comparar a borda durante a reorganização.")
	_botao("Comprar na mão selecionada", func(): compra_solicitada.emit(maxi(int(_dados["mao"]), 0)))
	_botao("Jogar carta do meio dessa mão", func(): jogada_solicitada.emit(maxi(int(_dados["mao"]), 0)))
	_botao("Restaurar 7 cartas por mão", restauracao_solicitada.emit)
	sincronizar(dados)


func _texto(texto: String, tamanho: int = 13) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", tamanho)
	add_child(rotulo)


func _botao(texto: String, acao: Callable, pai: Node = null) -> Button:
	if pai == null:
		pai = self
	var botao := Button.new()
	botao.text = texto
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pai.add_child(botao)
	botao.pressed.connect(acao)
	return botao


func _opcao(chave: String, texto: String) -> void:
	var check := CheckBox.new()
	check.text = texto
	add_child(check)
	_campos[chave] = check
	check.toggled.connect(func(valor: bool): _alterar(chave, valor))


func _lista(chave: String, texto: String, opcoes: Array, deslocamento: int) -> void:
	_texto(texto)
	var lista := OptionButton.new()
	for opcao in opcoes:
		lista.add_item(str(opcao))
	add_child(lista)
	_campos[chave] = lista
	lista.item_selected.connect(func(indice: int):
		_alterar(chave, (1 if indice == 0 else -1) if chave == "sentido" else indice - deslocamento))


func _numero(chave: String, texto: String, passo: float) -> void:
	_texto(texto)
	var numero := SpinBox.new()
	var limites: Vector2 = INDICADORES.LIMITES[chave]
	numero.min_value = limites.x
	numero.max_value = limites.y
	numero.step = passo
	add_child(numero)
	_campos[chave] = numero
	numero.value_changed.connect(func(valor: float): _alterar(chave, valor))


func _alterar(chave: String, valor: Variant) -> void:
	if _sincronizando:
		return
	var novos := _dados.duplicate(true)
	novos[chave] = valor
	configuracao_alterada.emit(INDICADORES.validar(novos))


func _proxima_mao() -> void:
	var indice := INDICADORES.ORDEM.find(int(_dados["mao"]))
	var mao: int = INDICADORES.ORDEM[posmod(indice + int(_dados["sentido"]), 4)] if indice >= 0 else 0
	_alterar("mao", mao)


func sincronizar(dados: Dictionary) -> void:
	_dados = INDICADORES.validar(dados)
	_sincronizando = true
	for chave in _campos:
		var campo: Control = _campos[chave]
		if campo is CheckBox:
			campo.set_pressed_no_signal(bool(_dados[chave]))
		elif campo is OptionButton:
			campo.select((0 if _dados[chave] == 1 else 1) if chave == "sentido" else int(_dados[chave]) + (1 if chave == "mao" else 0))
		elif campo is ColorPickerButton:
			campo.color = Color.html(_dados[chave])
		elif campo is SpinBox:
			campo.set_value_no_signal(float(_dados[chave]))
	_campos["mao"].disabled = bool(_dados["simular_passagem"])
	_proxima.disabled = bool(_dados["simular_passagem"])
	_sincronizando = false
