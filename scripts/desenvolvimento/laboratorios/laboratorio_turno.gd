extends "res://scripts/desenvolvimento/laboratorios/laboratorio_cenario_2d.gd"


func _ready() -> void:
	super._ready()
	# Retomar o conjunto que o usuário salvou; referência inicial só sem dados de turno.
	var ultima: Variant = _biblioteca.get("ultima")
	if ultima is Dictionary and ultima.get("turno_visual") is Dictionary:
		_categoria("Turno")
		for nome in _biblioteca.get("conjuntos", {}):
			if _biblioteca["conjuntos"][nome] == ultima:
				_nome_conjunto.text = str(nome)
				_listar_conjuntos(str(nome))
				break
	else:
		_carregar_referencia_turno()
