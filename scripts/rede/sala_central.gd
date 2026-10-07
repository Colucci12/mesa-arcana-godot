extends RefCounted
class_name SalaCentral

var codigo: String
var anfitriao_peer: int
var participantes: Dictionary = {}
var em_partida := false
var id_partida := 0
var _proximo_id := 1
var _mesa := Mesa_Api.new()


func _init(codigo_sala: String) -> void:
	codigo = codigo_sala


func entrar(peer: int, nome: String) -> Dictionary:
	var nome_limpo := nome.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if nome_limpo.is_empty() or nome_limpo.length() > 24:
		return falha("Escolha um nome com até 24 caracteres.")
	if em_partida:
		return falha("A partida já começou. Aguarde a próxima.")
	if participantes.size() >= 4:
		return falha("A sala já tem quatro jogadores.")
	for jogador in participantes.values():
		if str(jogador["nome"]).to_lower() == nome_limpo.to_lower():
			return falha("Esse nome já está em uso nesta sala.")
	participantes[peer] = {"id": _proximo_id, "nome": nome_limpo}
	_proximo_id += 1
	if participantes.size() == 1:
		anfitriao_peer = peer
	return {"sucesso": true}


func jogadores() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for jogador in participantes.values():
		resultado.append(jogador.duplicate())
	return resultado


func resumo() -> Dictionary:
	return {"codigo": codigo, "nome": "Mesa de %s" % participantes.get(anfitriao_peer, {}).get("nome", "amigos"),
		"quantidade": participantes.size(), "em_partida": em_partida}


func estado(peer: int) -> Dictionary:
	return {"codigo": codigo, "jogadores": jogadores(), "jogador_id": participantes[peer]["id"],
		"anfitriao_id": participantes[anfitriao_peer]["id"], "em_partida": em_partida,
		"id_partida": id_partida, "pode_iniciar": not em_partida and participantes.size() >= 2}


func iniciar(peer: int, nova_partida: int) -> Dictionary:
	if peer != anfitriao_peer:
		return falha("Somente quem organiza a sala pode iniciar a partida.")
	if em_partida or participantes.size() < 2:
		return falha("Aguarde pelo menos dois jogadores na sala.")
	_mesa = Mesa_Api.new()
	for jogador in participantes.values():
		_mesa.obter_mesa().adicionar_jogador(int(jogador["id"]), str(jogador["nome"]))
	var resultado := _mesa.iniciar_partida()
	if resultado["sucesso"]:
		em_partida = true
		id_partida = nova_partida
	return resultado


func comandar(peer: int, partida: int, comando: String, dados: Dictionary) -> Dictionary:
	if not participantes.has(peer) or not em_partida or partida != id_partida:
		return falha("Esse comando não pertence à partida atual.")
	var jogador := int(participantes[peer]["id"])
	match comando:
		"jogar_carta":
			if not dados.get("id_carta") is int or int(dados["id_carta"]) <= 0:
				return falha("Carta inválida.")
			return _mesa.jogar_carta(jogador, int(dados["id_carta"]))
		"comprar_carta":
			return _mesa.comprar_carta(jogador)
		"aceitar_compra_acumulada":
			return _mesa.aceitar_compra_acumulada(jogador)
		"passar_vez":
			return _mesa.passar_vez(jogador)
		"escolher_cor":
			if not dados.get("cor") is String:
				return falha("Cor inválida.")
			return _mesa.escolher_cor(jogador, str(dados["cor"]))
		"escolher_alvo":
			if not dados.get("alvo_id") is int:
				return falha("Jogador inválido.")
			return _mesa.escolher_alvo(jogador, int(dados["alvo_id"]))
	return falha("Comando desconhecido.")


func remover(peer: int) -> String:
	var nome := str(participantes[peer]["nome"])
	participantes.erase(peer)
	var motivo := ""
	if em_partida:
		em_partida = false
		_mesa = Mesa_Api.new()
		motivo = "%s saiu. A partida foi interrompida." % nome
	if anfitriao_peer == peer and not participantes.is_empty():
		anfitriao_peer = int(participantes.keys()[0])
	return motivo


static func falha(mensagem: String) -> Dictionary:
	return {"sucesso": false, "mensagem": mensagem}
