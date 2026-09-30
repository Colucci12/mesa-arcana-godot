extends Resource
class_name Carta_Base

enum Cores { AZUL, VERDE, AMARELO, VERMELHO, PRETO }

var _id: int = 0
var _cor: Cores
var valor: String

func _init(p_valor: String, p_cor: Cores) -> void:
	_cor = p_cor
	self.valor = p_valor

func aplicar_efeito(_api_efeitos: Efeitos_Api) -> void:
	pass

func _to_string() -> String:
	return "(%s:%s:%s)" % [str(self._id), self.valor, str(Cores.keys()[_cor])]

func para_dados() -> Dictionary:
	return {
		"id": _id,
		"valor": valor,
		"cor": Cores.keys()[_cor]
	}

#GETTER & SETTER
func get_cor() -> Cores:
	return _cor

func alterar_cor(nova_cor: Cores) -> bool:
	if _cor == nova_cor:
		return false
	_cor = nova_cor
	return true

func get_id() -> int:
	return _id

func set_id(p_id: int) -> void:
	if _id > 0:
		return
	if p_id <= 0:
		return
	_id = p_id
