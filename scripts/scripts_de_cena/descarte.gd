extends Control
class_name DescarteVisual

const COR_PONTILHADO = Color(0.88, 0.94, 0.81, 0.65)
const DESLOCAMENTOS = [Vector2.ZERO, Vector2(4, -3), Vector2(-4, 2), Vector2(2, 4)]
const ROTACOES = [0.0, 5.0, -4.0, 2.0]

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var margem := 7.0
	var direita := size.x - margem
	var abaixo := size.y - margem
	for x in range(int(margem), int(direita) + 1, 12):
		draw_circle(Vector2(x, margem), 1.8, COR_PONTILHADO)
		draw_circle(Vector2(x, abaixo), 1.8, COR_PONTILHADO)
	for y in range(int(margem), int(abaixo) + 1, 12):
		draw_circle(Vector2(margem, y), 1.8, COR_PONTILHADO)
		draw_circle(Vector2(direita, y), 1.8, COR_PONTILHADO)

func receber_carta(carta: Carta) -> void:
	carta.reparent(self, true)
	carta.state = false
	carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carta.verso = false
	var indice := get_child_count() - 1
	var posicao_central := (size - Carta.SIZE) / 2.0
	var deslocamento: Vector2 = DESLOCAMENTOS[indice % DESLOCAMENTOS.size()]
	var rotacao: float = ROTACOES[indice % ROTACOES.size()]
	carta.reposicionar(posicao_central + deslocamento, rotacao)

func alterar_cor_carta(id_carta: int, cor: Carta_Base.Cores) -> void:
	for filho in get_children():
		var carta := filho as Carta
		if carta and carta.id_carta == id_carta:
			carta.alterar_cor_visual(cor)
			return

func limpar() -> void:
	for carta in get_children():
		remove_child(carta)
		carta.queue_free()

