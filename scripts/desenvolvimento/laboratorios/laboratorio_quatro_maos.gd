extends "res://scripts/desenvolvimento/laboratorios/laboratorio_mao.gd"

const CENA_MAO = preload("res://scenes/main/componentes/mao.tscn")
const ARQUIVO_COMPOSICOES = "user://laboratorio_quatro_maos.json"
const NOMES_MAOS = ["Inferior", "Superior", "Esquerda", "Direita"]
const CHAVES_MAOS = ["inferior", "superior", "esquerda", "direita"]
const POSICOES_INICIAIS = [Vector2(50, 82), Vector2(50, 20), Vector2(20, 50), Vector2(80, 50)]
const GIROS_INICIAIS = [0.0, 180.0, -70.0, 70.0]
const TAMANHOS_INICIAIS = [1.0, 0.65, 0.75, 0.75]

var _maos: Array[Dictionary] = []
var _selecionada: int = 0
var _seletor: OptionButton
var _composicoes: Dictionary = {}
var _lista_composicoes: OptionButton
var _carregar_composicao: Button
var _notas_composicao: TextEdit


func _ready() -> void:
	super._ready()
	await _aplicar_composicao_visual()
	_mensagem.text = "Escolha uma mão para editar ou aplique um teste salvo do laboratório individual."


func _montar_cartas() -> void:
	var grupo_original := _grupo
	var mao_original := _mao
	for indice in range(4):
		if indice == 0:
			_grupo = grupo_original
			_mao = mao_original
		else:
			_grupo = Node2D.new()
			_grupo.name = "Grupo" + NOMES_MAOS[indice]
			_area.add_child(_grupo)
			_mao = CENA_MAO.instantiate() as MaoVisual
			_mao.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_mao.color = Color.TRANSPARENT
			_mao.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_mao.mao_adversaria = true
			_grupo.add_child(_mao)
		# A ordem explicita mantém a mão próxima à frente das outras.
		_grupo.z_index = [3, 0, 1, 2][indice]
		_cartas = []
		_dados_cartas = []
		super._montar_cartas()
		_maos.append({
			"grupo": _grupo, "mao": _mao, "cartas": _cartas,
			"dados": _dados_cartas, "perfil": _perfil_inicial(indice)
		})
	_usar_mao(0)


func _perfil_inicial(indice: int) -> Dictionary:
	var ajustes: Dictionary = PADRAO.duplicate()
	ajustes["posicao_x"] = POSICOES_INICIAIS[indice].x
	ajustes["posicao_y"] = POSICOES_INICIAIS[indice].y
	ajustes["giro"] = GIROS_INICIAIS[indice]
	ajustes["tamanho"] = TAMANHOS_INICIAIS[indice]
	return {
		"ajustes": ajustes, "frentes": indice == 0, "sombras": false, "notas": "",
		"deformacao_progressiva": false,
		"inclinacao_x_progressiva": false, "inclinacao_y_progressiva": false
	}


func _montar_painel() -> void:
	super._montar_painel()
	(_conteudo.get_child(0) as Label).text = "Quatro mãos, uma composição"
	(_conteudo.get_child(1) as Label).text = "Escolha qual mão editar. Os controles e o arraste afetam apenas essa mão."
	_seletor = OptionButton.new()
	for nome in NOMES_MAOS:
		_seletor.add_item("Editar mão " + nome.to_lower())
	_conteudo.add_child(_seletor)
	_conteudo.move_child(_seletor, 3)
	_seletor.item_selected.connect(_selecionar_mao)
	_nome.placeholder_text = "Nome da composição"
	_notas.placeholder_text = "Observações sobre a mão selecionada"
	_salvar.text = "Salvar composição inteira"
	_carregar.text = "Aplicar teste à mão selecionada"
	_restaurar.text = "Restaurar mão selecionada"
	var legenda_testes := _texto("Testes salvos no laboratório de uma mão:")
	_conteudo.move_child(legenda_testes, _lista.get_index())
	var legenda_notas := _texto("Anotações da mão selecionada:")
	_conteudo.move_child(legenda_notas, _notas.get_index())
	for filho in _conteudo.get_children():
		if filho is Button and filho.text == "Copiar valores e anotações":
			filho.text = "Copiar composição e anotações"
	_titulo("Composições salvas")
	_notas_composicao = TextEdit.new()
	_notas_composicao.custom_minimum_size = Vector2(0, 90)
	_notas_composicao.placeholder_text = "Observações sobre o conjunto das quatro mãos"
	_notas_composicao.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_conteudo.add_child(_notas_composicao)
	_lista_composicoes = OptionButton.new()
	_conteudo.add_child(_lista_composicoes)
	_carregar_composicao = _botao("Carregar composição selecionada", _carregar_conjunto)
	_botao("Restaurar as quatro mãos", _restaurar_conjunto)
	($Layout/AreaVisual/Guia as Label).text = "Com painel: arraste a mão selecionada\nTab oculta o painel e ativa o hover nas quatro mãos"


