extends Resource
class_name Baralho_Logico

enum Composicao { COMPLETO, NUMERICO, SEM_CORINGAS, COM_TROCA_COR, SEM_TROCA_MAO }

var _contador_id: int = 1
var _pilha_principal_de_cartas: Array[Carta_Base] = []
var _composicao: Composicao = Composicao.COMPLETO

func printar_baralho() -> void:
	for carta in _pilha_principal_de_cartas:
		print(carta)

func contar_numero_cartas() -> int:
	return _pilha_principal_de_cartas.size()

func comprar_carta() -> Carta_Base:
	if _pilha_principal_de_cartas.is_empty():
		_repor_baralho()
	return retirar_carta()

func pode_comprar_carta() -> bool:
	return true

func retirar_carta() -> Carta_Base:
	if _pilha_principal_de_cartas.is_empty():
		return null
	return _pilha_principal_de_cartas.pop_back()

func consultar_carta_por_id(id_carta: int) -> Carta_Base:
	for carta in _pilha_principal_de_cartas:
		if carta.get_id() == id_carta:
			return carta
	return null

func retirar_carta_numerica() -> Carta_Base:
	for indice in range(_pilha_principal_de_cartas.size() - 1, -1, -1):
		if _pilha_principal_de_cartas[indice] is Carta_Numerica:
			return _pilha_principal_de_cartas.pop_at(indice)
	return null

func limpar() -> void:
	_pilha_principal_de_cartas.clear()

func adicionar_cartas(cartas: Array[Carta_Base], embaralhar: bool = true) -> void:
	_pilha_principal_de_cartas.append_array(cartas)
	if embaralhar:
		_pilha_principal_de_cartas.shuffle()

func criar_baralho() -> void:
	_composicao = Composicao.COMPLETO
	_repor_baralho()

func criar_baralho_numerico() -> void:
	_composicao = Composicao.NUMERICO
	_repor_baralho()

func criar_baralho_sem_coringas() -> void:
	_composicao = Composicao.SEM_CORINGAS
	_repor_baralho()

func criar_baralho_com_troca_cor() -> void:
	_composicao = Composicao.COM_TROCA_COR
	_repor_baralho()

func criar_baralho_sem_troca_mao() -> void:
	_composicao = Composicao.SEM_TROCA_MAO
	_repor_baralho()

func _repor_baralho() -> void:
	var baralho := _criar_baralho_numerico()
	if _composicao != Composicao.NUMERICO:
		baralho.append_array(_criar_baralho_especial(2))
	match _composicao:
		Composicao.COM_TROCA_COR:
			for _indice in range(2):
				var carta := Carta_Troca_Cor.new()
				carta.set_id(_contador_id)
				_contador_id += 1
				baralho.append(carta)
		Composicao.SEM_TROCA_MAO:
			for _indice in range(2):
				for carta in [Carta_Troca_Cor.new(), Carta_Compra_Quatro.new()]:
					carta.set_id(_contador_id)
					_contador_id += 1
					baralho.append(carta)
		Composicao.COMPLETO:
			baralho.append_array(_criar_baralho_coringa(2))
	limpar()
	adicionar_cartas(baralho)

func _criar_baralho_numerico() -> Array[Carta_Base]:
	var baralho: Array[Carta_Base] = []
	
	for cor in [Carta_Base.Cores.AZUL, Carta_Base.Cores.VERDE, Carta_Base.Cores.VERMELHO, Carta_Base.Cores.AMARELO]:
		for numero in range(0, 10):
			var carta = Carta_Numerica.new(str(numero), cor)
			carta.set_id(_contador_id)
			_contador_id += 1
			baralho.append(carta)

	return baralho

func _criar_baralho_especial(quantidade: int = 1) -> Array[Carta_Base]:
	var baralho: Array[Carta_Base] = []
	var carta: Carta_Base
	
	for cor in [Carta_Base.Cores.AZUL, Carta_Base.Cores.VERDE, Carta_Base.Cores.VERMELHO, Carta_Base.Cores.AMARELO]:
		for n in range(0, max(quantidade, 0)):
			carta = Carta_Compra_Dois.new(cor)
			carta.set_id(_contador_id)
			_contador_id += 1
			baralho.append(carta)
			
			carta = Carta_Inverte.new(cor)
			carta.set_id(_contador_id)
			_contador_id += 1
			baralho.append(carta)
			
			carta = Carta_Pula_Turno.new(cor)
			carta.set_id(_contador_id)
			_contador_id += 1
			baralho.append(carta)
	
	return baralho

func _criar_baralho_coringa(quantidade: int = 1) -> Array[Carta_Base]:
	var baralho: Array[Carta_Base] = []
	var carta: Carta_Base
	
	for n in range(0, max(quantidade, 0)):
		carta = Carta_Compra_Quatro.new()
		carta.set_id(_contador_id)
		_contador_id += 1
		baralho.append(carta)
		
		carta = Carta_Troca_Cor.new()
		carta.set_id(_contador_id)
		_contador_id += 1
		baralho.append(carta)
		
		carta = Carta_Troca_Mao.new()
		carta.set_id(_contador_id)
		_contador_id += 1
		baralho.append(carta)
	
	return baralho
