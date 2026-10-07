extends Node

func _ready() -> void:
	var resultado: Dictionary = GameManager.online.iniciar_servidor()
	if not resultado["sucesso"]:
		push_error(str(resultado["mensagem"]))
		get_tree().quit(1)
