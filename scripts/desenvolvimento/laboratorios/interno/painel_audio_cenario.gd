extends VBoxContainer

const AUDIO = preload("res://scripts/main/componentes/audio_cenario.gd")
const ARQUIVO := "user://laboratorio_audio_cenario_2d.json"
const PRESET_V1 := "res://scripts/desenvolvimento/laboratorios/presets/audio_v1.json"
const PRESET_V2 := "res://scripts/desenvolvimento/laboratorios/presets/audio_v2.json"
const NOMES_CONTINUOS := {"vento": "Vento", "relogio": "Relógio", "fogo": "Fogo das velas", "musica": "Música"}

var _audio: AUDIO
var _campos: Array[Dictionary] = []
var _paginas: Dictionary = {}
var _atualizando := false
var _biblioteca: Dictionary = {}
var _arquivo_corrompido := false
var _nome: LineEdit
var _lista: OptionButton
var _mensagem: Label
var _ultimo: Label
var _pico: Label
var _isolamento: Label
var _tempo := 0.0


func montar(audio: AUDIO, comprar: Callable, jogar: Callable, restaurar: Callable) -> void:
	_audio = audio
	_ler()
	_texto(self, "Ouvir na composição", 18)
	_texto(self, "Passe o mouse pela mão e clique para jogar. D compra, J joga e R limpa. Tab oculta o painel e mantém os sons.")
	var acoes := HBoxContainer.new()
	add_child(acoes)
	_botao(acoes, "Comprar · D", comprar)
	_botao(acoes, "Jogar · J", jogar)
	_botao(self, "Restaurar 7 cartas por mão", restaurar)
	_check(self, "geral", "", "silencio", "Silenciar tudo")
	_campo(self, "geral", "", "volume", "Volume geral", -60, 0, " dB")
	_texto(self, "Valores mais próximos de zero ficam mais altos. O volume geral soma aos volumes abaixo.")
	_pico = _texto(self, "Saída: silêncio")
	_isolamento = _texto(self, "Categorias: todas")
	_ultimo = _texto(self, _audio.ultimo_som)
	var seletor := OptionButton.new()
	for nome in ["Cartas", "Ambiente", "Fogo", "Música", "Conjuntos de áudio"]:
		seletor.add_item(nome)
	add_child(seletor)
	for nome in ["Cartas", "Ambiente", "Fogo", "Música", "Conjuntos de áudio"]:
		var pagina := VBoxContainer.new()
		add_child(pagina)
		_paginas[nome] = pagina
	seletor.item_selected.connect(func(indice: int): _pagina(seletor.get_item_text(indice)))
	_montar_cartas(_paginas["Cartas"])
	_montar_continuo(_paginas["Ambiente"], "vento")
	_montar_continuo(_paginas["Ambiente"], "relogio")
	_montar_continuo(_paginas["Fogo"], "fogo")
	_texto(_paginas["Fogo"], "Uma camada para o conjunto de velas; ajuste até ficar discreta na sala.")
	_montar_continuo(_paginas["Música"], "musica")
	_texto(_paginas["Música"], "As faixas mantêm o volume original. Ajuste cada escolha pelo ouvido; a emenda musical ainda precisa de avaliação.")
	_montar_conjuntos(_paginas["Conjuntos de áudio"])
	_botao(self, "Ouvir todas as categorias", func(): _audio.isolar(""))
	_botao(self, "Parar prévias e efeitos", _audio.parar_previas)
	_botao(self, "Desligar ambiente, fogo e música", func():
		_audio.parar_tudo()
		_sincronizar())
	_mensagem = _texto(self, "Ajustes de áudio independentes dos conjuntos visuais. Salve quando quiser guardá-los.")
	if _arquivo_corrompido:
		_mensagem.text = "O arquivo de áudio salvo não pôde ser lido e foi preservado."
	_pagina("Cartas")
	_sincronizar()


