extends Control
class_name TelaMesa

signal comando_solicitado(comando: StringName, dados: Dictionary)

@export var id_jogador_local: int = 1
@export var intervalo_entre_cartas: float = 0.25
@export var intervalo_distribuicao_inicial: float = 0.09
@export var intervalo_troca_maos: float = 1.0

@onready var _mao_oponente: MaoVisual = $MaoOponente
@onready var _mao_jogador: MaoVisual = $MaoJogador
@onready var _monte: MonteVisual = $Monte
@onready var _escolha_cor: VBoxContainer = $EscolhaCor
@onready var _descarte: DescarteVisual = $Descarte
@onready var _nome_oponente: Label = $NomeOponente
@onready var _quantidade_oponente: Label = $QuantidadeOponente
@onready var _nome_jogador: Label = $NomeJogador
@onready var _quantidade_jogador: Label = $QuantidadeJogador
@onready var _indicador_turno: Label = $IndicadorTurno
@onready var _mensagem: Label = $Mensagem
@onready var _legenda_monte: Label = $LegendaMonte
@onready var _botao_passar: Button = $PassarVez

var _maos: Dictionary = {}
var _nomes: Dictionary = {}
var _contagens: Dictionary = {}
var _geracao_fila: int = 0
var _jogador_escolhendo_alvo_id: int = -1
var _alvo_enviado: bool = false
@onready var _escolha_alvo: VBoxContainer = $EscolhaAlvo
var _jogador_da_vez_id: int = -1
var _partida_ativa: bool = false
var _compra_acumulada: int = 0
var _jogador_escolhendo_cor_id: int = -1
var _escolha_cor_enviada: bool = false
var _pode_comprar: bool = true
var _comprou_neste_turno: bool = false
var _carta_comprada_jogavel_id: int = -1
var _mensagem_efeito: String = ""
var _fila_eventos: Array[Dictionary] = []
var _processando_eventos: bool = false
var _interacoes_liberadas: bool = false

func _ready() -> void:
	_monte.gui_input.connect(_ao_clicar_monte)
	_botao_passar.pressed.connect(_solicitar_passagem)
	resized.connect(_posicionar_escolha_cor)
	_posicionar_escolha_cor()
	$EscolhaCor/Azul.pressed.connect(_solicitar_cor.bind("AZUL"))
	$EscolhaCor/Verde.pressed.connect(_solicitar_cor.bind("VERDE"))
	$EscolhaCor/Amarelo.pressed.connect(_solicitar_cor.bind("AMARELO"))
	$EscolhaCor/Vermelho.pressed.connect(_solicitar_cor.bind("VERMELHO"))
	_atualizar_controles()

func _posicionar_escolha_cor() -> void:
	_escolha_cor.position = _monte.position + Vector2(_monte.size.x + 12.0, -6.0)

func aplicar_eventos(eventos: Array) -> void:
	for evento in eventos:
		_fila_eventos.append(evento)
	if not _processando_eventos:
		_processar_fila()

func _processar_fila() -> void:
	var geracao := _geracao_fila
	_processando_eventos = true
	_atualizar_controles()
	while not _fila_eventos.is_empty():
		var evento: Dictionary = _fila_eventos.pop_front()
		_aplicar_evento(evento)
		if evento.get("tipo", "") == "CartaRecebida":
			var origem: String = evento.get("publico", {}).get("origem", "")
			var intervalo := intervalo_distribuicao_inicial if origem == "inicial" else intervalo_entre_cartas
			await get_tree().create_timer(intervalo).timeout
		elif evento.get("tipo", "") == "MaoAtualizada":
			await get_tree().create_timer(intervalo_troca_maos).timeout
		if geracao != _geracao_fila:
			return
	_processando_eventos = false
	_atualizar_controles()

func mostrar_erro(mensagem: String) -> void:
	_alvo_enviado = false
	_escolha_cor_enviada = false
	_atualizar_controles()
	_mensagem.text = mensagem