func _usar_mao(indice: int) -> void:
	_selecionada = indice
	var registro := _maos[indice]
	_grupo = registro["grupo"]
	_mao = registro["mao"]
	_cartas = registro["cartas"]
	_dados_cartas = registro["dados"]
	_ajustes = registro["perfil"]["ajustes"].duplicate()


func _guardar_selecionada() -> void:
	_maos[_selecionada]["perfil"] = _perfil_atual()


func _mostrar_perfil(perfil: Dictionary) -> void:
	_deformacao_progressiva.set_pressed_no_signal(bool(perfil.get("deformacao_progressiva", false)))
	_inclinacao_x_progressiva.set_pressed_no_signal(bool(perfil.get("inclinacao_x_progressiva", false)))
	_inclinacao_y_progressiva.set_pressed_no_signal(bool(perfil.get("inclinacao_y_progressiva", false)))
	_frentes.set_pressed_no_signal(bool(perfil.get("frentes", false)))
	_sombras.set_pressed_no_signal(bool(perfil.get("sombras", false)))
	_notas.text = String(perfil.get("notas", ""))
	_preencher_ajustes(perfil["ajustes"])
	_mudar_sombras(_sombras.button_pressed)


func _selecionar_mao(indice: int) -> void:
	if _em_virada:
		_seletor.select(_selecionada)
		return
	_guardar_selecionada()
	_arrastando = false
	_usar_mao(indice)
	_mostrar_perfil(_maos[indice]["perfil"])
	_mensagem.text = "Editando a mão " + NOMES_MAOS[indice].to_lower() + "."


func _reposicionar() -> void:
	for indice in range(_maos.size()):
		var ajustes: Dictionary = _ajustes if indice == _selecionada else _maos[indice]["perfil"]["ajustes"]
		var grupo: Node2D = _maos[indice]["grupo"]
		grupo.position = _area.size * Vector2(float(ajustes["posicao_x"]), float(ajustes["posicao_y"])) / 100.0


func _atualizar_hover() -> void:
	for registro in _maos:
		for carta: Carta in registro["cartas"]:
			carta.definir_hover_habilitado(not _painel.visible and not _em_virada, true)


func _alternar_painel() -> void:
	_painel.visible = not _painel.visible
	_arrastando = false
	_atualizar_hover()


func _bloquear_controles(bloquear: bool) -> void:
	_seletor.disabled = bloquear
	_frentes.disabled = bloquear
	_salvar.disabled = bloquear
	_carregar.disabled = bloquear or _testes.is_empty()
	_restaurar.disabled = bloquear
	_carregar_composicao.disabled = bloquear or _composicoes.is_empty()


func _mudar_faces(mostrar: bool) -> void:
	if _em_virada or _cartas[0].verso == (not mostrar):
		return
	_bloquear_controles(true)
	for registro in _maos:
		for carta: Carta in registro["cartas"]:
			carta.definir_hover_habilitado(false)
	await super._mudar_faces(mostrar)
	_bloquear_controles(false)
	_guardar_selecionada()
	_atualizar_hover()


func _carregar_teste() -> void:
	var nome_composicao := _nome.text
	super._carregar_teste()
	_nome.text = nome_composicao
	_guardar_selecionada()


func _ler_testes() -> void:
	# Somente leitura: os testes individuais continuam no arquivo original.
	super._ler_testes()
	if FileAccess.file_exists(ARQUIVO_COMPOSICOES):
		var arquivo := FileAccess.open(ARQUIVO_COMPOSICOES, FileAccess.READ)
		if arquivo != null:
			var dados: Variant = JSON.parse_string(arquivo.get_as_text())
			if dados is Dictionary:
				for nome in dados:
					if dados[nome] is Dictionary and _composicao_valida(dados[nome]):
						_composicoes[String(nome)] = dados[nome]
	_atualizar_lista_composicoes()


func _composicao_valida(composicao: Dictionary) -> bool:
	var maos: Variant = composicao.get("maos")
	if not maos is Dictionary:
		return false
	for chave in CHAVES_MAOS:
		if not maos.get(chave) is Dictionary or not maos[chave].get("ajustes") is Dictionary:
			return false
	return true