func _montar_cartas(pai: VBoxContainer) -> void:
	_botao(pai, "Ouvir somente as cartas", func(): _audio.isolar("cartas"))
	_campo(pai, "geral", "", "volume_cartas", "Volume das cartas", -60, 0, " dB")
	for acao in AUDIO.ACOES:
		_texto(pai, AUDIO.ACOES[acao], 16)
		_check(pai, "cartas", acao, "ativo", "Tocar durante a ação")
		var familia := OptionButton.new()
		for grupo in AUDIO.GRUPOS:
			familia.add_item(AUDIO.NOMES_GRUPOS[grupo])
			familia.set_item_metadata(familia.item_count - 1, grupo)
		pai.add_child(familia)
		_campos.append({"controle": familia, "area": "cartas", "item": acao, "chave": "grupo"})
		familia.item_selected.connect(func(indice: int):
			_alterar(familia.get_item_metadata(indice), "cartas", acao, "grupo"))
		var variantes := OptionButton.new()
		pai.add_child(variantes)
		_campos.append({"controle": variantes, "area": "cartas", "item": acao, "chave": "indice"})
		variantes.item_selected.connect(_alterar.bind("cartas", acao, "indice"))
		_check(pai, "cartas", acao, "variar", "Alternar variantes sem repetir a anterior")
		_campo(pai, "cartas", acao, "volume", "Volume da ação", -60, 0, " dB")
		_campo(pai, "cartas", acao, "tom", "Variação de tom (±)", 0, 8, "%")
		_campo(pai, "cartas", acao, "variacao_volume", "Variação de volume (±)", 0, 3, " dB")
		_botao(pai, "Ouvir variante selecionada", func():
			var ajustes: Dictionary = _audio.configuracao["cartas"][acao]
			_audio.ouvir_variante(ajustes["grupo"], ajustes["indice"], acao))
		_botao(pai, "Ouvir com as variações", _audio.tocar.bind(acao, true))
	_texto(pai, "Chegar à mesa toca quando a animação termina. A seleção toca só ao entrar numa carta e limita a repetição ao passar o mouse rapidamente.")


func _montar_continuo(pai: VBoxContainer, chave: String) -> void:
	_texto(pai, NOMES_CONTINUOS[chave], 16)
	if chave == "relogio":
		var vez := CheckBox.new()
		vez.text = "Simular minha vez"
		pai.add_child(vez)
		vez.toggled.connect(_audio.definir_vez_local)
		_texto(pai, "O relógio da cena toca somente na sua vez. Este laboratório não tem turnos; use a simulação para comparar. Ouvir uma vez é uma prévia independente.")
	_check(pai, "continuos", chave, "ativo", "Tocar na cena")
	var seletor := OptionButton.new()
	for stream in AUDIO.CONTINUOS[chave]:
		seletor.add_item(stream.resource_path.get_file().get_basename())
	pai.add_child(seletor)
	_campos.append({"controle": seletor, "area": "continuos", "item": chave, "chave": "indice"})
	seletor.item_selected.connect(_alterar.bind("continuos", chave, "indice"))
	_campo(pai, "continuos", chave, "volume", "Volume", -60, 0, " dB")
	_check(pai, "continuos", chave, "repetir", "Repetir continuamente")
	_botao(pai, "Ouvir uma vez", _audio.ouvir_continuo.bind(chave))
	_botao(pai, "Ouvir somente " + NOMES_CONTINUOS[chave].to_lower(), func(): _audio.isolar(chave))
	_botao(pai, "Recomeçar na cena", func():
		_audio.recomecar(chave)
		_sincronizar())


func _montar_conjuntos(pai: VBoxContainer) -> void:
	_texto(pai, "Guardar ajustes de áudio", 16)
	_nome = LineEdit.new()
	_nome.placeholder_text = "Nome do conjunto de áudio"
	pai.add_child(_nome)
	_lista = OptionButton.new()
	pai.add_child(_lista)
	_botao(pai, "Salvar conjunto de áudio", _salvar)
	_botao(pai, "Carregar conjunto selecionado", _carregar)
	_botao(pai, "Copiar ajustes de áudio", func(): DisplayServer.clipboard_set(JSON.stringify(_audio.configuracao, "\t")))
	_botao(pai, "Restaurar ajustes iniciais de áudio", func():
		_audio.parar_previas()
		_audio.isolar("")
		_audio.aplicar(AUDIO.padrao())
		_sincronizar()
		_mensagem.text = "Áudio restaurado; conjuntos salvos preservados.")
	_texto(pai, "Salvar também guarda quais camadas estão ligadas. Ao carregar, elas voltam a tocar. Isolar uma categoria vale apenas para a sessão.")
	_listar()


func _pagina(nome: String) -> void:
	for chave in _paginas:
		_paginas[chave].visible = chave == nome


func _dados(area: String, item: String) -> Dictionary:
	return _audio.configuracao if area == "geral" else _audio.configuracao[area][item]


func _alterar(valor: Variant, area: String, item: String, chave: String) -> void:
	if _atualizando:
		return
	var dados := _audio.configuracao.duplicate(true)
	var destino: Dictionary = dados if area == "geral" else dados[area][item]
	destino[chave] = valor
	if chave == "grupo":
		destino["indice"] = 0
	_audio.aplicar(dados)
	_sincronizar()