func interromper_partida(mensagem: String) -> void:
	_geracao_fila += 1
	_processando_eventos = false
	_jogador_escolhendo_alvo_id = -1
	_partida_ativa = false
	_interacoes_liberadas = false
	_jogador_escolhendo_cor_id = -1
	_escolha_cor_enviada = false
	_fila_eventos.clear()
	_mao_jogador.limpar_jogabilidade()
	_indicador_turno.text = "Partida interrompida"
	_mensagem.text = mensagem
	_atualizar_controles()

func _aplicar_evento(evento: Dictionary) -> void:
	var publico: Dictionary = evento.get("publico", {})
	match evento.get("tipo", ""):
		"PartidaIniciada":
			_iniciar_exibicao(publico)
		"CartaRecebida":
			_aplicar_carta_recebida(evento, publico)
		"DistribuicaoConcluida":
			_interacoes_liberadas = true
			_atualizar_indicador_turno(_nome_do_jogador(_jogador_da_vez_id))
			_mensagem.text = _mensagem_turno()
		"CartaJogada":
			_aplicar_carta_jogada(publico)
		"MaosTrocadas":
			_aplicar_maos_trocadas(publico)
		"MaoAtualizada":
			_aplicar_mao_atualizada(evento)
		"CompraPenalidadeRealizada":
			_aplicar_compra_penalidade(publico)
		"CompraAcumulada":
			_compra_acumulada = int(publico.get("quantidade", 0))
		"EscolhaAlvoSolicitada":
			_mostrar_escolha_alvo(int(publico.get("jogador_id", -1)))
		"EscolhaCorSolicitada":
			_jogador_escolhendo_cor_id = int(publico.get("jogador_id", -1))
			_escolha_cor_enviada = false
			if _jogador_escolhendo_cor_id == id_jogador_local:
				_mensagem.text = "Escolha a nova cor."
			else:
				_mensagem.text = "%s está escolhendo a cor." % _nome_do_jogador(_jogador_escolhendo_cor_id)
		"CorDaCartaAlterada":
			_jogador_escolhendo_cor_id = -1
			_escolha_cor_enviada = false
			var nome_cor := String(publico.get("cor", ""))
			var cor: Carta_Base.Cores = Carta_Base.Cores.get(nome_cor, Carta_Base.Cores.PRETO)
			var id_carta := int(publico.get("id_carta", -1))
			var carta_local := _procurar_carta_local(id_carta)
			if carta_local:
				carta_local.alterar_cor_visual(cor)
			else:
				_descarte.alterar_cor_carta(id_carta, cor)
			_mensagem.text = "Cor alterada para %s." % nome_cor.to_lower()
		"TurnoPulado":
			_registrar_mensagem_efeito("%s perdeu a vez." % publico.get("nome", "Um jogador"))
		"SentidoInvertido":
			_registrar_mensagem_efeito("Sentido invertido.")
		"TurnoAlterado":
			_jogador_escolhendo_cor_id = -1
			_escolha_cor_enviada = false
			_jogador_da_vez_id = int(publico.get("jogador_id", -1))
			_pode_comprar = bool(publico.get("pode_comprar", true))
			_compra_acumulada = int(publico.get("compra_acumulada", 0))
			_comprou_neste_turno = false
			_carta_comprada_jogavel_id = -1
			if _jogador_da_vez_id == id_jogador_local:
				var dados_privados: Dictionary = evento.get("privado", {})
				_mao_jogador.mostrar_cartas_jogaveis(dados_privados.get("ids_jogaveis", []))
			else:
				_mao_jogador.limpar_jogabilidade()
			_atualizar_indicador_turno(String(publico.get("nome", "")))
			_mensagem.text = _mensagem_turno()
			_mensagem_efeito = ""
		"PartidaEncerrada":
			_partida_ativa = false
			_interacoes_liberadas = false
			_jogador_escolhendo_cor_id = -1
			_escolha_cor_enviada = false
			_compra_acumulada = 0
			_mao_jogador.limpar_jogabilidade()
			_indicador_turno.text = "Vencedor: %s" % publico.get("vencedor_nome", "")
			_mensagem.text = "Partida encerrada"
	_atualizar_controles()

