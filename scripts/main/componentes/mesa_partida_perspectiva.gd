extends "res://scripts/main/componentes/mesa_partida.gd"

const CENARIO = preload("res://scripts/main/componentes/cenario_partida.gd")
const VISUAL_UI = preload("res://scripts/main/componentes/tema_partida.gd")

@onready var _botao_comprar: Button = $ComprarCarta
@onready var _botao_enquadramento: Button = $EditarEnquadramento

var _cenario: CENARIO
var _painel_enquadramento: PanelContainer
var _campos_enquadramento: Dictionary = {}
var _atualizando_enquadramento := false
var _mensagem_enquadramento: Label


func _ready() -> void:
	move_child($FundoPartida, 0)
	_cenario = CENARIO.new()
	_cenario.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cenario)
	move_child(_cenario, 1)
	_mao_jogador = _cenario.apresentacao.obter_maos()[0]
	_mao_oponente = _cenario.apresentacao.obter_maos()[1]
	_descarte = _cenario.apresentacao.obter_descarte()
	_cenario.jogada_solicitada.connect(_solicitar_jogada)
	_cenario.compra_solicitada.connect(_solicitar_compra)
	for nome in ["PlanoFundo", "Titulo", "MaoJogador", "MaoOponente", "MaoEsquerda", "MaoDireita", "Monte", "Descarte", "LegendaMonte", "LegendaDescarte"]:
		get_node(nome).hide()
	for filho in get_children():
		if filho is Control and filho != _cenario and filho != $FundoPartida:
			filho.z_index = 200
			if filho is Label:
				filho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	super._ready()
	VISUAL_UI.aplicar_mesa(self)
	_montar_enquadramento()
	_posicionar_interface()
	resized.connect(_posicionar_interface)
	_botao_comprar.pressed.connect(_solicitar_compra)
	_botao_enquadramento.toggled.connect(_alternar_enquadramento)
	visibility_changed.connect(_ao_alterar_visibilidade)


func _obter_maos_visuais() -> Array:
	var maos := _cenario.apresentacao.obter_maos()
	return [maos[0], maos[2], maos[1], maos[3]]


func _iniciar_exibicao(dados: Dictionary) -> void:
	_cenario.apresentacao.limpar_partida()
	super._iniciar_exibicao(dados)
	_cenario.apresentacao.atualizar_jogadores()
	intervalo_troca_maos = _cenario.apresentacao.duracao_trajeto


func interromper_partida(mensagem: String) -> void:
	super.interromper_partida(mensagem)
	_cenario.apresentacao.limpar_partida()


func _adicionar_carta_local(dados_carta: Dictionary) -> void:
	_cenario.apresentacao.receber_carta(_mao_jogador, dados_carta)


func _aplicar_carta_recebida(evento: Dictionary, publico: Dictionary) -> void:
	if int(publico.get("jogador_id", -1)) == id_jogador_local and _jogador_da_vez_id == id_jogador_local:
		var privado: Dictionary = evento.get("privado", {})
		if privado.get("ids_jogaveis") is Array:
			# Aplicar a lista confirmada antes de criar a carta e iniciar sua apresentação.
			_mao_jogador.mostrar_cartas_jogaveis(privado["ids_jogaveis"])
	super._aplicar_carta_recebida(evento, publico)


func _definir_quantidade_oponente(id_jogador: int, quantidade: int) -> void:
	var mao: MaoVisual = _maos[id_jogador]
	while mao.quantidade_cartas() < quantidade:
		_cenario.apresentacao.receber_carta(mao, {})
	_atualizar_quantidade(id_jogador, quantidade)


func _mostrar_carta_inicial(dados_carta: Dictionary) -> void:
	_cenario.apresentacao.mostrar_carta_inicial(dados_carta)


func _aplicar_carta_jogada(dados: Dictionary) -> void:
	var id_jogador := int(dados["jogador_id"])
	var dados_carta: Dictionary = dados["carta"]
	var carta := _procurar_carta_local(int(dados_carta["id"])) if id_jogador == id_jogador_local else _obter_carta_oponente(id_jogador)
	if carta == null:
		push_error("A carta confirmada pelo servidor não está na mão visual.")
		return
	_cenario.apresentacao.jogar_carta(_maos[id_jogador], carta, dados_carta)
	_atualizar_quantidade(id_jogador, int(dados["quantidade_cartas"]))
	_mensagem_efeito = ""
	_mensagem.text = ""


