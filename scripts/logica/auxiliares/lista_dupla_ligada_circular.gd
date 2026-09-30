extends RefCounted
"""Implementação simplificada de uma lista duplamente ligada circular."""
class_name ListaDuplamenteLigadaCircular

# No.gd ou dentro do script principal
class No:
	"""Classe que representa um nó da lista duplamente ligada circular."""
	var dado
	var proximo = null
	var anterior = null

	func _init(p_dado):
		"""Inicializa um novo nó com o dado fornecido."""
		self.dado = p_dado

var _cabeca = null
var _atual = null
var _tamanho = 0

func esta_vazia() -> bool:
	"""Verifica se a lista está vazia."""
	return _cabeca == null

func obter_tamanho() -> int:
	"""Retorna o tamanho da lista."""
	return _tamanho

func adicionar(p_dado):
	"""Adiciona um novo nó no final da lista."""
	var novo_no = No.new(p_dado)

	if esta_vazia():
		# Se a lista estiver vazia, o novo nó aponta para si mesmo
		novo_no.proximo = novo_no
		novo_no.anterior = novo_no
		_cabeca = novo_no
		_atual = novo_no
	else:
		# Se a lista não estiver vazia
		var ultimo_no = _cabeca.anterior
		
		# Atualizando os ponteiros
		novo_no.proximo = _cabeca
		novo_no.anterior = ultimo_no
		ultimo_no.proximo = novo_no
		_cabeca.anterior = novo_no
		
		# Se atual for null, define-o como o primeiro nó
		if _atual == null:
			_atual = _cabeca

	_tamanho += 1

func obter_atual():
	"""Retorna o dado do nó atual sem alterar a posição."""
	if esta_vazia():
		return null

	if _atual == null:
		_atual = _cabeca
		
	return _atual.dado

func reiniciar_atual() -> void:
	_atual = _cabeca

func obter_proximo():
	"""Retorna o dado do próximo nó e avança a posição atual para ele."""
	if esta_vazia():
		return null

	if _atual == null:
		_atual = _cabeca
	else:
		_atual = _atual.proximo
		
	return _atual.dado

func inverter():
	"""Inverte a ordem da lista."""
	if esta_vazia() or _tamanho <= 1:
		# Lista vazia ou com apenas um elemento, não precisa inverter
		return

	var no_aux = _cabeca

	# Percorre a lista e inverte todos os ponteiros
	for i in range(_tamanho):
		# Troca os ponteiros proximo e anterior
		var temp = no_aux.proximo
		no_aux.proximo = no_aux.anterior
		no_aux.anterior = temp
		
		# Move para o próximo nó (que agora é o anterior)
		no_aux = no_aux.anterior

	# Atualiza a cabeça da lista (a cabeça agora é o que era o último elemento)
	_cabeca = _cabeca.proximo

func obter_elementos() -> Array:
	"""Retorna um Array com todos os elementos da lista circular."""
	if esta_vazia():
		return []

	var elementos = []
	var no_aux = _cabeca

	# Percorre a lista
	while true:
		elementos.append(no_aux.dado)
		no_aux = no_aux.proximo
		if no_aux == _cabeca:
			break

	return elementos

func remover(p_dado):
	"""Remove o primeiro nó encontrado que contenha o dado fornecido."""
	if esta_vazia():
		return

	var no_alvo = null
	var no_aux = _cabeca

	# 1. Busca o nó que contém o dado
	for i in range(_tamanho):
		if no_aux.dado == p_dado:
			no_alvo = no_aux
			break
		no_aux = no_aux.proximo

	# Se não encontrou o dado, sai da função
	if no_alvo == null:
		return

	# 2. Caso especial: a lista tem apenas um elemento
	if _tamanho == 1:
		_cabeca = null
		_atual = null
	else:
		# 3. Ajusta os vizinhos para "pularem" o nó alvo
		no_alvo.anterior.proximo = no_alvo.proximo
		no_alvo.proximo.anterior = no_alvo.anterior

		# 4. Se o nó removido era a 'cabeca', movemos a cabeca para o próximo
		if no_alvo == _cabeca:
			_cabeca = no_alvo.proximo
		
		# 5. Se o nó removido era o 'atual', movemos o ponteiro para não ficar nulo
		if no_alvo == _atual:
			_atual = no_alvo.proximo

	# 6. Limpeza de segurança (ajuda o RefCounted a liberar a memória)
	no_alvo.proximo = null
	no_alvo.anterior = null
	
	_tamanho -= 1

func imprimir_lista():
	"""Exibe todos os elementos da lista."""
	if esta_vazia():
		print("Lista vazia")
		return

	var no_aux = _cabeca
	var itens = []

	# Percorre a lista
	while true:
		# Marca o nó atual com asteriscos se for o "atual"
		var item_str = str(no_aux.dado)
		if no_aux == _atual:
			item_str = "*" + item_str + "*"
			
		itens.append(item_str)
		no_aux = no_aux.proximo
		if no_aux == _cabeca:
			break

	# GDScript 4 usa join de forma similar a arrays
	print(" <-> ".join(itens) + " <-> (volta ao início)")
