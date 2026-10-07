extends Node


const GRUPOS := {
	"deslizar": [preload("res://audio/cartas/card-slide-1.wav"), preload("res://audio/cartas/card-slide-2.wav"), preload("res://audio/cartas/card-slide-3.wav"), preload("res://audio/cartas/card-slide-4.wav")],
	"empurrar": [preload("res://audio/cartas/card-shove-1.wav"), preload("res://audio/cartas/card-shove-2.wav"), preload("res://audio/cartas/card-shove-3.wav"), preload("res://audio/cartas/card-shove-4.wav")],
	"retirar": [preload("res://audio/cartas/cards-pack-take-out-1.wav"), preload("res://audio/cartas/cards-pack-take-out-2.wav")]
}
const CONTINUOS := {
	"relogio": [preload("res://audio/ambiente/relogio.ogg")],
	"fogo": [preload("res://audio/fogo/fogo.ogg")],
	"musica": [preload("res://audio/musica/musica_fundo_2.ogg")]
}
const ACOES := {"compra": "Comprar carta", "jogar": "Retirar da mão", "pousar": "Chegar à mesa", "selecionar": "Selecionar na mão"}

var configuracao: Dictionary = padrao()
var _buses: Dictionary = {}
var _vozes: Array[AudioStreamPlayer] = []
var _acoes_vozes: Dictionary = {}
var _camadas: Dictionary = {}
var _ultimos: Dictionary = {}
var _aleatorio := RandomNumberGenerator.new()
var _ultima_selecao := -1000
var _vez_local := false


static func padrao() -> Dictionary:
	var cartas := {}
	var grupos := {"compra": "deslizar", "jogar": "empurrar", "pousar": "empurrar", "selecionar": "deslizar"}
	for acao in ACOES:
		cartas[acao] = {"ativo": acao != "pousar", "grupo": grupos[acao], "indice": 0, "variar": true,
			"volume": -22.0 if acao == "selecionar" else (-20.0 if acao == "jogar" else -14.0),
			"tom": 2.0, "variacao_volume": 0.7}
	return {"volume": -6.0, "volume_cartas": 0.0, "silencio": false, "cartas": cartas,
		"continuos": {"relogio": {"ativo": false, "indice": 0, "volume": -24.0, "repetir": true},
			"fogo": {"ativo": false, "indice": 0, "volume": -12.0, "repetir": true},
			"musica": {"ativo": false, "indice": 0, "volume": -22.0, "repetir": false}}}


static func variantes(acao: String, grupo: String) -> Array:
	var recursos: Array = GRUPOS.get(grupo, [])
	return recursos.slice(0, 4) if acao == "selecionar" and grupo == "deslizar" else recursos


static func validar(dados: Variant) -> Dictionary:
	var resultado := padrao()
	if not dados is Dictionary:
		return resultado
	for chave in ["volume", "volume_cartas"]:
		resultado[chave] = _numero(dados.get(chave), resultado[chave], -60, 0)
	if dados.get("silencio") is bool:
		resultado["silencio"] = dados["silencio"]
	var cartas: Variant = dados.get("cartas")
	if cartas is Dictionary:
		for acao in ACOES:
			var entrada: Variant = cartas.get(acao)
			if not entrada is Dictionary:
				continue
			var destino: Dictionary = resultado["cartas"][acao]
			if entrada.get("grupo") is String and GRUPOS.has(entrada["grupo"]):
				destino["grupo"] = entrada["grupo"]
			for chave in ["ativo", "variar"]:
				if entrada.get(chave) is bool:
					destino[chave] = entrada[chave]
			destino["indice"] = int(_numero(entrada.get("indice"), 0, 0, variantes(acao, destino["grupo"]).size() - 1))
			destino["volume"] = _numero(entrada.get("volume"), destino["volume"], -60, 0)
			destino["tom"] = _numero(entrada.get("tom"), destino["tom"], 0, 8)
			destino["variacao_volume"] = _numero(entrada.get("variacao_volume"), destino["variacao_volume"], 0, 3)
	var continuos: Variant = dados.get("continuos")
	if continuos is Dictionary:
		for chave in CONTINUOS:
			var entrada: Variant = continuos.get(chave)
			if not entrada is Dictionary:
				continue
			var destino: Dictionary = resultado["continuos"][chave]
			for opcao in ["ativo", "repetir"]:
				if entrada.get(opcao) is bool:
					destino[opcao] = entrada[opcao]
			destino["indice"] = int(_numero(entrada.get("indice"), 0, 0, CONTINUOS[chave].size() - 1))
			destino["volume"] = _numero(entrada.get("volume"), destino["volume"], -60, 0)
	return resultado