func _trocar_maos_visuais(mao_autor: MaoVisual, mao_alvo: MaoVisual) -> void:
	_cenario.apresentacao.trocar_maos(mao_autor, mao_alvo)


func _aplicar_mao_atualizada(evento: Dictionary) -> void:
	if int(evento.get("publico", {}).get("jogador_id", -1)) != id_jogador_local:
		return
	var cartas: Array = evento.get("privado", {}).get("cartas", [])
	_cenario.apresentacao.atualizar_mao_local(cartas)
	_quantidade_jogador.text = "%d cartas" % cartas.size()


func _atualizar_controles() -> void:
	super._atualizar_controles()
	if _cenario == null:
		return
	_cenario.definir_hover(_partida_ativa and _interacoes_liberadas)
	_cenario.definir_vez_local(_partida_ativa and _interacoes_liberadas and _jogador_da_vez_id == id_jogador_local)
	_botao_comprar.disabled = not _pode_agir() or (_compra_acumulada == 0 and (not _pode_comprar or _carta_comprada_jogavel_id > 0))
	_botao_comprar.text = "Comprar pilha (+%d)" % _compra_acumulada if _compra_acumulada > 0 else "Comprar carta"
	_indicador_turno.add_theme_color_override("font_color", VISUAL_UI.MENU.OURO if _partida_ativa and _jogador_da_vez_id == id_jogador_local else VISUAL_UI.MENU.CREME)


func _pode_agir() -> bool:
	return super._pode_agir() and (_cenario == null or not _cenario.enquadramento_em_edicao())


func _montar_enquadramento() -> void:
	_painel_enquadramento = PanelContainer.new()
	_painel_enquadramento.position = Vector2(16, 64)
	_painel_enquadramento.custom_minimum_size.x = 280
	_painel_enquadramento.z_index = 240
	_painel_enquadramento.hide()
	_painel_enquadramento.theme = VISUAL_UI.tema()
	_painel_enquadramento.add_theme_stylebox_override("panel", VISUAL_UI.painel())
	add_child(_painel_enquadramento)
	var conteudo := VBoxContainer.new()
	conteudo.add_theme_constant_override("separation", 8)
	_painel_enquadramento.add_child(conteudo)
	var ajuda := Label.new()
	ajuda.text = "Arraste a cena com o mouse.\nUse a roda para aproximar ou afastar."
	ajuda.add_theme_font_size_override("font_size", 17)
	conteudo.add_child(ajuda)
	for definicao in [["zoom", "Zoom (%)", 20, 400, 0.1], ["x", "Horizontal", -5000, 5000, 0.1], ["y", "Vertical", -5000, 5000, 0.1]]:
		var linha := HBoxContainer.new()
		conteudo.add_child(linha)
		var legenda := Label.new()
		legenda.text = str(definicao[1])
		legenda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(legenda)
		var numero := SpinBox.new()
		numero.min_value = float(definicao[2])
		numero.max_value = float(definicao[3])
		numero.step = float(definicao[4])
		numero.custom_minimum_size.x = 120
		linha.add_child(numero)
		_campos_enquadramento[str(definicao[0])] = numero
		numero.value_changed.connect(_alterar_enquadramento.bind(str(definicao[0])))
	var restaurar := Button.new()
	restaurar.text = "Restaurar referência"
	restaurar.theme_type_variation = &"AbaMenu"
	restaurar.pressed.connect(_cenario.restaurar_enquadramento)
	conteudo.add_child(restaurar)
	var copiar := Button.new()
	copiar.text = "Copiar enquadramento"
	copiar.theme_type_variation = &"AbaMenu"
	copiar.pressed.connect(_copiar_enquadramento)
	conteudo.add_child(copiar)
	_mensagem_enquadramento = Label.new()
	_mensagem_enquadramento.text = "Ajustes valem para esta sessão."
	_mensagem_enquadramento.add_theme_font_size_override("font_size", 15)
	conteudo.add_child(_mensagem_enquadramento)
	_cenario.enquadramento_alterado.connect(_sincronizar_enquadramento)
	var atual := _cenario.obter_enquadramento()
	var pan: Array = atual["pan"]
	_sincronizar_enquadramento(float(atual["zoom"]), Vector2(float(pan[0]), float(pan[1])))


