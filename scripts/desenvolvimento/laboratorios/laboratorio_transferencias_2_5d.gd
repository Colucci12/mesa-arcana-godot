extends "res://scripts/desenvolvimento/laboratorios/laboratorio_maos_erguidas.gd"

const CENA_COMPRA = preload("res://scenes/main/componentes/monte.tscn")
const CENA_JOGADA = preload("res://scenes/main/componentes/descarte.tscn")
const PLANO_CARTA = preload("res://scripts/desenvolvimento/laboratorios/plano_carta_laboratorio.gd")
const ARQUIVO_MOVIMENTOS = "user://laboratorio_transferencias_2_5d.json"
const CAPTURA_PILHA := Vector2(280, 280)

@export_group("Transferências")
@export_range(0.8, 2.0, 0.05) var duracao_trajeto := 1.0
@export_range(0.0, 160.0, 5.0) var altura_trajeto := 65.0
@export var conjunto_visual_inicial := "teste 5"
@export var centro_compra := Vector2(0.42, 0.57)
@export var centro_jogada := Vector2(0.58, 0.57)

var _compra: MonteVisual
var _jogada: DescarteVisual
var _viewport_pilhas: SubViewport
var _planos_pilhas: Array[Node2D] = []
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


func _ready() -> void:
	super._ready()
	_montar_pilhas()
	_ler_importacoes()
	if _importacoes.has(conjunto_visual_inicial):
		_aplicar_teste(_importacoes[conjunto_visual_inicial], conjunto_visual_inicial)
		_mensagem.text = "Restaurado: " + conjunto_visual_inicial + ". Testes salvos preservados."
	_atualizar_pilhas()
	_atualizar_estado_trajeto()


func _arquivo_testes() -> String:
	return ARQUIVO_MOVIMENTOS


func _parametros_adicionais_teste() -> Dictionary:
	return {"trajeto": {"duracao": duracao_trajeto, "altura": altura_trajeto,
		"compra": [centro_compra.x, centro_compra.y], "descarte": [centro_jogada.x, centro_jogada.y]}}


func _aplicar_teste(perfil: Dictionary, nome: String) -> void:
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
	for mao in _maos_erguidas:
		mao.duracao_reorganizacao = duracao_trajeto
	super._aplicar_teste(perfil, nome)


func _montar_mao(indice: int) -> void:
	if not _baralho_pronto:
		_baralho_visual.criar_baralho()
		_baralho_pronto = true
	super._montar_mao(indice)
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


func _atualizar_indicadores() -> void:
	super._atualizar_indicadores()
	if _edicao_bloqueada:
		(_controles_avancados["frentes"] as CheckBox).disabled = true


func _montar_painel() -> void:
	super._montar_painel()
	(_controles_ui.get_child(0) as Label).text = "Transferências 2.5D"
	_comandos_trajeto = VBoxContainer.new()
	_controles_ui.add_child(_comandos_trajeto)
	_controles_ui.move_child(_comandos_trajeto, 2)
	var anterior := _controles_ui
	_controles_ui = _comandos_trajeto
	_texto("Comprar/jogar usa a mão selecionada nos controles. Inferior primeiro; depois compare laterais e superior.")
	_botao("Comprar para a mão selecionada · D", _comprar)
	_botao("Jogar da mão selecionada · J", _jogar_carta)
	_escolha_jogada = OptionButton.new()
	for texto in ["Jogar a primeira", "Jogar a carta do meio", "Jogar a última"]:
		_escolha_jogada.add_item(texto)
	_controles_ui.add_child(_escolha_jogada)
	_botao("Esvaziar mãos e descarte · R", _esvaziar)
	_estado_trajeto = _texto("")
	_controles_ui = anterior
	_texto("Importar do laboratório visual", 16)
	_lista_importacoes = OptionButton.new()
	_controles_ui.add_child(_lista_importacoes)
	_botao("Importar conjunto visual selecionado", _importar_visual)
	_mensagem.text = "Importe seu conjunto visual. Salvar aqui usa um arquivo separado; não grava distribuição de cartas."


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
	_viewport_pilhas.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_composicao.add_child(_viewport_pilhas)
	_compra = CENA_COMPRA.instantiate() as MonteVisual
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
		var plano := PLANO_CARTA.new()
		_composicao.add_child(plano)
		plano.face.z_index = 3 + indice
		plano.usar_textura(_viewport_pilhas.get_texture(), CAPTURA_PILHA, Vector4(indice * 0.5, 0, 0.5, 1))
		_planos_pilhas.append(plano)
	for _indice in range(3):
		var carta := _compra.criar_carta()
		var dados := _baralho_visual.comprar_carta().para_dados()
		_dados_por_instancia[carta.get_instance_id()] = dados
		carta.setup_dados(dados)
		_jogada.receber_carta(carta)
		carta.aplicar_estado_visual(_estado_descarte(carta), false)
		carta.definir_sombra_visivel(false)
		carta.definir_hover_habilitado(false)