static func _numero(valor: Variant, base: float, minimo: float, maximo: float) -> float:
	if (valor is int or valor is float) and is_finite(float(valor)):
		return clampf(float(valor), minimo, maximo)
	return base


func _ready() -> void:
	_aleatorio.randomize()
	_criar_bus("geral", "Master")
	var limitador := AudioEffectHardLimiter.new()
	limitador.ceiling_db = -1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(_buses["geral"]), limitador)
	for chave in ["cartas", "relogio", "fogo", "musica"]:
		_criar_bus(chave, _buses["geral"])
	for indice in range(8):
		_vozes.append(_criar_player("cartas"))
	for chave in CONTINUOS:
		var a := _criar_player(chave)
		var b := _criar_player(chave)
		_camadas[chave] = {"players": [a, b], "frente": 0, "assinatura": "", "tween": null}
	aplicar(configuracao)


func _criar_bus(chave: String, envio: String) -> void:
	AudioServer.add_bus()
	var indice := AudioServer.bus_count - 1
	var nome := "JUNO_%d_%s" % [get_instance_id(), chave]
	AudioServer.set_bus_name(indice, nome)
	AudioServer.set_bus_send(indice, envio)
	_buses[chave] = nome


func _criar_player(chave: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	if OS.has_feature("web"):
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.bus = _buses[chave]
	add_child(player)
	return player


func aplicar(dados: Dictionary) -> void:
	configuracao = validar(dados)
	if _buses.is_empty():
		return
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(_buses["geral"]), configuracao["volume"])
	AudioServer.set_bus_mute(AudioServer.get_bus_index(_buses["geral"]), configuracao["silencio"])
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(_buses["cartas"]), configuracao["volume_cartas"])
	for chave in CONTINUOS:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(_buses[chave]), configuracao["continuos"][chave]["volume"])
		_atualizar_camada(chave)
	# Desligar uma ação interrompe também suas vozes que já estavam tocando.
	for player in _vozes:
		var acao: String = _acoes_vozes.get(player.get_instance_id(), "")
		if not acao.is_empty() and not bool(configuracao["cartas"][acao]["ativo"]):
			player.stop()


func tocar(acao: String) -> void:
	if not ACOES.has(acao):
		return
	var ajustes: Dictionary = configuracao["cartas"][acao]
	if not bool(ajustes["ativo"]):
		return
	if acao == "selecionar":
		var agora := Time.get_ticks_msec()
		if agora - _ultima_selecao < 70:
			return
		_ultima_selecao = agora
	var grupo: String = ajustes["grupo"]
	var recursos := variantes(acao, grupo)
	var indice := int(ajustes["indice"])
	if bool(ajustes["variar"]) and recursos.size() > 1:
		# Sortear entre as alternativas evita repetir a mesma variante consecutivamente.
		var anterior := int(_ultimos.get(grupo, -1))
		if anterior >= recursos.size():
			anterior = -1
		indice = _aleatorio.randi_range(0, recursos.size() - 2 if anterior >= 0 else recursos.size() - 1)
		if anterior >= 0 and indice >= anterior:
			indice += 1
		_ultimos[grupo] = indice
	var player: AudioStreamPlayer = _voz_livre(acao)
	player.stop()
	player.bus = _buses["cartas"]
	player.stream = recursos[indice]
	player.pitch_scale = 1.0 + _aleatorio.randf_range(-float(ajustes["tom"]), float(ajustes["tom"])) / 100.0
	player.volume_db = float(ajustes["volume"]) + _aleatorio.randf_range(-float(ajustes["variacao_volume"]), float(ajustes["variacao_volume"]))
	player.play()


