extends Control

const TEMA = preload("res://scripts/main/componentes/tema_menu.gd")

@onready var _jogar: Button = $Interface/Conteudo/Jogar
@onready var _regras: Control = $Interface/Conteudo/ComoJogar
@onready var _botao_regras: Button = $Interface/Conteudo/Regras
@onready var _fechar_regras: Button = $Interface/Conteudo/ComoJogar/Painel/Conteudo/Fechar
@onready var _abertura: ColorRect = $Abertura

func _ready() -> void:
	GameManager.definir_musica_menu(true)
	$Interface.theme = TEMA.tema()
	_jogar.pressed.connect(_abrir_conexao)
	$Interface/Conteudo/Sair.pressed.connect(get_tree().quit)
	_botao_regras.pressed.connect(_mostrar_regras)
	_fechar_regras.pressed.connect(_ocultar_regras)
	$Interface/Conteudo/ComoJogar/Painel/Conteudo/Cabecalho/Icone.texture = TEMA.livro()
	_iniciar_abertura()


func _iniciar_abertura() -> void:
	for elemento in _elementos_menu():
		elemento.modulate.a = 0.0
	for botao in [_jogar, _botao_regras, $Interface/Conteudo/Sair]:
		botao.focus_mode = Control.FOCUS_NONE
	# A música já está tocando: primeiro o escuro, depois a paisagem e o menu.
	var entrada := create_tween()
	entrada.tween_interval(0.9)
	entrada.tween_property(_abertura, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	entrada.tween_callback(_revelar_menu)


func _elementos_menu() -> Array[Control]:
	return [$Interface/Conteudo/Logo, $Interface/Conteudo/Chamada,
		$Interface/Conteudo/Divisor, _jogar, _botao_regras,
		$Interface/Conteudo/Sair, $Interface/Conteudo/Rodape]


func _revelar_menu() -> void:
	var elementos := _elementos_menu()
	var atrasos := [0.0, 0.25, 0.25, 0.5, 0.65, 0.8, 1.05]
	var revelacao := create_tween().set_parallel(true)
	revelacao.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for indice in range(elementos.size()):
		var elemento: Control = elementos[indice]
		var destino_y := elemento.position.y
		elemento.position.y += 14.0
		revelacao.tween_property(elemento, "modulate:a", 1.0, 0.65).set_delay(atrasos[indice])
		revelacao.tween_property(elemento, "position:y", destino_y, 0.65).set_delay(atrasos[indice])
	revelacao.finished.connect(_concluir_abertura)


func _concluir_abertura() -> void:
	_abertura.hide()
	$VolumeMusica.show()
	for botao in [_jogar, _botao_regras, $Interface/Conteudo/Sair]:
		botao.focus_mode = Control.FOCUS_ALL
	_jogar.grab_focus()

func _abrir_conexao() -> void:
	get_tree().change_scene_to_file("res://scenes/main/telas/partida_rede.tscn")


func _mostrar_regras() -> void:
	_jogar.disabled = true
	_botao_regras.disabled = true
	$Interface/Conteudo/Sair.disabled = true
	_regras.show()
	_fechar_regras.grab_focus()


func _ocultar_regras() -> void:
	_regras.hide()
	_jogar.disabled = false
	_botao_regras.disabled = false
	$Interface/Conteudo/Sair.disabled = false
	_botao_regras.grab_focus()


func _unhandled_input(evento: InputEvent) -> void:
	if _regras.visible and evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		_ocultar_regras()
		get_viewport().set_input_as_handled()
