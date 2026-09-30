extends Node
class_name BarramentoEventos

signal comando_solicitado(comando: StringName, dados: Dictionary)
signal evento_partida(evento: Dictionary)
signal erro_comando(mensagem: String)
signal identidade_definida(id_jogador: int)
signal estado_conexao(mensagem: String, permitir_nova_tentativa: bool)