func _sincronizar() -> void:
	_atualizando = true
	for entrada in _campos:
		var dados := _dados(entrada["area"], entrada["item"])
		var controle: Control = entrada["controle"]
		var valor: Variant = dados[entrada["chave"]]
		if controle is CheckBox:
			controle.set_pressed_no_signal(bool(valor))
		elif controle is SpinBox:
			controle.set_value_no_signal(float(valor))
		elif controle is OptionButton:
			if entrada["chave"] == "grupo":
				for indice in range(controle.item_count):
					if controle.get_item_metadata(indice) == valor:
						controle.select(indice)
			elif entrada["area"] == "cartas":
				controle.clear()
				for stream in AUDIO.variantes(entrada["item"], dados["grupo"]):
					controle.add_item(stream.resource_path.get_file().get_basename())
				controle.select(int(valor))
			else:
				controle.select(int(valor))
	_atualizando = false


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _audio == null:
		return
	_tempo += delta
	if _tempo < 0.15:
		return
	_tempo = 0.0
	_ultimo.text = _audio.ultimo_som
	var solo := _audio.categoria_isolada()
	_isolamento.text = "Categorias: todas" if solo.is_empty() else "Isolado: " + str(NOMES_CONTINUOS.get(solo, "Cartas"))
	var pico := _audio.pico_saida()
	_pico.text = "Saída: silêncio" if pico < -60 else "Saída: %.1f dB" % pico
	_pico.modulate = Color(1, 0.5, 0.4) if pico > -1 else Color.WHITE


func _ler() -> void:
	for nome in ["Audio V1", "Audio V2"]:
		var caminho: String = PRESET_V2 if nome == "Audio V2" else PRESET_V1
		var referencia: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		if referencia is Dictionary:
			_biblioteca[nome] = AUDIO.validar(referencia)
	if not FileAccess.file_exists(ARQUIVO):
		if _biblioteca.has("Audio V2"):
			_audio.aplicar(_biblioteca["Audio V2"])
			set_meta("ultimo_nome", "Audio V2")
		return
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if not dados is Dictionary or not dados.get("conjuntos") is Dictionary:
		_arquivo_corrompido = true
		return
	for nome in dados["conjuntos"]:
		if dados["conjuntos"][nome] is Dictionary:
			_biblioteca[str(nome)] = AUDIO.validar(dados["conjuntos"][nome])
	if dados.get("ultima") is Dictionary:
		_audio.aplicar(dados["ultima"])
	if dados.get("nome") is String:
		set_meta("ultimo_nome", dados["nome"])


func _listar() -> void:
	_lista.clear()
	var nomes: Array = _biblioteca.keys()
	nomes.sort()
	for nome in nomes:
		_lista.add_item(nome)
	_lista.disabled = nomes.is_empty()
	if _nome.text.is_empty():
		_nome.text = str(get_meta("ultimo_nome", ""))
	for indice in range(_lista.item_count):
		if _lista.get_item_text(indice) == _nome.text:
			_lista.select(indice)


func _salvar() -> void:
	var nome := _nome.text.strip_edges().left(100)
	if nome.is_empty():
		_mensagem.text = "Escreva um nome para o conjunto de áudio."
		return
	if _arquivo_corrompido:
		_mensagem.text = "O arquivo salvo está inválido. Escrita suspensa para preservá-lo; use Copiar ajustes de áudio."
		return
	var conjuntos := _biblioteca.duplicate(true)
	conjuntos[nome] = _audio.configuracao.duplicate(true)
	var dados := {"conjuntos": conjuntos, "ultima": _audio.configuracao, "nome": nome}
	var temporario := ARQUIVO + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		_mensagem.text = "Não foi possível salvar o áudio; ajustes anteriores preservados."
		return
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(ARQUIVO)) != OK:
		_mensagem.text = "Não foi possível concluir o salvamento do áudio."
		return
	_biblioteca = conjuntos
	_nome.text = nome
	_listar()
	_mensagem.text = "Áudio salvo: " + nome


func _carregar() -> void:
	if _lista.selected < 0:
		return
	var nome := _lista.get_item_text(_lista.selected)
	_audio.parar_tudo()
	_audio.isolar("")
	_audio.aplicar(_biblioteca[nome])
	_nome.text = nome
	_sincronizar()
	_mensagem.text = "Áudio carregado: " + nome + ". Use Salvar para reabrir com estes ajustes."


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


func _check(pai: Node, area: String, item: String, chave: String, texto: String) -> void:
	var check := CheckBox.new()
	check.text = texto
	check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pai.add_child(check)
	_campos.append({"controle": check, "area": area, "item": item, "chave": chave})
	check.toggled.connect(_alterar.bind(area, item, chave))


func _campo(pai: Node, area: String, item: String, chave: String, texto: String,
		minimo: float, maximo: float, sufixo: String) -> void:
	_texto(pai, texto)
	var spin := SpinBox.new()
	spin.min_value = minimo
	spin.max_value = maximo
	spin.step = 0.5 if chave != "tom" else 0.1
	spin.suffix = sufixo
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pai.add_child(spin)
	_campos.append({"controle": spin, "area": area, "item": item, "chave": chave})
	spin.value_changed.connect(_alterar.bind(area, item, chave))
