extends Control

signal jogada_solicitada(id_carta: int)
signal compra_solicitada
signal enquadramento_alterado(zoom: float, pan: Vector2)

const CATALOGO = preload("res://scripts/main/cenario/catalogo_cenario.gd")
const ASSET = preload("res://scripts/main/cenario/asset_cenario.gd")
const CARTAS = preload("res://scripts/main/cenario/captura_cartas.gd")
const LUZ = preload("res://scripts/main/cenario/luz_cenario.gd")
const HALOS = preload("res://scripts/main/cenario/halos_cenario.gd")
const AUDIO = preload("res://scripts/main/componentes/audio_cenario.gd")
const APRESENTACAO = preload("res://scripts/main/componentes/apresentacao_partida.gd")
const CENA_APRESENTACAO = preload("res://scenes/main/componentes/apresentacao_partida.tscn")
const INDICADORES = preload("res://scripts/main/componentes/indicadores_turno.gd")
const COMPOSICAO := "res://config/cenario.json"
const CONFIG_AUDIO := "res://config/audio.json"
const REFERENCIA := Vector2(1280, 720)

var apresentacao: APRESENTACAO
var _composicao := Node2D.new()
var _referencia := CARTAS.new()
var _audio := AUDIO.new()
var _zoom := 100.0
var _pan := Vector2.ZERO
var _hover_ativo := false
var _zoom_inicial := 100.0
var _pan_inicial := Vector2.ZERO
var _editar_enquadramento := false
var _botao_arrasto := 0
var _inicio_mouse := Vector2.ZERO
var _inicio_pan := Vector2.ZERO
var _indicadores: INDICADORES
var _mao_da_vez := -1
var _sentido := 1
var _turno_ativo := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	add_child(_composicao)
	_referencia.cena_apresentacao = CENA_APRESENTACAO
	_composicao.add_child(_referencia)
	add_child(_audio)
	_referencia.evento_audio.connect(_tocar_evento)
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COMPOSICAO))
	var dados: Dictionary = snapshot["composicao"]
	var luz := LUZ.validar(dados.get("luz"))
	var cartas := CARTAS.validar(dados.get("cartas"))
	_referencia.atualizar(cartas, luz)
	apresentacao = _referencia.obter_apresentacao() as APRESENTACAO
	_indicadores = INDICADORES.new()
	apresentacao._composicao.add_child(_indicadores)
	_indicadores.preparar(apresentacao)
	var turno := INDICADORES.validar(dados.get("turno_visual"))
	turno["mao"] = -1
	_indicadores.configurar(turno)
	_indicadores.aplicar_luz(luz)
	apresentacao.jogada_solicitada.connect(func(id: int): jogada_solicitada.emit(id))
	for entrada in dados["pecas"]:
		var peca := CATALOGO.validar(entrada)
		if peca.is_empty():
			continue
		var asset := ASSET.new()
		_composicao.add_child(asset)
		asset.aplicar(peca)
		asset.aplicar_luz(luz, _referencia)
	var halos := HALOS.new()
	_composicao.add_child(halos)
	halos.atualizar(luz)
	_zoom = float(dados.get("zoom", 100.0))
	var pan: Array = dados.get("pan", [0.0, 0.0])
	_pan = Vector2(float(pan[0]), float(pan[1]))
	_zoom_inicial = _zoom
	_pan_inicial = _pan
	_audio.aplicar(JSON.parse_string(FileAccess.get_file_as_string(CONFIG_AUDIO)))
	resized.connect(_ajustar_enquadramento)
	visibility_changed.connect(_ao_alterar_visibilidade)
	get_window().focus_exited.connect(_encerrar_arrasto)
	get_window().mouse_exited.connect(_encerrar_arrasto)
	_ajustar_enquadramento()
	_ao_alterar_visibilidade()


func _ajustar_enquadramento() -> void:
	var fator := minf(size.x / REFERENCIA.x, size.y / REFERENCIA.y) * _zoom / 100.0
	_composicao.scale = Vector2.ONE * fator
	_composicao.position = size * 0.5 - REFERENCIA * fator * 0.5 + _pan * fator


func definir_hover(ativo: bool) -> void:
	_hover_ativo = ativo
	_atualizar_interacao()


func _atualizar_interacao() -> void:
	_referencia.definir_interacao(_hover_ativo and not _editar_enquadramento and is_visible_in_tree())


