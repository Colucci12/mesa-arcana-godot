extends Resource
class_name Descarte_Logico

# TODO: ideia futura — não acumular todas as cartas no descarte (memória / baralhos novos)
var _pilha_descarte: Array[Carta_Base] = []

func adicionar_carta(p_carta: Carta_Base) -> void:
	if p_carta == null:
		push_error("Tentativa de descartar uma carta nula.")
		return
	_pilha_descarte.push_back(p_carta)

func consultar_carta() -> Carta_Base:
	if esta_vazia():
		return null
	return _pilha_descarte[-1]

func consultar_carta_por_id(id_carta: int) -> Carta_Base:
	for carta in _pilha_descarte:
		if carta.get_id() == id_carta:
			return carta
	return null

func retirar_carta() -> Carta_Base:
	if esta_vazia():
		push_warning("Tentativa de retirar carta de uma pilha de descarte vazia.")
		return null
	return _pilha_descarte.pop_back()

func limpar() -> void:
	_pilha_descarte.clear()

func esta_vazia() -> bool:
	return _pilha_descarte.is_empty()

func tamanho() -> int:
	return _pilha_descarte.size()
