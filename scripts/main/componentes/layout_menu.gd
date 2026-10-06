extends Control

const REFERENCIA := Vector2(1280, 720)

@onready var _conteudo: Control = $Conteudo


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	var fator := maxf(minf(size.x / REFERENCIA.x, size.y / REFERENCIA.y), 0.01)
	_conteudo.size = REFERENCIA
	_conteudo.scale = Vector2.ONE * fator
	_conteudo.position = (size - REFERENCIA * fator) / 2.0