func _plano_pilha(indice: int) -> Dictionary:
	var centro := (centro_compra if indice == 0 else centro_jogada) * Vector2(_viewport_mesa.size_2d_override)
	var altura := 8.0 if indice == 0 else 2.0
	return {"ponto": Vector3(centro.x - CAPTURA_PILHA.x / 2.0, centro.y - CAPTURA_PILHA.y / 2.0, altura),
		"u": Vector3(CAPTURA_PILHA.x, 0, 0), "v": Vector3(0, CAPTURA_PILHA.y, 0), "frontal": 0.0}


func _atualizar_pilhas() -> void:
	for indice in range(_planos_pilhas.size()):
		var plano := _plano_pilha(indice)
		var visual: Node2D = _planos_pilhas[indice]
		visual.apresentar(_matriz_da_mesa(plano["ponto"], plano["u"], plano["v"]))
		visual.projetar_sombra(self, plano, 1.0)


func _projetar_maos() -> void:
	super._projetar_maos()
	_atualizar_pilhas()


func _estado_descarte(carta: Carta) -> Dictionary:
	var indice := carta.get_index()
	return {"posicao": (_jogada.size - Carta.SIZE) / 2.0 + DescarteVisual.DESLOCAMENTOS[indice % 4],
		"rotacao": DescarteVisual.ROTACOES[indice % 4], "escala": Vector2(1.5, 1.5),
		"inclinacao": Vector2.ZERO, "deformacao": 0.0}


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
		var base := _plano_pilha(pilha)
		q -= Vector2(pilha * CAPTURA_PILHA.x, 0)
		var p: Vector3 = base["ponto"]
		return {"ponto": p + Vector3(q.x, q.y, 0), "u": Vector3(u.x, u.y, 0),
			"v": Vector3(v.x, v.y, 0), "frontal": 0.0}
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
	if _transitos.has(id):
		visual = _transitos[id]["visual"]
	else:
		visual = PLANO_CARTA.new()
		_composicao.add_child(visual)
		visual.face.z_index = 20
		visual.capturar_carta(carta)
		carta.reorganizacao_iniciada.connect(_ao_iniciar_reorganizacao.bind(carta))
		carta.reorganizacao_atualizada.connect(_ao_atualizar_reorganizacao.bind(carta))
		carta.reorganizacao_concluida.connect(_ao_concluir_reorganizacao.bind(carta))
	# A carta muda de pai agora. Só a apresentação atravessa os dois canvases.
	carta.definir_apresentacao_externa(true)
	_transitos[id] = {"carta": carta, "visual": visual, "inicio": inicio, "atual": inicio,
		"destino": destino, "novo_trajeto": true, "altura_arco": altura_trajeto}
	_apresentar_trajeto(_transitos[id], inicio)
	_travar_edicao(true)


func _ao_iniciar_reorganizacao(_estado: Dictionary, carta: Carta) -> void:
	var id := carta.get_instance_id()
	if not _transitos.has(id):
		return
	var registro: Dictionary = _transitos[id]
	# A mão reiniciou o tween da carta: preservar também sua aparência projetada.
	registro["inicio"] = registro["atual"]
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
	_apresentar_trajeto(registro, atual)


func _ao_concluir_reorganizacao(carta: Carta) -> void:
	var id := carta.get_instance_id()
	if not _transitos.has(id):
		return
	carta.definir_apresentacao_externa(false)
	var destino := int(_transitos[id]["destino"])
	carta.definir_hover_habilitado(destino == 0 and not _maos_erguidas[0].mao_adversaria)
	_desconectar_apresentacao(carta)
	_transitos[id]["visual"].queue_free()
	_transitos.erase(id)


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
	visual.sincronizar_carta()
	visual.apresentar(_matriz_apresentacao(plano))
	visual.projetar_sombra(self, plano, 1.0 - float(plano["frontal"]))


func _process(delta: float) -> void:
	for id in _transitos.keys():
		var registro: Dictionary = _transitos[id]
		var carta: Carta = registro["carta"]
		if not is_instance_valid(carta):
			registro["visual"].queue_free()
			_transitos.erase(id)
			continue
		# Só sincroniza virada/captura e luz; o tween da Carta avança o trajeto.
		_apresentar_trajeto(registro, registro["atual"])
	if _transitos.is_empty():
		_travar_edicao(false)
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
			if _comandos_trajeto.is_ancestor_of(controle) or _campos_fonte.is_ancestor_of(controle) or controle == _fonte_localizada or controle == _seletor:
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
		registro["visual"].queue_free()
	_transitos.clear()
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
