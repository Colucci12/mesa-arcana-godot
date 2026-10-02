extends "res://scripts/desenvolvimento/laboratorios/laboratorio_quatro_maos.gd"

const CENA_MONTE = preload("res://scenes/main/componentes/monte.tscn")
const CENA_DESCARTE = preload("res://scenes/main/componentes/descarte.tscn")

@export_range(0.8, 2.0, 0.05) var duracao_transferencia := 1.0

var _monte: MonteVisual
var _descarte: DescarteVisual
var _escolha: OptionButton
var _contagem: Label
var _comandos: VBoxContainer
var _em_movimento := false
var _animacoes_ativas := 0
var _baralho := Baralho_Logico.new()
var _dados_movimento: Dictionary = {}


func _ready() -> void:
	await super._ready()
	_monte = CENA_MONTE.instantiate() as MonteVisual
	_descarte = CENA_DESCARTE.instantiate() as DescarteVisual
	for pilha in [_monte, _descarte]:
		_area.add_child(pilha)
		pilha.set_anchors_preset(Control.PRESET_TOP_LEFT)
		pilha.pivot_offset = Vector2.ZERO
		pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monte.size = Vector2(110, 145)
	_descarte.size = Vector2(152, 180)
	_area.resized.connect(_posicionar_pilhas)
	_posicionar_pilhas()
	_descarte.perspectiva_habilitada = true
	_atualizar_duracoes()
	_atualizar_contagem()
	_mensagem.text = "Carregue sua composição e compare comprar/jogar. Reiniciar esvazia as mãos sem alterar seus ajustes."


func _montar_cartas() -> void:
	_baralho.criar_baralho()
	super._montar_cartas()
	for registro in _maos:
		for indice in range(registro["cartas"].size()):
			var carta: Carta = registro["cartas"][indice]
			var dados := _baralho.comprar_carta().para_dados()
			carta.setup_dados(dados)
			registro["dados"][indice] = dados
			_dados_movimento[carta.get_instance_id()] = dados


func _montar_painel() -> void:
	super._montar_painel()
	(_conteudo.get_child(0) as Label).text = "Movimento entre monte, mãos e descarte"
	var comandos := VBoxContainer.new()
	_comandos = comandos
	_conteudo.add_child(comandos)
	_conteudo.move_child(comandos, 2)
	for item in [["Comprar uma por mão · D", _distribuir], ["Jogar uma por mão · J", _jogar], ["Esvaziar mãos e descarte · R", _reiniciar]]:
		var botao := Button.new()
		botao.text = item[0]
		botao.pressed.connect(item[1])
		comandos.add_child(botao)
	_escolha = OptionButton.new()
	for nome in ["Jogar a primeira carta", "Jogar a carta do meio", "Jogar a última carta"]:
		_escolha.add_item(nome)
	comandos.add_child(_escolha)
	_contagem = Label.new()
	_contagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comandos.add_child(_contagem)
	($Layout/AreaVisual/Guia as Label).text = "D: comprar · J: jogar · R: esvaziar\nTab: painel/hover · escolha primeira/meio/última no painel"


