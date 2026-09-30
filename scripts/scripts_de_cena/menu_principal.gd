extends Control

@onready var _jogar: Button = $Centro/Opcoes/Jogar

func _ready() -> void:
	_jogar.pressed.connect(_abrir_conexao)
	$Centro/Opcoes/Sair.pressed.connect(get_tree().quit)
	_jogar.grab_focus.call_deferred()

func _abrir_conexao() -> void:
	get_tree().change_scene_to_file("res://scenes/partida_rede.tscn")
