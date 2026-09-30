extends RefCounted
class_name Mesa_Api

const CARTAS_POR_MAO_INICIAL: int = 7

var _mesa: Mesa_Logica

func _init(p_mesa: Mesa_Logica = null) -> void:
	_mesa = p_mesa if p_mesa else Mesa_Logica.new()

func obter_mesa() -> Mesa_Logica:
	return _mesa

func iniciar_partida() -> Dictionary:
	var jogadores := _mesa.obter_jogadores()
	if jogadores.size() < 2:
		return _falha("jogadores_insuficientes", "A partida precisa de dois jogadores.")
	if jogadores.size() > 4:
		return _falha("limite_de_jogadores", "A partida aceita no máximo quatro jogadores.")
	if _mesa.obter_fase() == Mesa_Logica.Fase.EM_ANDAMENTO:
		return _falha("partida_em_andamento", "Já existe uma partida em andamento.")

	_mesa.preparar_nova_partida()
	var carta_inicial := _mesa.descartar_carta_inicial()
	if not carta_inicial:
		return _falha("baralho_indisponivel", "Não foi possível preparar o descarte inicial.")
	_mesa.iniciar_estado_partida()

	var jogador_atual := _mesa.obter_jogador_atual()
	var eventos: Array[Dictionary] = []
	eventos.append(_evento("PartidaIniciada", {
		"jogadores": _mesa.obter_estado_publico_jogadores(),
		"jogador_atual_id": jogador_atual.get_id(),
		"carta_topo": carta_inicial.para_dados(),
		"cartas_no_monte": _mesa.obter_quantidade_monte(),
		"pode_comprar": _mesa.pode_comprar_carta(),
		"compra_acumulada": _mesa.obter_compra_acumulada()
	}))
	for _rodada in range(CARTAS_POR_MAO_INICIAL):
		for jogador in jogadores:
			var carta := _mesa.comprar_carta_para_jogador(jogador.get_id())
			eventos.append(_evento_carta_recebida(jogador, carta, "inicial"))
	eventos.append(_evento("DistribuicaoConcluida"))
	return _sucesso(eventos)

func pode_jogar_carta(id_jogador: int, id_carta: int) -> bool:
	if _mesa.obter_fase() != Mesa_Logica.Fase.EM_ANDAMENTO:
		return false
	if _mesa.tem_escolha_pendente():
		return false
	if not _eh_a_vez(id_jogador):
		return false
	var carta := _mesa.obter_carta_do_jogador(id_jogador, id_carta)
	if not _carta_implementada(carta):
		return false
	if _mesa.obter_compra_acumulada() > 0:
		return _pode_rebater_compra(carta)
	if _mesa.comprou_neste_turno() and id_carta != _mesa.obter_carta_comprada_jogavel_id():
		return false
	return _validar_jogada(carta, _mesa.consultar_carta_descarte())

func jogar_carta(id_jogador: int, id_carta: int) -> Dictionary:
	var validacao := _validar_jogada_solicitada(id_jogador, id_carta)
	if not validacao["sucesso"]:
		return _falha(validacao["erro"], validacao["mensagem"])

	var carta := _mesa.descartar_carta_do_jogador_por_id(id_jogador, id_carta)
	if not carta:
		return _falha("carta_nao_encontrada", "A carta não está mais na mão do jogador.")

	var jogador := _mesa.consultar_jogador_por_id(id_jogador)
	var eventos: Array[Dictionary] = []
	eventos.append(_evento("CartaJogada", {
		"jogador_id": id_jogador,
		"carta": carta.para_dados(),
		"quantidade_cartas": jogador.retorna_quantidade_cartas()
	}))
	var efeitos := Efeitos_Api.new(_mesa)
	carta.aplicar_efeito(efeitos)
	eventos.append_array(_eventos_dos_efeitos(efeitos))
	if _mesa.tem_escolha_pendente():
		return _sucesso(eventos)
	return _concluir_jogada(eventos)

