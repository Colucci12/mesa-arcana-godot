extends Control

signal jogada_solicitada(id_carta: int)
signal compra_solicitada

const CATALOGO = preload("res://scripts/desenvolvimento/laboratorios/interno/catalogo_cenario_2d.gd")
const ASSET = preload("res://scripts/desenvolvimento/laboratorios/asset_cenario_2d.gd")
const CARTAS = preload("res://scripts/desenvolvimento/laboratorios/cartas_cenario_2d.gd")
const LUZ = preload("res://scripts/desenvolvimento/laboratorios/interno/luz_cenario_2d.gd")
const HALOS = preload("res://scripts/desenvolvimento/laboratorios/halos_cenario_2d.gd")
const AUDIO = preload("res://scripts/main/componentes/audio_cenario.gd")
const APRESENTACAO = preload("res://scripts/main/componentes/apresentacao_partida.gd")
const CENA_APRESENTACAO = preload("res://scenes/main/componentes/apresentacao_partida.tscn")
const COMPOSICAO := "res://scripts/desenvolvimento/laboratorios/presets/ajuste_velas_v1.json"
const AUDIO_V2 := "res://scripts/desenvolvimento/laboratorios/presets/audio_v2.json"
const REFERENCIA := Vector2(1280, 720)

var apresentacao: APRESENTACAO
var _composicao := Node2D.new()
var _referencia := CARTAS.new()
var _audio := AUDIO.new()
var _zoom := 100.0
var _pan := Vector2.ZERO
var _hover_ativo := false


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
	_audio.aplicar(JSON.parse_string(FileAccess.get_file_as_string(AUDIO_V2)))
	resized.connect(_ajustar_enquadramento)
	visibility_changed.connect(_ao_alterar_visibilidade)
	_ajustar_enquadramento()
	_ao_alterar_visibilidade()


func _ajustar_enquadramento() -> void:
	var fator := minf(size.x / REFERENCIA.x, size.y / REFERENCIA.y) * _zoom / 100.0
	_composicao.scale = Vector2.ONE * fator
	_composicao.position = size * 0.5 - REFERENCIA * fator * 0.5 + _pan * fator


func definir_hover(ativo: bool) -> void:
	_hover_ativo = ativo
	_referencia.definir_interacao(ativo and is_visible_in_tree())


func definir_vez_local(ativa: bool) -> void:
	_audio.definir_vez_local(ativa and is_visible_in_tree())


func _tocar_evento(acao: String) -> void:
	if is_visible_in_tree():
		_audio.tocar(acao)


func _ao_alterar_visibilidade() -> void:
	var visivel := is_visible_in_tree()
	_referencia.definir_interacao(_hover_ativo and visivel)
	if not visivel:
		_audio.definir_vez_local(false)
		_audio.suspender_reproducao()
	else:
		_audio.aplicar(_audio.configuracao)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var foco := get_viewport().gui_get_hovered_control()
	if foco != null and foco != self and foco != get_parent():
		_referencia.sair_do_mouse()
		return
	_referencia.atualizar_mouse(_composicao.get_local_mouse_position())


func _unhandled_input(evento: InputEvent) -> void:
	if not is_visible_in_tree() or not _hover_ativo:
		return
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var ponto := _composicao.get_local_mouse_position()
		if _referencia.clicar(ponto):
			get_viewport().set_input_as_handled()
		elif apresentacao.monte_no_ponto(_referencia.posicao_referencia(ponto)):
			compra_solicitada.emit()
			get_viewport().set_input_as_handled()