func _iniciar_exibicao(dados: Dictionary) -> void:
	_partida_ativa = true
	_interacoes_liberadas = false
	_jogador_escolhendo_cor_id = -1
	_escolha_cor_enviada = false
	_jogador_da_vez_id = int(dados.get("jogador_atual_id", -1))
	_compra_acumulada = int(dados.get("compra_acumulada", 0))
	_pode_comprar = bool(dados.get("pode_comprar", true))
	_comprou_neste_turno = false
	_carta_comprada_jogavel_id = -1
	_mensagem_efeito = ""
	_mao_jogador.limpar_jogabilidade()
	_jogador_escolhendo_alvo_id = -1
	_configurar_jogadores(dados.get("jogadores", []))
	_descarte.limpar()
	_mostrar_carta_inicial(dados.get("carta_topo", {}))
	_mensagem.text = "Distribuindo cartas..."
	_indicador_turno.text = "Distribuindo cartas..."
	_atualizar_controles()

func _aplicar_carta_recebida(evento: Dictionary, publico: Dictionary) -> void:
	var id_jogador := int(publico.get("jogador_id", -1))
	if id_jogador == id_jogador_local:
		var dados_privados: Dictionary = evento.get("privado", {})
		_adicionar_carta_local(dados_privados.get("carta", {}))
		_quantidade_jogador.text = "%d cartas" % int(publico.get("quantidade_cartas", 0))
	else:
		_definir_quantidade_oponente(id_jogador, int(publico.get("quantidade_cartas", 0)))
	match publico.get("origem", ""):
		"inicial":
			if id_jogador == id_jogador_local and _jogador_da_vez_id == id_jogador_local:
				var dados_privados: Dictionary = evento.get("privado", {})
				_mao_jogador.mostrar_cartas_jogaveis(dados_privados.get("ids_jogaveis", []))
		"compra":
			_aplicar_carta_comprada(evento, publico)

func _aplicar_carta_comprada(evento: Dictionary, publico: Dictionary) -> void:
	_mensagem_efeito = ""
	_pode_comprar = bool(publico.get("pode_comprar", true))
	var carta_jogavel := bool(publico.get("carta_jogavel", false))
	if int(publico.get("jogador_id", -1)) == id_jogador_local:
		var dados_privados: Dictionary = evento.get("privado", {})
		var ids_jogaveis: Array = dados_privados.get("ids_jogaveis", [])
		_comprou_neste_turno = true
		_carta_comprada_jogavel_id = int(ids_jogaveis[0]) if not ids_jogaveis.is_empty() else -1
		_mao_jogador.mostrar_cartas_jogaveis(ids_jogaveis)
		if carta_jogavel:
			_mensagem.text = "Jogue a carta recém-comprada ou passe a vez."
		elif _pode_comprar:
			_mensagem.text = "Continue comprando até encontrar uma carta jogável."
		else:
			_mensagem.text = "Monte esgotado: passe a vez."
	else:
		if carta_jogavel:
			_mensagem.text = "%s está decidindo se joga ou passa." % _nome_do_jogador(int(publico.get("jogador_id", -1)))
		elif _pode_comprar:
			_mensagem.text = "%s continua comprando." % _nome_do_jogador(int(publico.get("jogador_id", -1)))
		else:
			_mensagem.text = "%s ficou sem cartas para comprar." % _nome_do_jogador(int(publico.get("jogador_id", -1)))