func comprar_carta(id_jogador: int) -> Dictionary:
	if _mesa.obter_fase() != Mesa_Logica.Fase.EM_ANDAMENTO:
		return _falha("partida_nao_em_andamento", "Não há uma partida em andamento.")
	if _mesa.tem_escolha_pendente():
		return _falha("escolha_cor_pendente", "Aguarde a escolha da cor.")
	var jogador := _mesa.consultar_jogador_por_id(id_jogador)
	if not jogador:
		return _falha("jogador_inexistente", "O jogador não pertence a esta partida.")
	if not _eh_a_vez(id_jogador):
		return _falha("fora_da_vez", "Só o jogador da vez pode comprar.")
	if _mesa.obter_compra_acumulada() > 0:
		return _falha("compra_acumulada_pendente", "Rebata a pilha ou compre as cartas acumuladas.")
	if _mesa.obter_carta_comprada_jogavel_id() > 0:
		return _falha("compra_concluida", "Jogue a carta comprada ou passe a vez.")
	if not _mesa.pode_comprar_carta():
		return _falha("monte_esgotado", "Não há cartas disponíveis para comprar.")

	var carta := _mesa.comprar_carta_para_jogador(id_jogador)
	if not carta:
		return _falha("monte_esgotado", "Não foi possível comprar uma carta.")
	var carta_jogavel := _carta_implementada(carta) and _validar_jogada(carta, _mesa.consultar_carta_descarte())
	_mesa.registrar_compra_no_turno(carta.get_id() if carta_jogavel else -1)
	var eventos: Array[Dictionary] = []
	eventos.append(_evento_carta_recebida(jogador, carta, "compra", {
		"carta_jogavel": carta_jogavel,
		"pode_comprar": _mesa.pode_comprar_carta()
	}))
	return _sucesso(eventos)

func aceitar_compra_acumulada(id_jogador: int) -> Dictionary:
	if _mesa.obter_fase() != Mesa_Logica.Fase.EM_ANDAMENTO:
		return _falha("partida_nao_em_andamento", "Não há uma partida em andamento.")
	if _mesa.tem_escolha_pendente():
		return _falha("escolha_cor_pendente", "Aguarde a escolha da cor.")
	var jogador := _mesa.consultar_jogador_por_id(id_jogador)
	if not jogador:
		return _falha("jogador_inexistente", "O jogador não pertence a esta partida.")
	if not _eh_a_vez(id_jogador):
		return _falha("fora_da_vez", "Só o jogador da vez pode comprar a pilha.")
	var quantidade_exigida := _mesa.obter_compra_acumulada()
	if quantidade_exigida <= 0:
		return _falha("sem_compra_acumulada", "Não há uma compra acumulada para aceitar.")

	var eventos: Array[Dictionary] = []
	eventos.append_array(_resolver_compra_acumulada(jogador))
	var proximo := _mesa.avancar_turno()
	eventos.append(_evento_turno_alterado(proximo))
	return _sucesso(eventos)

func _resolver_compra_acumulada(jogador: Jogador_Logico) -> Array[Dictionary]:
	var quantidade_exigida := _mesa.obter_compra_acumulada()
	var eventos: Array[Dictionary] = []
	for _indice in range(quantidade_exigida):
		var carta := _mesa.comprar_carta_para_jogador(jogador.get_id())
		if not carta:
			break
		eventos.append(_evento_carta_recebida(jogador, carta, "penalidade"))
	_mesa.zerar_compra_acumulada()
	eventos.append(_evento("CompraPenalidadeRealizada", {
		"jogador_id": jogador.get_id(),
		"quantidade_exigida": quantidade_exigida,
		"quantidade_comprada": eventos.size(),
		"quantidade_cartas": jogador.retorna_quantidade_cartas(),
		"cartas_no_monte": _mesa.obter_quantidade_monte()
	}))
	return eventos

func passar_vez(id_jogador: int) -> Dictionary:
	if _mesa.obter_fase() != Mesa_Logica.Fase.EM_ANDAMENTO:
		return _falha("partida_nao_em_andamento", "Não há uma partida em andamento.")
	if _mesa.tem_escolha_pendente():
		return _falha("escolha_cor_pendente", "Aguarde a escolha da cor.")
	if not _mesa.consultar_jogador_por_id(id_jogador):
		return _falha("jogador_inexistente", "O jogador não pertence a esta partida.")
	if not _eh_a_vez(id_jogador):
		return _falha("fora_da_vez", "Só o jogador da vez pode passar.")
	if _mesa.obter_compra_acumulada() > 0:
		return _falha("compra_acumulada_pendente", "Rebata a pilha ou compre as cartas acumuladas.")
	if _mesa.obter_carta_comprada_jogavel_id() <= 0 and _mesa.pode_comprar_carta():
		return _falha("compra_em_andamento", "Compre até encontrar uma carta jogável.")

	var proximo := _mesa.avancar_turno()
	var eventos: Array[Dictionary] = []
	eventos.append(_evento("TurnoPassado", {"jogador_id": id_jogador}))
	eventos.append(_evento_turno_alterado(proximo))
	return _sucesso(eventos)

