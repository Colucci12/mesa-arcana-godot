extends Node

const CENA_MESA = preload("res://scenes/mesa_partida.tscn")

var _mesa_api: Mesa_Api
var _tela: TelaMesa

func _ready() -> void:
	var mesa := Mesa_Logica.new()
	_mesa_api = Mesa_Api.new(mesa)
	mesa.adicionar_jogador(1, "Você")
	mesa.adicionar_jogador(2, "Oponente")
	_tela = CENA_MESA.instantiate() as TelaMesa
	_tela.id_jogador_local = 1
	add_child(_tela)
	_tela.comando_solicitado.connect(_ao_receber_comando)
	_aplicar_resultado(_mesa_api.iniciar_partida())

func _ao_receber_comando(comando: StringName, dados: Dictionary) -> void:
	var resultado: Dictionary
	match comando:
		&"jogar_carta":
			resultado = _mesa_api.jogar_carta(1, int(dados.get("id_carta", -1)))
		&"comprar_carta":
			resultado = _mesa_api.comprar_carta(1)
		&"aceitar_compra_acumulada":
			resultado = _mesa_api.aceitar_compra_acumulada(1)
		&"passar_vez":
			resultado = _mesa_api.passar_vez(1)
		&"escolher_cor":
			resultado = _mesa_api.escolher_cor(1, String(dados.get("cor", "")))
		_:
			return
	_aplicar_resultado(resultado)

func _aplicar_resultado(resultado: Dictionary) -> void:
	if resultado["sucesso"]:
		var eventos_visiveis: Array[Dictionary] = []
		for evento in resultado["eventos"]:
			var evento_visivel := VisibilidadeEventos.para_jogador(evento, 1)
			if not evento_visivel.is_empty():
				eventos_visiveis.append(evento_visivel)
		_tela.aplicar_eventos(eventos_visiveis)
	else:
		_tela.mostrar_erro(resultado["mensagem"])