func _alternar_enquadramento(ativo: bool) -> void:
	_painel_enquadramento.visible = ativo
	_botao_enquadramento.text = "Concluir enquadramento" if ativo else "Ajustar enquadramento"
	_cenario.definir_modo_enquadramento(ativo)
	_atualizar_controles()


func _alterar_enquadramento(valor: float, chave: String) -> void:
	if _atualizando_enquadramento:
		return
	var atual := _cenario.obter_enquadramento()
	var pan: Array = atual["pan"]
	if chave == "zoom":
		atual["zoom"] = valor
	else:
		pan[0 if chave == "x" else 1] = valor
	_cenario.ajustar_enquadramento(float(atual["zoom"]), Vector2(float(pan[0]), float(pan[1])))


func _sincronizar_enquadramento(zoom: float, pan: Vector2) -> void:
	_atualizando_enquadramento = true
	(_campos_enquadramento["zoom"] as SpinBox).value = zoom
	(_campos_enquadramento["x"] as SpinBox).value = pan.x
	(_campos_enquadramento["y"] as SpinBox).value = pan.y
	_atualizando_enquadramento = false
	_mensagem_enquadramento.text = "Ajustes valem para esta sessão."


func _copiar_enquadramento() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_cenario.obter_enquadramento(), "\t"))
	_mensagem_enquadramento.text = "Enquadramento copiado."


func _ao_alterar_visibilidade() -> void:
	if not is_visible_in_tree():
		_botao_enquadramento.set_pressed_no_signal(false)
		_alternar_enquadramento(false)


func _posicionar_escolha_cor() -> void:
	_centralizar_escolha(_escolha_cor)


func _mostrar_escolha_alvo(id_autor: int) -> void:
	super._mostrar_escolha_alvo(id_autor)
	for filho in _escolha_alvo.get_children():
		if filho is Button:
			filho.theme_type_variation = &"AcaoPartida"
			filho.custom_minimum_size = Vector2(220, 44)
			filho.clip_text = true
			filho.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			filho.tooltip_text = filho.text
	_centralizar_escolha(_escolha_alvo)


func _centralizar_escolha(escolha: VBoxContainer) -> void:
	var dimensoes := escolha.get_combined_minimum_size()
	_posicionar_rotulo(escolha, Vector2(0.5, 0.5), -dimensoes * 0.5, dimensoes)


func _posicionar_interface() -> void:
	_posicionar_rotulo(_indicador_turno, Vector2(0.5, 0), Vector2(-220, 16), Vector2(440, 36))
	_posicionar_rotulo(_mensagem, Vector2(0.5, 0), Vector2(-330, 56), Vector2(660, 48))
	_mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_posicionar_rotulo(_nome_jogador, Vector2(0, 1), Vector2(16, -94), Vector2(200, 32))
	_posicionar_rotulo(_quantidade_jogador, Vector2(0, 1), Vector2(16, -62), Vector2(200, 26))
	_posicionar_rotulo(_nome_oponente, Vector2(0.5, 0), Vector2(-130, 120), Vector2(260, 32))
	_posicionar_rotulo(_quantidade_oponente, Vector2(0.5, 0), Vector2(-130, 152), Vector2(260, 26))
	_nome_oponente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantidade_oponente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_posicionar_rotulo(_botao_comprar, Vector2(1, 1), Vector2(-256, -168), Vector2(240, 48))
	_posicionar_rotulo(_botao_passar, Vector2(1, 1), Vector2(-256, -112), Vector2(240, 48))
	_centralizar_escolha(_escolha_cor)
	_centralizar_escolha(_escolha_alvo)


func _posicionar_rotulo(controle: Control, ancora: Vector2, deslocamento: Vector2, dimensoes: Vector2) -> void:
	controle.set_anchor(SIDE_LEFT, ancora.x)
	controle.set_anchor(SIDE_RIGHT, ancora.x)
	controle.set_anchor(SIDE_TOP, ancora.y)
	controle.set_anchor(SIDE_BOTTOM, ancora.y)
	controle.position = size * ancora + deslocamento
	controle.size = dimensoes
