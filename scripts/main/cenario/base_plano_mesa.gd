extends Control

const REFERENCIA := Vector2(1280, 720)
const CENA_MAO = preload("res://scenes/main/componentes/mao.tscn")
const CENTROS = [Vector2(0.5, 0.83), Vector2(0.5, 0.17), Vector2(0.13, 0.5), Vector2(0.87, 0.5)]
const GIROS = [0.0, 180.0, 90.0, -90.0]

@onready var _composicao: Node2D = $Composicao
@onready var _mesa: MesaVisual = $Composicao/Mesa
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


func _ao_mouse_entrar() -> void:
	_mouse_na_janela = true


func _ao_mouse_sair() -> void:
	_mouse_na_janela = false
	_sair_da_mesa()


func _sair_da_mesa() -> void:
	if _mouse_na_mesa:
		_viewport_mesa.notify_mouse_exited()
		_mouse_na_mesa = false


func _montar_mao(_indice: int) -> void:
	pass


func _ajustar_enquadramento() -> void:
	var fator := maxf(minf(size.x / REFERENCIA.x, size.y / REFERENCIA.y), 0.001)
	_composicao.scale = Vector2.ONE * fator
	_composicao.position = (size - REFERENCIA * fator) / 2.0