func _aplicar_carta_jogada(dados: Dictionary) -> void:
	var id_jogador := int(dados.get("jogador_id", -1))
	var dados_carta: Dictionary = dados.get("carta", {})
	var carta: Carta
	if id_jogador == id_jogador_local:
		carta = _procurar_carta_local(int(dados_carta.get("id", -1)))
		_quantidade_jogador.text = "%d cartas" % int(dados.get("quantidade_cartas", 0))
	else:
		carta = _obter_carta_oponente(id_jogador)
		_atualizar_quantidade(id_jogador, int(dados.get("quantidade_cartas", 0)))
	if not carta:
		carta = _monte.criar_carta(dados_carta)
	else:
		carta.setup_dados(dados_carta)
	carta.definir_jogavel(true)
	_descarte.receber_carta(carta)
	_mensagem_efeito = ""
	_mensagem.text = ""

func _aplicar_maos_trocadas(dados: Dictionary) -> void:
	var id_autor := int(dados.get("jogador_id", -1))
	var id_alvo := int(dados.get("alvo_id", -1))
	var mao_autor: MaoVisual = _maos[id_autor]
	var mao_alvo: MaoVisual = _maos[id_alvo]
	_mao_jogador.limpar_jogabilidade()
	mao_autor.trocar_cartas_com(mao_alvo)
	_atualizar_quantidade(id_autor, int(dados.get("quantidade_jogador", 0)))
	_atualizar_quantidade(id_alvo, int(dados.get("quantidade_alvo", 0)))
	_jogador_escolhendo_alvo_id = -1
	_registrar_mensagem_efeito("%s trocou as mãos com %s." % [_nome_do_jogador(id_autor), _nome_do_jogador(id_alvo)])

func _aplicar_mao_atualizada(evento: Dictionary) -> void:
	var publico: Dictionary = evento.get("publico", {})
	if int(publico.get("jogador_id", -1)) != id_jogador_local:
		return
	var privado: Dictionary = evento.get("privado", {})
	var cartas: Array = privado.get("cartas", [])
	while _mao_jogador.get_child_count() < cartas.size():
		var carta_nova := _monte.criar_carta()
		_mao_jogador.receber_carta_do_monte(carta_nova)
	while _mao_jogador.get_child_count() > cartas.size():
		var carta_excedente: Node = _mao_jogador.get_child(_mao_jogador.get_child_count() - 1)
		_mao_jogador.remove_child(carta_excedente)
		carta_excedente.queue_free()
	for indice in range(cartas.size()):
		var carta := _mao_jogador.get_child(indice) as Carta
		carta.setup_dados(cartas[indice])
		if not carta.selecionada.is_connected(_solicitar_jogada):
			carta.selecionada.connect(_solicitar_jogada)
	_quantidade_jogador.text = "%d cartas" % cartas.size()

func _aplicar_compra_penalidade(publico: Dictionary) -> void:
	_compra_acumulada = 0
	var id_jogador := int(publico.get("jogador_id", -1))
	var quantidade := int(publico.get("quantidade_comprada", 0))
	_registrar_mensagem_efeito("%s comprou %d cartas da pilha." % [_nome_do_jogador(id_jogador), quantidade])

func _adicionar_carta_local(dados_carta: Dictionary) -> void:
	var carta := _monte.criar_carta(dados_carta)
	carta.selecionada.connect(_solicitar_jogada)
	_mao_jogador.receber_carta_do_monte(carta)

func _definir_quantidade_oponente(id_jogador: int, quantidade: int) -> void:
	var mao_oponente: MaoVisual = _maos[id_jogador]
	var quantidade_segura := maxi(quantidade, 0)
	while mao_oponente.get_child_count() < quantidade_segura:
		var carta := _monte.criar_carta()
		mao_oponente.receber_carta_do_monte(carta)
	while mao_oponente.get_child_count() > quantidade_segura:
		var carta: Node = mao_oponente.get_child(mao_oponente.get_child_count() - 1)
		mao_oponente.remove_child(carta)
		carta.queue_free()
	_atualizar_quantidade(id_jogador, quantidade_segura)

func _procurar_carta_local(id_carta: int) -> Carta:
	for filho in _mao_jogador.get_children():
		var carta := filho as Carta
		if carta and carta.id_carta == id_carta:
			return carta
	return null

