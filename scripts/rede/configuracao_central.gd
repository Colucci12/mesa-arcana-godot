extends RefCounted

const ARQUIVO := "res://config/rede.cfg"


static func ler() -> ConfigFile:
	var configuracao := ConfigFile.new()
	configuracao.load(ARQUIVO)
	return configuracao


static func url_cliente() -> String:
	var url := OS.get_environment("JUNO_SERVIDOR_URL").strip_edges()
	if url.is_empty():
		url = str(ler().get_value("cliente", "url", "")).strip_edges()
	if url.is_empty() and OS.has_feature("web"):
		url = str(Engine.get_singleton("JavaScriptBridge").call("eval", "(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/multiplayer'"))
	return "ws://127.0.0.1:9080" if url.is_empty() else url


static func numero_servidor(chave: String, variavel: String, padrao: int, minimo: int, maximo: int) -> int:
	var texto := OS.get_environment(variavel)
	return clampi(int(texto) if texto.is_valid_int() else int(ler().get_value("servidor", chave, padrao)), minimo, maximo)


static func endereco_servidor() -> String:
	var endereco := OS.get_environment("JUNO_BIND").strip_edges()
	return str(ler().get_value("servidor", "endereco", "*")) if endereco.is_empty() else endereco


static func pagina_segura() -> bool:
	return OS.has_feature("web") and str(Engine.get_singleton("JavaScriptBridge").call("eval", "location.protocol")) == "https:"
