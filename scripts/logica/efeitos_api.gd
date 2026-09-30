extends RefCounted
class_name Efeitos_Api

var _mesa: Mesa_Logica
var _fatos: Array[Dictionary] = []

func _init(p_mesa: Mesa_Logica) -> void:
	_mesa = p_mesa

func acumular_compra(quantidade: int) -> void:
	_mesa.adicionar_compra_acumulada(quantidade)
	_fatos.append({
		"tipo": "CompraAcumulada",
		"publico": {
			"acrescimo": quantidade,
			"quantidade": _mesa.obter_compra_acumulada()
		}
	})

func pular_turno() -> void:
	var jogador_pulado := _mesa.pular_proximo_jogador()
	_fatos.append({
		"tipo": "TurnoPulado",
		"publico": {
			"jogador_id": jogador_pulado.get_id(),
			"nome": jogador_pulado.get_nome()
		}
	})

func inverter_ordem() -> void:
	_mesa.inverter_ordem_jogadores()
	_fatos.append({"tipo": "SentidoInvertido", "publico": {}})
	if _mesa.obter_jogadores().size() == 2:
		pular_turno()

func obter_fatos() -> Array[Dictionary]:
	var fatos: Array[Dictionary] = []
	fatos.assign(_fatos)
	return fatos

func solicitar_escolha_cor() -> void:
	var jogador := _mesa.solicitar_escolha_cor()
	_fatos.append({
		"tipo": "EscolhaCorSolicitada",
		"publico": {
			"jogador_id": jogador.get_id(),
			"nome": jogador.get_nome(),
			"cores_disponiveis": ["AZUL", "VERDE", "AMARELO", "VERMELHO"]
		}
	})

func solicitar_troca_de_mao() -> void:
	pass