func _obter_carta_oponente(id_jogador: int) -> Carta:
	var mao_oponente: MaoVisual = _maos[id_jogador]
	if mao_oponente.get_child_count() == 0:
		return null
	return mao_oponente.get_child(mao_oponente.get_child_count() - 1) as Carta

func _limpar_mao(mao: Control) -> void:
	for carta in mao.get_children():
		mao.remove_child(carta)
		carta.queue_free()

func _mostrar_carta_inicial(dados_carta: Dictionary) -> void:
	if dados_carta.is_empty():
		return
	var carta := _monte.criar_carta(dados_carta)
	_descarte.receber_carta(carta)

func _solicitar_jogada(id_carta: int) -> void:
	if not _pode_agir():
		return
	if not _mao_jogador.carta_permitida(id_carta):
		if _compra_acumulada > 0:
			_mensagem.text = "Rebata a pilha ou compre as cartas."
		elif _comprou_neste_turno:
			_mensagem.text = "Após comprar, só a carta jogável recém-comprada pode ser jogada."
		else:
			_mensagem.text = "Esta carta não pode ser jogada agora."
		return
	comando_solicitado.emit(&"jogar_carta", {"id_carta": id_carta})

func _solicitar_compra() -> void:
	if not _pode_agir():
		return
	if _compra_acumulada > 0:
		comando_solicitado.emit(&"aceitar_compra_acumulada", {})
		return
	if not _pode_comprar or _carta_comprada_jogavel_id > 0:
		return
	comando_solicitado.emit(&"comprar_carta", {})

func _solicitar_passagem() -> void:
	if not _pode_agir():
		return
	if _compra_acumulada > 0:
		return
	if _carta_comprada_jogavel_id <= 0 and _pode_comprar:
		return
	comando_solicitado.emit(&"passar_vez", {})

func _solicitar_cor(nome_cor: String) -> void:
	if not _partida_ativa or not _interacoes_liberadas or _processando_eventos or _escolha_cor_enviada:
		return
	if _jogador_escolhendo_cor_id != id_jogador_local:
		return
	_escolha_cor_enviada = true
	_escolha_cor.hide()
	_mensagem.text = "Confirmando cor..."
	comando_solicitado.emit(&"escolher_cor", {"cor": nome_cor})