func definir_modo_enquadramento(ativo: bool) -> void:
	_editar_enquadramento = ativo
	_encerrar_arrasto()
	_referencia.sair_do_mouse()
	_atualizar_interacao()


func enquadramento_em_edicao() -> bool:
	return _editar_enquadramento


func obter_enquadramento() -> Dictionary:
	return {"zoom": _zoom, "pan": [_pan.x, _pan.y]}


func ajustar_enquadramento(zoom: float, pan: Vector2) -> void:
	_zoom = clampf(zoom, 20, 400)
	_pan = pan.clamp(Vector2(-5000, -5000), Vector2(5000, 5000))
	_ajustar_enquadramento()
	enquadramento_alterado.emit(_zoom, _pan)


func restaurar_enquadramento() -> void:
	ajustar_enquadramento(_zoom_inicial, _pan_inicial)


func _encerrar_arrasto() -> void:
	_botao_arrasto = 0


func _aproximar_no_mouse(aproximar: bool) -> void:
	var antes := _composicao.get_local_mouse_position()
	_zoom = clampf(_zoom * (1.1 if aproximar else 1.0 / 1.1), 20, 400)
	_ajustar_enquadramento()
	var depois := _composicao.get_local_mouse_position()
	ajustar_enquadramento(_zoom, _pan + depois - antes)
	if _botao_arrasto != 0:
		_inicio_mouse = get_local_mouse_position()
		_inicio_pan = _pan


func definir_vez_local(ativa: bool) -> void:
	_audio.definir_vez_local(ativa and is_visible_in_tree())


func definir_turno(mao: int, sentido: int, ativo: bool) -> void:
	_mao_da_vez = mao
	_sentido = sentido
	_turno_ativo = ativo
	_atualizar_turno_visual()


func reiniciar_turno() -> void:
	_mao_da_vez = -1
	_sentido = 1
	_turno_ativo = false
	_indicadores.reiniciar()
	_atualizar_turno_visual()


func _atualizar_turno_visual() -> void:
	if _indicadores == null:
		return
	var visivel := is_visible_in_tree()
	_indicadores.definir_turno(_mao_da_vez, _sentido, _turno_ativo and visivel)
	if not visivel:
		_indicadores.set_process(false)


func _tocar_evento(acao: String) -> void:
	if is_visible_in_tree():
		_audio.tocar(acao)


func _ao_alterar_visibilidade() -> void:
	var visivel := is_visible_in_tree()
	_atualizar_interacao()
	_atualizar_turno_visual()
	if not visivel:
		_encerrar_arrasto()
		_audio.definir_vez_local(false)
		_audio.suspender_reproducao()
	else:
		_audio.aplicar(_audio.configuracao)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _editar_enquadramento:
		_referencia.sair_do_mouse()
		return
	var foco := get_viewport().gui_get_hovered_control()
	if foco != null and foco != self and foco != get_parent():
		_referencia.sair_do_mouse()
		return
	_referencia.atualizar_mouse(_composicao.get_local_mouse_position())


func _input(evento: InputEvent) -> void:
	if not is_visible_in_tree() or not _editar_enquadramento or _botao_arrasto == 0:
		return
	if evento is InputEventMouseButton and not evento.pressed and evento.button_index == _botao_arrasto:
		_encerrar_arrasto()
		get_viewport().set_input_as_handled()
	elif evento is InputEventMouseMotion:
		var fator := maxf(_composicao.scale.x, 0.001)
		ajustar_enquadramento(_zoom, _inicio_pan + (get_local_mouse_position() - _inicio_mouse) / fator)
		get_viewport().set_input_as_handled()


func _unhandled_input(evento: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _editar_enquadramento:
		if evento is InputEventMouseButton and evento.pressed:
			if evento.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
				_botao_arrasto = evento.button_index
				_inicio_mouse = get_local_mouse_position()
				_inicio_pan = _pan
			elif evento.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				_aproximar_no_mouse(evento.button_index == MOUSE_BUTTON_WHEEL_UP)
			else:
				return
			get_viewport().set_input_as_handled()
		return
	if not _hover_ativo:
		return
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var ponto := _composicao.get_local_mouse_position()
		if _referencia.clicar(ponto):
			get_viewport().set_input_as_handled()
		elif apresentacao.monte_no_ponto(_referencia.posicao_referencia(ponto)):
			compra_solicitada.emit()
			get_viewport().set_input_as_handled()
