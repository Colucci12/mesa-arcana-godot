extends RefCounted
class_name VisibilidadeEventos

static func para_jogador(evento: Dictionary, id_jogador: int) -> Dictionary:
	var destinatario_id := int(evento.get("destinatario_id", -1))
	if bool(evento.get("somente_destinatario", false)) and destinatario_id != id_jogador:
		return {}
	return {
		"tipo": evento.get("tipo", ""),
		"publico": evento.get("publico", {}),
		"destinatario_id": destinatario_id,
		"privado": evento.get("privado", {}) if destinatario_id == id_jogador else {}
	}
