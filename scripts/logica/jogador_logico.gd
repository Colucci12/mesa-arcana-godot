extends Resource
class_name Jogador_Logico

var _id_jogador: int
var _nome: String
var _mao_de_cartas: Array[Carta_Base] = []

func _init(id: int, nick: String) -> void:
	_id_jogador = id
	_nome = nick

func get_id() -> int:
	return _id_jogador

func recebe_carta(carta: Carta_Base) -> void:
	if carta:
		_mao_de_cartas.append(carta)

func consulta_carta(id_carta: int) -> Carta_Base:
	for i in range(_mao_de_cartas.size()):
		if _mao_de_cartas[i].get_id() == id_carta:
			return _mao_de_cartas[i]
	return null

func descarta_carta(id_carta: int) -> Carta_Base:
	for i in range(_mao_de_cartas.size()):
		if _mao_de_cartas[i].get_id() == id_carta:
			return _mao_de_cartas.pop_at(i)
	return null

func retorna_quantidade_cartas() -> int:
	return _mao_de_cartas.size()

func entregar_mao() -> Array[Carta_Base]:
	var mao: Array[Carta_Base] = []
	mao.assign(_mao_de_cartas)
	_mao_de_cartas.clear()
	return mao

func receber_mao(cartas: Array[Carta_Base]) -> void:
	_mao_de_cartas.assign(cartas)

func limpar_mao() -> void:
	_mao_de_cartas.clear()

func serializar_mao() -> Array[Dictionary]:
	var cartas: Array[Dictionary] = []
	for carta in _mao_de_cartas:
		cartas.append(carta.para_dados())
	return cartas

func printar_mao_cartas() -> void:
	print("Jogador: %s" % [_nome])
	for carta in _mao_de_cartas:
		print(carta)

func get_nome() -> String:
	return _nome
