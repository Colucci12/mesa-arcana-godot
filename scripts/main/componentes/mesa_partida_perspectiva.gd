extends "res://scripts/main/componentes/mesa_partida.gd"

const CENARIO = preload("res://scripts/main/componentes/cenario_partida.gd")

@onready var _botao_comprar: Button = $ComprarCarta

var _cenario: CENARIO


func _ready() -> void:
	_cenario = CENARIO.new()
	_cenario.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cenario)
	move_child(_cenario, 0)
	_mao_jogador = _cenario.apresentacao.obter_maos()[0]
	_mao_oponente = _cenario.apresentacao.obter_maos()[1]
	_descarte = _cenario.apresentacao.obter_descarte()
	_cenario.jogada_solicitada.connect(_solicitar_jogada)
	_cenario.compra_solicitada.connect(_solicitar_compra)
	for nome in ["PlanoFundo", "Titulo", "MaoJogador", "MaoOponente", "MaoEsquerda", "MaoDireita", "Monte", "Descarte", "LegendaMonte", "LegendaDescarte"]:
		get_node(nome).hide()
	for filho in get_children():
		if filho is Control and filho != _cenario:
			filho.z_index = 200
			if filho is Label:
				filho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	super._ready()
	_posicionar_interface()
	resized.connect(_posicionar_interface)
	_botao_comprar.pressed.connect(_solicitar_compra)


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


func _posicionar_escolha_cor() -> void:
	_escolha_cor.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_escolha_cor.position = size * 0.5 - Vector2(50, 72)


func _posicionar_interface() -> void:
	_posicionar_rotulo(_indicador_turno, Vector2(0.5, 0), Vector2(-220, 16), Vector2(440, 36))
	_posicionar_rotulo(_mensagem, Vector2(0.5, 0), Vector2(-330, 56), Vector2(660, 48))
	_mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_posicionar_rotulo(_nome_jogador, Vector2(0, 1), Vector2(16, -94), Vector2(200, 32))
	_posicionar_rotulo(_quantidade_jogador, Vector2(0, 1), Vector2(16, -62), Vector2(200, 26))
	_posicionar_rotulo(_nome_oponente, Vector2(0.5, 0), Vector2(-130, 105), Vector2(260, 32))
	_posicionar_rotulo(_quantidade_oponente, Vector2(0.5, 0), Vector2(-130, 137), Vector2(260, 26))
	_nome_oponente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantidade_oponente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_posicionar_rotulo(_botao_comprar, Vector2(1, 1), Vector2(-190, -152), Vector2(174, 40))
	_posicionar_rotulo(_botao_passar, Vector2(1, 1), Vector2(-190, -104), Vector2(174, 40))


func _posicionar_rotulo(controle: Control, ancora: Vector2, deslocamento: Vector2, dimensoes: Vector2) -> void:
	controle.set_anchor(SIDE_LEFT, ancora.x)
	controle.set_anchor(SIDE_RIGHT, ancora.x)
	controle.set_anchor(SIDE_TOP, ancora.y)
	controle.set_anchor(SIDE_BOTTOM, ancora.y)
	controle.position = size * ancora + deslocamento
	controle.size = dimensoes
