extends "res://scripts/desenvolvimento/laboratorios/laboratorio_perspectiva.gd"

signal jogada_solicitada(id_carta: int)


func configurar_referencia_cenario(perfil: Dictionary, mostrar_mesa: bool) -> void:
	super.configurar_referencia_cenario(perfil, mostrar_mesa)
	limpar_partida()


func _aplicar_avancados(somente: int = -1) -> void:
	# Na partida, o dono define a face; os controles de prévia não revelam adversários.
	for indice in range(_perfis.size()):
		_perfis[indice]["avancados"]["frentes"] = indice == 0
	super._aplicar_avancados(somente)


func _projetar_maos() -> void:
	super._projetar_maos()
	for indice in range(_maos_erguidas.size()):
		if not _maos_erguidas[indice].visible:
			_poligonos[indice].hide()
			_sombras_tampo[indice].hide()


func obter_maos() -> Array[MaoVisual]:
	return _maos_erguidas


func obter_descarte() -> DescarteVisual:
	return _jogada


func limpar_partida() -> void:
	definir_interacao_referencia(false)
	_esvaziar()
	for mao in _maos_erguidas:
		mao.hide()
	_projetar_maos()


func atualizar_jogadores() -> void:
	_projetar_maos()


func receber_carta(mao: MaoVisual, dados: Dictionary) -> Carta:
	var indice := _maos_erguidas.find(mao)
	if indice < 0:
		return null
	var carta := _compra.criar_carta(dados if not dados.is_empty() else null)
	_dados_por_instancia[carta.get_instance_id()] = dados.duplicate(true)
	carta.animacao_2_5d_habilitada = true
	carta.aplicar_estado_visual(_estado_compra(), false)
	carta.definir_sombra_visivel(false)
	_preparar_visual(carta, _plano_carta(carta, -1, false, 0), indice)
	if indice == 0:
		_conectar_hover_audio(carta)
	mao.duracao_reorganizacao = duracao_trajeto
	mao.receber_carta_do_monte(carta)
	var registro: Dictionary = _transitos[carta.get_instance_id()]
	_apresentar_trajeto(registro, registro["atual"])
	carta.definir_hover_habilitado(false)
	_atualizar_captura()
	_projetar_maos()
	evento_audio.emit("compra")
	return carta


func jogar_carta(mao: MaoVisual, carta: Carta, dados: Dictionary) -> void:
	var indice := _maos_erguidas.find(mao)
	if indice == 0:
		var havia_hover := false
		for existente in mao.obter_cartas():
			havia_hover = havia_hover or existente.state
		_silenciar_proximo_hover_audio = havia_hover and mao.quantidade_cartas() > 1
	_sair_da_mesa()
	var id := carta.get_instance_id()
	var inicio: Dictionary = _transitos[id]["atual"] if _transitos.has(id) else _plano_carta(carta, indice)
	_preparar_visual(carta, inicio, -1)
	_dados_por_instancia[id] = dados.duplicate(true)
	carta.setup_dados(dados)
	carta.definir_jogavel(true)
	_jogada.duracao_animacao = duracao_trajeto
	_jogada.receber_carta(carta)
	carta.definir_sombra_visivel(false)
	_atualizar_captura()
	_projetar_maos()
	evento_audio.emit("jogar")


func mostrar_carta_inicial(dados: Dictionary) -> void:
	if dados.is_empty():
		return
	var carta := _compra.criar_carta(dados)
	carta.animacao_2_5d_habilitada = true
	carta.aplicar_estado_visual(_estado_compra(), false)
	_preparar_visual(carta, _plano_carta(carta, -1, false, 0), -1)
	_dados_por_instancia[carta.get_instance_id()] = dados.duplicate(true)
	_jogada.receber_carta(carta)
	carta.definir_sombra_visivel(false)


func trocar_maos(mao_autor: MaoVisual, mao_alvo: MaoVisual) -> void:
	_sair_da_mesa()
	_silenciar_proximo_hover_audio = false
	var indice_autor := _maos_erguidas.find(mao_autor)
	var indice_alvo := _maos_erguidas.find(mao_alvo)
	var proprias := mao_autor.obter_cartas()
	var outras := mao_alvo.obter_cartas()
	# Capturar todas as origens antes de qualquer reorganização do leque.
	for par in [[proprias, indice_autor, indice_alvo], [outras, indice_alvo, indice_autor]]:
		for carta: Carta in par[0]:
			var id := carta.get_instance_id()
			var inicio: Dictionary = _transitos[id]["atual"] if _transitos.has(id) else _plano_carta(carta, int(par[1]))
			_preparar_visual(carta, inicio, int(par[2]))
	mao_autor.trocar_cartas_com(mao_alvo)
	for mao in [mao_autor, mao_alvo]:
		for carta in mao.obter_cartas():
			if mao != _maos_erguidas[0]:
				_dados_por_instancia[carta.get_instance_id()] = {}
				carta.setup_dados({})
			carta.definir_hover_habilitado(false)
	_atualizar_captura()
	_projetar_maos()


func atualizar_mao_local(cartas: Array) -> void:
	var mao := _maos_erguidas[0]
	# A transferência conserva as instâncias. Os dados privados atualizam a nova mão.
	for indice in range(mini(cartas.size(), mao.quantidade_cartas())):
		var carta := mao.obter_carta(indice)
		var dados: Dictionary = cartas[indice]
		_dados_por_instancia[carta.get_instance_id()] = dados.duplicate(true)
		carta.setup_dados(dados)
		_conectar_hover_audio(carta)
	mao.reorganizar()


func clicar_carta_referencia(posicao: Vector2) -> bool:
	if not _interacao_referencia:
		return false
	var local := _composicao.get_global_transform().affine_inverse() * posicao
	var carta := _carta_no_ponto_da_mao(local, 0)
	if carta == null:
		return false
	jogada_solicitada.emit(carta.id_carta)
	return true


func monte_no_ponto(posicao: Vector2) -> bool:
	var local := _composicao.get_global_transform().affine_inverse() * posicao
	var plano := _plano_pilha(0)
	var matriz := _matriz_da_mesa(plano["ponto"], plano["u"], plano["v"])
	var ponto: Vector3 = matriz.inverse() * Vector3(local.x, local.y, 1)
	if ponto.z <= 0.00001:
		return false
	var uv := Vector2(ponto.x, ponto.y) / ponto.z
	return Rect2((CAPTURA_PILHA - _compra.size) / 2.0, _compra.size).has_point(uv * CAPTURA_PILHA)


func _comprar() -> void:
	pass


func _jogar_carta(_carta_especifica: Carta = null) -> void:
	pass