func escolher_cor(id_jogador: int, nome_cor: String) -> Dictionary:
	if _mesa.obter_fase() != Mesa_Logica.Fase.EM_ANDAMENTO:
		return _falha("partida_nao_em_andamento", "Não há uma partida em andamento.")
	if _mesa.obter_jogador_escolhendo_cor_id() != id_jogador:
		return _falha("escolha_cor_nao_permitida", "Só quem jogou o coringa pode escolher a cor.")
	var cores := {
		"AZUL": Carta_Base.Cores.AZUL,
		"VERDE": Carta_Base.Cores.VERDE,
		"AMARELO": Carta_Base.Cores.AMARELO,
		"VERMELHO": Carta_Base.Cores.VERMELHO
	}
	if not cores.has(nome_cor):
		return _falha("cor_invalida", "Escolha uma das quatro cores disponíveis.")
	var cor: Carta_Base.Cores = cores[nome_cor]
	var id_carta := _mesa.obter_carta_aguardando_cor_id()
	var localizacao := _mesa.alterar_cor_carta(id_carta, cor)
	if localizacao.is_empty():
		return _falha("carta_nao_encontrada", "A carta que aguarda a escolha não foi encontrada.")
	_mesa.concluir_escolha_cor()
	var eventos: Array[Dictionary] = []
	if bool(localizacao["alterada"]):
		var evento_cor := _evento_cor_alterada(localizacao, id_carta, nome_cor)
		if not evento_cor.is_empty():
			eventos.append(evento_cor)
	return _concluir_jogada(eventos)

func escolher_alvo(id_jogador: int, id_alvo: int) -> Dictionary:
	if _mesa.obter_fase() != Mesa_Logica.Fase.EM_ANDAMENTO or _mesa.obter_jogador_escolhendo_alvo_id() != id_jogador:
		return _falha("escolha_alvo_nao_permitida", "Só quem jogou a carta pode escolher o adversário.")
	if id_alvo == id_jogador or not _mesa.consultar_jogador_por_id(id_alvo):
		return _falha("alvo_invalido", "Escolha outro jogador da mesa.")
	var efeitos := Efeitos_Api.new(_mesa)
	efeitos.trocar_maos_com(id_alvo)
	return _sucesso(_eventos_dos_efeitos(efeitos))

func _eventos_dos_efeitos(efeitos: Efeitos_Api) -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	for fato in efeitos.obter_fatos():
		var tipo := String(fato["tipo"])
		eventos.append(_evento(tipo, fato["publico"]))
		if tipo == "MaosTrocadas":
			eventos.append_array(_eventos_maos_atualizadas([int(fato["publico"]["jogador_id"]), int(fato["publico"]["alvo_id"])]))
	return eventos

func _concluir_jogada(eventos: Array[Dictionary]) -> Dictionary:
	var vencedor := _mesa.obter_jogador_sem_cartas()
	if vencedor:
		if _mesa.obter_compra_acumulada() > 0:
			var penalizado := _mesa.avancar_turno()
			eventos.append_array(_resolver_compra_acumulada(penalizado))
		_mesa.encerrar_partida()
		eventos.append(_evento("PartidaEncerrada", {
			"vencedor_id": vencedor.get_id(),
			"vencedor_nome": vencedor.get_nome()
		}))
	else:
		var proximo := _mesa.avancar_turno()
		eventos.append(_evento_turno_alterado(proximo))
	return _sucesso(eventos)

func _eventos_maos_atualizadas(ids: Array) -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	for jogador in _mesa.obter_jogadores():
		if not ids.has(jogador.get_id()):
			continue
		eventos.append(_evento("MaoAtualizada", {"jogador_id": jogador.get_id()}, jogador.get_id(), {
			"cartas": jogador.serializar_mao()
		}, true))
	return eventos

func _evento_cor_alterada(localizacao: Dictionary, id_carta: int, nome_cor: String) -> Dictionary:
	var publico := {"id_carta": id_carta, "cor": nome_cor}
	match String(localizacao["local"]):
		"mao":
			return _evento("CorDaCartaAlterada", publico, int(localizacao["jogador_id"]), {}, true)
		"descarte":
			return _evento("CorDaCartaAlterada", publico)
	return {}

func _obter_ids_jogaveis(id_jogador: int) -> Array[int]:
	var ids: Array[int] = []
	var jogador := _mesa.consultar_jogador_por_id(id_jogador)
	if not jogador:
		return ids
	for dados_carta in jogador.serializar_mao():
		var id_carta := int(dados_carta.get("id", -1))
		if pode_jogar_carta(id_jogador, id_carta):
			ids.append(id_carta)
	return ids

func _evento_carta_recebida(jogador: Jogador_Logico, carta: Carta_Base, origem: String, extras: Dictionary = {}) -> Dictionary:
	var publico := {
		"jogador_id": jogador.get_id(),
		"quantidade_cartas": jogador.retorna_quantidade_cartas(),
		"cartas_no_monte": _mesa.obter_quantidade_monte(),
		"origem": origem
	}
	publico.merge(extras)
	var privado := {"carta": carta.para_dados()}
	if origem != "penalidade":
		privado["ids_jogaveis"] = _obter_ids_jogaveis(jogador.get_id())
	return _evento("CartaRecebida", publico, jogador.get_id(), privado)