func _ao_clicar_monte(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed:
		_solicitar_compra()
		_monte.accept_event()

func _atualizar_controles() -> void:
	_escolha_alvo.visible = _partida_ativa and not _processando_eventos and not _alvo_enviado and _jogador_escolhendo_alvo_id == id_jogador_local
	var pode_agir := _pode_agir()
	_escolha_cor.visible = _partida_ativa and _interacoes_liberadas and not _processando_eventos and not _escolha_cor_enviada and _jogador_escolhendo_cor_id == id_jogador_local
	var compra_liberada := pode_agir and (_compra_acumulada > 0 or (_pode_comprar and _carta_comprada_jogavel_id <= 0))
	_monte.modulate = Color.WHITE if compra_liberada else Color(0.55, 0.55, 0.55)
	_monte.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if compra_liberada else Control.CURSOR_ARROW
	if pode_agir and _compra_acumulada > 0:
		_legenda_monte.text = "Comprar pilha (+%d)" % _compra_acumulada
	else:
		_legenda_monte.text = "Clique para comprar" if compra_liberada else "Monte"
	_botao_passar.visible = pode_agir and _compra_acumulada == 0 and (_carta_comprada_jogavel_id > 0 or not _pode_comprar)

func _pode_agir() -> bool:
	return _partida_ativa and _interacoes_liberadas and not _processando_eventos and _jogador_escolhendo_cor_id < 0 and _jogador_escolhendo_alvo_id < 0 and _jogador_da_vez_id == id_jogador_local

func _registrar_mensagem_efeito(mensagem: String) -> void:
	if _mensagem_efeito.is_empty():
		_mensagem_efeito = mensagem
	else:
		_mensagem_efeito += " " + mensagem
	_mensagem.text = _mensagem_efeito

func _mensagem_turno() -> String:
	if _compra_acumulada > 0:
		if _jogador_da_vez_id == id_jogador_local:
			return "Pilha +%d: rebata ou clique no monte para comprar." % _compra_acumulada
		return "%s deve rebater ou comprar %d cartas." % [_nome_do_jogador(_jogador_da_vez_id), _compra_acumulada]
	if not _mensagem_efeito.is_empty():
		return _mensagem_efeito
	return "" if _pode_comprar else "Monte esgotado: jogue uma carta ou passe a vez."

func _atualizar_indicador_turno(nome_jogador: String) -> void:
	if _jogador_da_vez_id == id_jogador_local:
		_indicador_turno.text = "Sua vez"
	else:
		_indicador_turno.text = "Vez de %s" % nome_jogador

func _nome_do_jogador(id_jogador: int) -> String:
	return String(_nomes.get(id_jogador, ""))

func _atualizar_quantidade(id_jogador: int, quantidade: int) -> void:
	var rotulo: Label = _contagens.get(id_jogador)
	if rotulo:
		rotulo.text = "%d cartas" % quantidade

func _configurar_jogadores(jogadores: Array) -> void:
	var maos := [_mao_jogador, $MaoEsquerda, _mao_oponente, $MaoDireita]
	var nomes := [_nome_jogador, $NomeEsquerda, _nome_oponente, $NomeDireita]
	var quantidades := [_quantidade_jogador, $QuantidadeEsquerda, _quantidade_oponente, $QuantidadeDireita]
	_maos.clear()
	_nomes.clear()
	_contagens.clear()
	for indice in range(4):
		_limpar_mao(maos[indice])
		maos[indice].hide()
		nomes[indice].hide()
		quantidades[indice].hide()
	var indice_local := 0
	for indice in range(jogadores.size()):
		if int(jogadores[indice]["id"]) == id_jogador_local:
			indice_local = indice
	var posicoes := [0, 2] if jogadores.size() == 2 else ([0, 1, 3] if jogadores.size() == 3 else [0, 1, 2, 3])
	for deslocamento in range(jogadores.size()):
		var jogador: Dictionary = jogadores[(indice_local + deslocamento) % jogadores.size()]
		var id_jogador := int(jogador["id"])
		var posicao: int = posicoes[deslocamento]
		_maos[id_jogador] = maos[posicao]
		_nomes[id_jogador] = String(jogador["nome"])
		_contagens[id_jogador] = quantidades[posicao]
		nomes[posicao].text = String(jogador["nome"])
		maos[posicao].show()
		nomes[posicao].show()
		quantidades[posicao].show()
		_atualizar_quantidade(id_jogador, int(jogador.get("quantidade_cartas", 0)))

func _mostrar_escolha_alvo(id_autor: int) -> void:
	_jogador_escolhendo_alvo_id = id_autor
	_alvo_enviado = false
	for filho in _escolha_alvo.get_children():
		_escolha_alvo.remove_child(filho)
		filho.queue_free()
	for id_jogador in _nomes:
		if id_jogador == id_autor:
			continue
		var botao := Button.new()
		botao.text = _nome_do_jogador(id_jogador)
		botao.pressed.connect(_solicitar_alvo.bind(id_jogador))
		_escolha_alvo.add_child(botao)
	_mensagem.text = "Escolha com quem trocar a mão." if id_autor == id_jogador_local else "%s está escolhendo com quem trocar." % _nome_do_jogador(id_autor)

func _solicitar_alvo(id_alvo: int) -> void:
	if _processando_eventos or _alvo_enviado or _jogador_escolhendo_alvo_id != id_jogador_local:
		return
	_alvo_enviado = true
	_atualizar_controles()
	comando_solicitado.emit(&"escolher_alvo", {"alvo_id": id_alvo})
