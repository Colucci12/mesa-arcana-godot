extends Control

const REFERENCIA := Vector2(1280, 720)
const CENA_MAO = preload("res://scenes/main/componentes/mao.tscn")
const CENA_CARTA = preload("res://scenes/main/componentes/carta.tscn")
const CORES = ["VERMELHO", "AZUL", "VERDE", "AMARELO"]
const CENTROS = [Vector2(0.5, 0.83), Vector2(0.5, 0.17), Vector2(0.13, 0.5), Vector2(0.87, 0.5)]
const GIROS = [0.0, 180.0, 90.0, -90.0]

@onready var _composicao: Node2D = $Composicao
@onready var _mesa: MesaVisual = $Composicao/Mesa
@onready var _plano: TextureRect = $Composicao/Mesa/PlanoMesa
@onready var _viewport_mesa: SubViewport = $Composicao/Mesa/PlanoViewport
@onready var _conteudo_mesa: Control = $Composicao/Mesa/PlanoViewport/Conteudo

var _mouse_na_janela := true
var _mouse_na_mesa := false
var _posicao_mouse_anterior := Vector2.ZERO


func _ready() -> void:
	_dimensionar_plano()
	_viewport_mesa.gui_disable_input = false
	for indice in range(4):
		_montar_mao(indice)
	resized.connect(_ajustar_enquadramento)
	get_window().mouse_entered.connect(_ao_mouse_entrar)
	get_window().mouse_exited.connect(_ao_mouse_sair)
	get_window().focus_exited.connect(_sair_da_mesa)
	_ajustar_enquadramento()


func _dimensionar_plano() -> void:
	# A largura aumenta o espaço disponível, em vez de ampliar o conteúdo.
	var dimensoes := Vector2i(roundi(_mesa.largura_proxima), roundi(MesaVisual.TAMANHO_PLANO.y))
	_conteudo_mesa.size = Vector2(dimensoes)
	_mesa.definir_tamanho_plano(Vector2(dimensoes))


func _process(_delta: float) -> void:
	if not _mouse_na_janela or not get_window().has_focus():
		_sair_da_mesa()
		return
	var uv := _plano.get_local_mouse_position() / _plano.size
	if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
		_sair_da_mesa()
		return
	# Mesma conversão que o fragmento do shader usa para amostrar o plano.
	var largura := lerpf(_mesa.largura_distante, 1.0, uv.y)
	var origem := Vector2(0.5 + (uv.x - 0.5) / largura, uv.y / largura)
	if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(origem):
		_sair_da_mesa()
		return
	var posicao_mouse := origem * Vector2(_viewport_mesa.size_2d_override)
	if not _mouse_na_mesa:
		_viewport_mesa.notify_mouse_entered()
		_mouse_na_mesa = true
		_posicao_mouse_anterior = posicao_mouse
	var movimento := InputEventMouseMotion.new()
	# push_input com coordenadas locais recebe as dimensões lógicas do plano,
	# sem aplicar novamente a resolução ampliada usada na renderização.
	movimento.position = posicao_mouse
	movimento.global_position = posicao_mouse
	movimento.relative = posicao_mouse - _posicao_mouse_anterior
	_viewport_mesa.push_input(movimento, true)
	_posicao_mouse_anterior = posicao_mouse


func _ao_mouse_entrar() -> void:
	_mouse_na_janela = true


func _ao_mouse_sair() -> void:
	_mouse_na_janela = false
	_sair_da_mesa()


func _sair_da_mesa() -> void:
	if _mouse_na_mesa:
		_viewport_mesa.notify_mouse_exited()
		_mouse_na_mesa = false


func _montar_mao(indice: int) -> void:
	var mao := CENA_MAO.instantiate() as MaoVisual
	# Apenas posição e orientação no plano original; nenhum preset 2.5D.
	mao.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mao.custom_minimum_size = Vector2(360, 140)
	mao.size = Vector2(360, 140)
	mao.pivot_offset = mao.size / 2.0
	mao.position = CENTROS[indice] * Vector2(_viewport_mesa.size_2d_override) - mao.pivot_offset
	mao.rotation_degrees = GIROS[indice]
	mao.color = Color.TRANSPARENT
	mao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mao.mao_adversaria = indice != 0
	_conteudo_mesa.add_child(mao)
	mao.definir_hover_habilitado(true, true)
	for numero in range(7):
		var carta := CENA_CARTA.instantiate() as Carta
		mao.receber_carta(carta, false)
		carta.setup_dados({"id": indice * 7 + numero + 1,
			"cor": CORES[numero % CORES.size()], "valor": str(numero + 1)})
		carta.definir_sombra_visivel(true)


func _ajustar_enquadramento() -> void:
	var fator := maxf(minf(size.x / REFERENCIA.x, size.y / REFERENCIA.y), 0.001)
	_composicao.scale = Vector2.ONE * fator
	_composicao.position = (size - REFERENCIA * fator) / 2.0