func _atualizar_lista_composicoes(selecionar: String = "") -> void:
	_lista_composicoes.clear()
	var nomes := _composicoes.keys()
	nomes.sort()
	for nome in nomes:
		_lista_composicoes.add_item(String(nome))
		if nome == selecionar:
			_lista_composicoes.select(_lista_composicoes.item_count - 1)
	_carregar_composicao.disabled = nomes.is_empty() or _em_virada
	if nomes.is_empty():
		_lista_composicoes.add_item("Nenhuma composição salva")
		_lista_composicoes.set_item_disabled(0, true)


func _perfil_composicao() -> Dictionary:
	_guardar_selecionada()
	var perfis: Dictionary = {}
	for indice in range(4):
		perfis[CHAVES_MAOS[indice]] = _maos[indice]["perfil"].duplicate(true)
	return {"maos": perfis, "notas": _notas_composicao.text}


func _salvar_teste() -> void:
	if _em_virada:
		return
	var nome := _nome.text.strip_edges()
	if nome.is_empty():
		_mensagem.text = "Dê um nome à composição antes de salvar."
		return
	var arquivo := FileAccess.open(ARQUIVO_COMPOSICOES, FileAccess.WRITE)
	if arquivo == null:
		_mensagem.text = "Não foi possível salvar a composição."
		return
	_composicoes[nome] = _perfil_composicao()
	arquivo.store_string(JSON.stringify(_composicoes, "\t"))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	_atualizar_lista_composicoes(nome)
	_mensagem.text = "Composição salva: " + nome if erro == OK else "Falha ao gravar. A composição está disponível apenas nesta sessão."


func _carregar_conjunto() -> void:
	if _em_virada or _composicoes.is_empty():
		return
	var nome := _lista_composicoes.get_item_text(_lista_composicoes.selected)
	var composicao: Dictionary = _composicoes[nome]
	for indice in range(4):
		_maos[indice]["perfil"] = composicao["maos"][CHAVES_MAOS[indice]].duplicate(true)
	_nome.text = nome
	_notas_composicao.text = String(composicao.get("notas", ""))
	await _aplicar_composicao_visual()
	_mensagem.text = "Composição carregada: " + nome


func _aplicar_composicao_visual() -> void:
	var selecionada_anterior := _selecionada
	var precisa_virar := false
	for registro in _maos:
		for carta: Carta in registro["cartas"]:
			carta.definir_hover_habilitado(false)
	for indice in range(4):
		_usar_mao(indice)
		_mostrar_perfil(_maos[indice]["perfil"])
		_guardar_selecionada()
		for numero in range(_cartas.size()):
			var carta := _cartas[numero]
			if carta.verso != (not _frentes.button_pressed):
				precisa_virar = true
				if _frentes.button_pressed:
					carta.setup_dados(_dados_cartas[numero])
				carta.verso = not _frentes.button_pressed
	_usar_mao(selecionada_anterior)
	_mostrar_perfil(_maos[_selecionada]["perfil"])
	if precisa_virar:
		_em_virada = true
		_bloquear_controles(true)
		await get_tree().create_timer(0.75).timeout
		_em_virada = false
		# Reaplicar a geometria após as viradas, sem deixar elevação residual.
		_guardar_selecionada()
		for indice in range(4):
			_usar_mao(indice)
			_mostrar_perfil(_maos[indice]["perfil"])
		_usar_mao(selecionada_anterior)
		_mostrar_perfil(_maos[_selecionada]["perfil"])
	_bloquear_controles(false)
	_atualizar_hover()


func _restaurar_inicio() -> void:
	if _em_virada:
		return
	_guardar_selecionada()
	_maos[_selecionada]["perfil"] = _perfil_inicial(_selecionada)
	await _aplicar_composicao_visual()
	_mensagem.text = "Mão selecionada restaurada. As demais mãos e os testes salvos foram mantidos."


func _restaurar_conjunto() -> void:
	if _em_virada:
		return
	for indice in range(4):
		_maos[indice]["perfil"] = _perfil_inicial(indice)
	await _aplicar_composicao_visual()
	_mensagem.text = "As quatro mãos foram restauradas. As composições salvas foram mantidas."


func _copiar_valores() -> void:
	if _em_virada:
		return
	DisplayServer.clipboard_set(JSON.stringify(_perfil_composicao(), "\t"))
	_mensagem.text = "Composição e anotações copiadas."