func _posicionar_pilhas() -> void:
	_monte.position = _area.size * Vector2(0.42, 0.48) - _monte.size / 2.0
	_descarte.position = _area.size * Vector2(0.59, 0.48) - _descarte.size / 2.0


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		var foco := get_viewport().gui_get_focus_owner()
		if not (foco is LineEdit or foco is TextEdit or foco is SpinBox):
			match evento.physical_keycode:
				KEY_D:
					_distribuir()
					get_viewport().set_input_as_handled()
					return
				KEY_J:
					_jogar()
					get_viewport().set_input_as_handled()
					return
				KEY_R:
					_reiniciar()
					get_viewport().set_input_as_handled()
					return
	if _em_movimento and evento is InputEventKey and evento.physical_keycode != KEY_TAB:
		get_viewport().set_input_as_handled()
		return
	if _em_movimento and evento is InputEventMouseButton and _painel.visible and _painel.get_global_rect().has_point(get_global_mouse_position()) and not _comandos.get_global_rect().has_point(get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		return
	super._input(evento)


func _entrada_area(evento: InputEvent) -> void:
	if not _em_movimento:
		super._entrada_area(evento)


func _iniciar_rodada() -> bool:
	if (_em_virada and not _em_movimento) or not is_instance_valid(_monte):
		return false
	_guardar_selecionada()
	var foco := get_viewport().gui_get_focus_owner()
	if foco != null:
		foco.release_focus()
	_em_movimento = true
	_em_virada = true
	_arrastando = false
	_bloquear_controles(true)
	_atualizar_hover()
	return true


func _distribuir() -> void:
	if not _iniciar_rodada():
		return
	_atualizar_duracoes()
	for registro in _maos:
		var mao: MaoVisual = registro["mao"]
		var dados := _baralho.comprar_carta().para_dados()
		var carta := _monte.criar_carta(dados)
		_dados_movimento[carta.get_instance_id()] = dados
		# O reparent acontece aqui; a própria mão anima todo o novo leque.
		mao.receber_carta_do_monte(carta)
	_sincronizar_cartas()
	_atualizar_contagem()


func _jogar() -> void:
	if not _iniciar_rodada():
		return
	_atualizar_duracoes()
	for registro in _maos:
		var mao: MaoVisual = registro["mao"]
		var quantidade := mao.quantidade_cartas()
		if quantidade == 0:
			continue
		var indice := 0
		if _escolha.selected == 1:
			indice = floori(float(quantidade) / 2.0)
		elif _escolha.selected == 2:
			indice = quantidade - 1
		var carta := mao.obter_carta(indice)
		carta.setup_dados(_dados_movimento[carta.get_instance_id()])
		# A saída dispara a reorganização da mão; o descarte anima sua nova filha.
		_descarte.receber_carta(carta)
	_sincronizar_cartas()
	_atualizar_contagem()


func _atualizar_duracoes() -> void:
	for registro in _maos:
		(registro["mao"] as MaoVisual).duracao_reorganizacao = duracao_transferencia
	_descarte.duracao_animacao = duracao_transferencia


func _process(_delta: float) -> void:
	if not is_instance_valid(_descarte) or not _em_movimento:
		return
	var ativas := 0
	for registro in _maos:
		var mao: MaoVisual = registro["mao"]
		for carta in mao.obter_cartas():
			if carta.em_animacao_visual():
				ativas += 1
	for filho in _descarte.get_children():
		var carta := filho as Carta
		if carta != null and carta.em_animacao_visual():
			ativas += 1
	if ativas != _animacoes_ativas:
		_animacoes_ativas = ativas
		_atualizar_contagem()
	if ativas == 0:
		_finalizar_rodada()


func _sincronizar_cartas() -> void:
	for registro in _maos:
		var mao: MaoVisual = registro["mao"]
		var cartas := mao.obter_cartas()
		var dados: Array[Dictionary] = []
		for carta in cartas:
			dados.append(_dados_movimento[carta.get_instance_id()])
		registro["cartas"] = cartas
		registro["dados"] = dados
	_cartas = _maos[_selecionada]["cartas"]
	_dados_cartas = _maos[_selecionada]["dados"]


func _finalizar_rodada() -> void:
	_em_movimento = false
	_em_virada = false
	_sincronizar_cartas()
	_bloquear_controles(false)
	_atualizar_hover()
	_atualizar_contagem()


func _reiniciar() -> void:
	if not is_instance_valid(_descarte) or (_em_virada and not _em_movimento):
		return
	for registro in _maos:
		(registro["mao"] as MaoVisual).limpar()
	_descarte.limpar()
	_dados_movimento.clear()
	_baralho.criar_baralho()
	_animacoes_ativas = 0
	_finalizar_rodada()
	_mensagem.text = "Mãos vazias. D compra uma carta por mão; repita para testar sete ou mais. Ajustes preservados."


func _atualizar_contagem() -> void:
	var quantidades: Array[String] = []
	for registro in _maos:
		quantidades.append(str((registro["mao"] as MaoVisual).quantidade_cartas()))
	_contagem.text = "Inferior / superior / esquerda / direita: " + " / ".join(quantidades) + "\nDescarte: " + str(_descarte.get_child_count()) + " · Animando: " + str(_animacoes_ativas)