func _evento_turno_alterado(jogador: Jogador_Logico) -> Dictionary:
	return _evento("TurnoAlterado", {
		"jogador_id": jogador.get_id(),
		"nome": jogador.get_nome(),
		"pode_comprar": _mesa.pode_comprar_carta(),
		"compra_acumulada": _mesa.obter_compra_acumulada()
	}, jogador.get_id(), {"ids_jogaveis": _obter_ids_jogaveis(jogador.get_id())})

func _validar_jogada_solicitada(id_jogador: int, id_carta: int) -> Dictionary:
	if _mesa.obter_fase() != Mesa_Logica.Fase.EM_ANDAMENTO:
		return {"sucesso": false, "erro": "partida_nao_em_andamento", "mensagem": "Não há uma partida em andamento."}
	if _mesa.tem_escolha_pendente():
		return {"sucesso": false, "erro": "escolha_cor_pendente", "mensagem": "Aguarde a escolha da cor."}
	if not _mesa.consultar_jogador_por_id(id_jogador):
		return {"sucesso": false, "erro": "jogador_inexistente", "mensagem": "O jogador não pertence a esta partida."}
	if not _eh_a_vez(id_jogador):
		return {"sucesso": false, "erro": "fora_da_vez", "mensagem": "Só o jogador da vez pode jogar."}
	var carta := _mesa.obter_carta_do_jogador(id_jogador, id_carta)
	if not carta:
		return {"sucesso": false, "erro": "carta_nao_encontrada", "mensagem": "A carta não está na mão do jogador."}
	if not _carta_implementada(carta):
		return {"sucesso": false, "erro": "carta_fora_desta_etapa", "mensagem": "Esta carta ainda não foi implementada na partida."}
	if _mesa.obter_compra_acumulada() > 0:
		if _pode_rebater_compra(carta):
			return {"sucesso": true, "erro": "", "mensagem": ""}
		return {"sucesso": false, "erro": "compra_acumulada_pendente", "mensagem": "Rebata a pilha ou compre as cartas acumuladas."}
	if _mesa.comprou_neste_turno() and id_carta != _mesa.obter_carta_comprada_jogavel_id():
		return {"sucesso": false, "erro": "carta_nao_eh_a_comprada", "mensagem": "Após comprar, só é possível jogar a carta jogável recém-comprada."}
	if not _validar_jogada(carta, _mesa.consultar_carta_descarte()):
		return {"sucesso": false, "erro": "carta_nao_jogavel", "mensagem": "A carta precisa combinar em cor ou número com o descarte."}
	return {"sucesso": true, "erro": "", "mensagem": ""}

func _eh_a_vez(id_jogador: int) -> bool:
	var atual := _mesa.obter_jogador_atual()
	return atual != null and atual.get_id() == id_jogador

func _carta_implementada(carta: Carta_Base) -> bool:
	return carta is Carta_Numerica or carta is Carta_Especial or carta is Carta_Troca_Cor or carta is Carta_Compra_Quatro or carta is Carta_Troca_Mao

func _pode_rebater_compra(carta: Carta_Base) -> bool:
	var carta_topo := _mesa.consultar_carta_descarte()
	if carta is Carta_Compra_Dois:
		if carta_topo is Carta_Compra_Dois:
			return true
		if carta_topo is Carta_Compra_Quatro:
			return carta.get_cor() == carta_topo.get_cor()
	if carta is Carta_Compra_Quatro:
		return carta_topo is Carta_Compra_Quatro
	return false

func _validar_jogada(carta_jogada: Carta_Base, carta_topo: Carta_Base) -> bool:
	if not carta_jogada or not carta_topo:
		return false
	if carta_jogada is Carta_Compra_Quatro and carta_topo is Carta_Compra_Dois:
		return false
	if carta_jogada is Carta_Coringa:
		return true
	return carta_jogada.get_cor() == carta_topo.get_cor() or carta_jogada.valor == carta_topo.valor

func _evento(tipo: String, publico: Dictionary = {}, destinatario_id: int = -1, privado: Dictionary = {}, somente_destinatario: bool = false) -> Dictionary:
	return {
		"tipo": tipo,
		"publico": publico,
		"destinatario_id": destinatario_id,
		"privado": privado,
		"somente_destinatario": somente_destinatario
	}

func _sucesso(eventos: Array[Dictionary]) -> Dictionary:
	return {"sucesso": true, "erro": "", "mensagem": "", "eventos": eventos}

func _falha(codigo: String, mensagem: String) -> Dictionary:
	return {"sucesso": false, "erro": codigo, "mensagem": mensagem, "eventos": []}