func _voz_livre(acao: String) -> AudioStreamPlayer:
	# A seleção rápida reutiliza sua voz; compras e chegadas podem se sobrepor.
	if acao == "selecionar":
		for player in _vozes:
			if player.playing and _acoes_vozes.get(player.get_instance_id()) == acao:
				return player
	for player in _vozes:
		if not player.playing:
			_acoes_vozes[player.get_instance_id()] = acao
			return player
	var player: AudioStreamPlayer = _vozes.pop_front()
	_vozes.append(player)
	_acoes_vozes[player.get_instance_id()] = acao
	return player


func _stream_continuo(chave: String, repetir: bool) -> AudioStreamOggVorbis:
	var ajustes: Dictionary = configuracao["continuos"][chave]
	var original: AudioStreamOggVorbis = CONTINUOS[chave][int(ajustes["indice"])]
	var stream := original.duplicate() as AudioStreamOggVorbis
	stream.set_meta("arquivo", original.resource_path.get_file())
	stream.loop = repetir
	return stream


func _atualizar_camada(chave: String) -> void:
	var ajustes: Dictionary = configuracao["continuos"][chave]
	var camada: Dictionary = _camadas[chave]
	if chave == "relogio" and not _vez_local:
		# Fora da vez, não deixar a transição prolongar o tique-taque.
		camada["assinatura"] = ""
		var transicao: Tween = camada["tween"]
		if transicao != null and transicao.is_valid():
			transicao.kill()
		for player in camada["players"]:
			player.stop()
		return
	var assinatura := "%d/%s" % [int(ajustes["indice"]), str(ajustes["repetir"])] if bool(ajustes["ativo"]) else ""
	if assinatura == camada["assinatura"]:
		return
	camada["assinatura"] = assinatura
	var anterior: Tween = camada["tween"]
	if anterior != null and anterior.is_valid():
		anterior.kill()
	var tween := create_tween().set_parallel(true)
	camada["tween"] = tween
	var frente := int(camada["frente"])
	var nova := 1 - frente
	for indice in range(2):
		var player: AudioStreamPlayer = camada["players"][indice]
		if indice == nova and not assinatura.is_empty():
			player.stop()
			player.stream = _stream_continuo(chave, bool(ajustes["repetir"]))
			player.volume_linear = 0.0
			player.play()
			tween.tween_property(player, "volume_linear", 1.0, 0.4)
		else:
			tween.tween_property(player, "volume_linear", 0.0, 0.4)
			tween.tween_callback(player.stop).set_delay(0.4)
	if not assinatura.is_empty():
		camada["frente"] = nova


func definir_vez_local(ativa: bool) -> void:
	if _vez_local == ativa:
		return
	_vez_local = ativa
	if _camadas.has("relogio"):
		_atualizar_camada("relogio")


func _parar_efeitos() -> void:
	for player in _vozes:
		player.stop()


func suspender_reproducao() -> void:
	# Sair da partida interrompe imediatamente, sem mudar a mixagem escolhida.
	_parar_efeitos()
	for camada in _camadas.values():
		var tween: Tween = camada["tween"]
		if tween != null and tween.is_valid():
			tween.kill()
		camada["tween"] = null
		camada["assinatura"] = ""
		for player: AudioStreamPlayer in camada["players"]:
			player.stop()


func _exit_tree() -> void:
	# Buses pertencem a esta instância; sair da partida libera seus canais.
	var chaves: Array = _buses.keys()
	chaves.reverse()
	for chave in chaves:
		var indice := AudioServer.get_bus_index(_buses[chave])
		if indice > 0:
			AudioServer.remove_bus(indice)
