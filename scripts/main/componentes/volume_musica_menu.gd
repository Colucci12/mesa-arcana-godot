extends Control

const TEMA = preload("res://scripts/main/componentes/tema_menu.gd")

@onready var _botao: Button = $Botao
@onready var _painel: PanelContainer = $Painel
@onready var _volume: HSlider = $Painel/Conteudo/Volume
@onready var _percentual: Label = $Painel/Conteudo/Legenda/Percentual


func _ready() -> void:
	theme = TEMA.tema()
	_botao.toggled.connect(_alternar_painel)
	_volume.value_changed.connect(_alterar_volume)
	GameManager.volume_musica_menu_alterado.connect(_atualizar_volume)
	_atualizar_volume(GameManager.obter_volume_musica_menu())


func _alternar_painel(aberto: bool) -> void:
	_painel.visible = aberto
	if aberto:
		_volume.grab_focus()


func fechar_painel() -> void:
	_painel.hide()
	_botao.set_pressed_no_signal(false)


func _alterar_volume(valor: float) -> void:
	GameManager.definir_volume_musica_menu(valor / 100.0)


func _atualizar_volume(volume: float) -> void:
	var percentual := roundi(volume * 100.0)
	_volume.set_value_no_signal(percentual)
	_percentual.text = "%d%%" % percentual
	_botao.tooltip_text = "Volume da música: %d%%. Clique para ajustar." % percentual


func _input(evento: InputEvent) -> void:
	if not _painel.is_visible_in_tree():
		return
	if evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		fechar_painel()
		_botao.grab_focus()
		get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton and evento.pressed:
		var ponto := get_global_mouse_position()
		if not _painel.get_global_rect().has_point(ponto) and not _botao.get_global_rect().has_point(ponto):
			fechar_painel()
