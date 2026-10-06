extends RefCounted

const FONTE = preload("res://images/BarlowCondensed-Bold.ttf")
const BOTOES = preload("res://images/UI/pack_botoes.png")
const DETALHES = preload("res://images/UI/pack_detalhes.png")
const ICONES = preload("res://images/UI/pack_icones.png")
const CREME := Color("#f5e9c8")
const OURO := Color("#d6af68")
const SUAVE := Color("#a7b8ad")


static func recorte(textura: Texture2D, regiao: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = regiao
	atlas.filter_clip = true
	return atlas


static func divisor() -> AtlasTexture:
	return recorte(DETALHES, Rect2(403, 212, 553, 91))


static func emblema() -> AtlasTexture:
	return recorte(DETALHES, Rect2(680, 728, 168, 190))


static func livro() -> AtlasTexture:
	return recorte(ICONES, Rect2(828, 196, 426, 446))


static func _botao(linha: int) -> StyleBoxTexture:
	var estilo := StyleBoxTexture.new()
	# Os quatro estados mantêm a mesma área útil e os motivos nas extremidades.
	var centros := [176.0, 422.0, 671.0, 916.0]
	var altura := 260.0 if linha == 1 else 240.0
	var textura := recorte(BOTOES, Rect2(75, centros[linha] - altura / 2.0, 1298, altura))
	if linha != 1:
		textura.margin = Rect2(0, 10, 0, 20)
	estilo.texture = textura
	estilo.content_margin_left = 44
	estilo.content_margin_right = 44
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	return estilo


static func _painel(cor: Color, borda: Color, margem: float = 20.0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.border_color = borda
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = margem
	estilo.content_margin_right = margem
	estilo.content_margin_top = margem
	estilo.content_margin_bottom = margem
	return estilo


static func tema() -> Theme:
	var resultado := Theme.new()
	resultado.default_font = FONTE
	resultado.default_font_size = 21
	resultado.set_color("font_color", "Label", CREME)
	resultado.set_color("default_color", "RichTextLabel", CREME)
	resultado.set_font("normal_font", "RichTextLabel", FONTE)
	resultado.set_font_size("normal_font_size", "RichTextLabel", 22)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		resultado.set_stylebox(estado, "Button", _botao(["normal", "hover", "pressed", "disabled"].find(estado)))
	resultado.set_stylebox("focus", "Button", _botao(1))
	for propriedade in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		resultado.set_color(propriedade, "Button", CREME)
	resultado.set_color("font_disabled_color", "Button", Color("#939489"))
	resultado.set_stylebox("panel", "PanelContainer", _painel(Color(0.014, 0.042, 0.047, 0.94), Color(0.70, 0.52, 0.26, 0.62)))
	resultado.set_stylebox("panel", "AcceptDialog", _painel(Color("#081e24"), OURO))
	resultado.set_stylebox("panel", "Window", _painel(Color("#081e24"), OURO))
	resultado.set_stylebox("normal", "LineEdit", _painel(Color("#0b262d"), Color("#46645d"), 8))
	resultado.set_stylebox("focus", "LineEdit", _painel(Color("#103039"), OURO, 8))
	resultado.set_stylebox("read_only", "LineEdit", _painel(Color("#10242a"), Color("#34433e"), 8))
	resultado.set_color("font_color", "LineEdit", CREME)
	resultado.set_color("font_placeholder_color", "LineEdit", SUAVE)
	resultado.set_color("caret_color", "LineEdit", OURO)
	resultado.set_color("selection_color", "LineEdit", Color("#315449"))
	resultado.set_constant("separation", "VBoxContainer", 10)
	resultado.set_constant("separation", "HBoxContainer", 12)
	resultado.set_type_variation("AbaMenu", "Button")
	resultado.set_stylebox("normal", "AbaMenu", _painel(Color("#102c32"), Color("#416056"), 10))
	resultado.set_stylebox("hover", "AbaMenu", _painel(Color("#21453f"), OURO, 10))
	resultado.set_stylebox("pressed", "AbaMenu", _painel(Color("#285347"), OURO, 10))
	resultado.set_stylebox("disabled", "AbaMenu", _painel(Color("#14262b"), Color("#34433e"), 10))
	resultado.set_stylebox("focus", "AbaMenu", _painel(Color(0, 0, 0, 0), OURO, 10))
	resultado.set_type_variation("VagaSala", "PanelContainer")
	resultado.set_stylebox("panel", "VagaSala", _painel(Color("#102b30"), Color(0.38, 0.48, 0.40, 0.6), 6))
	resultado.set_stylebox("panel", "PopupMenu", _painel(Color("#081e24"), OURO, 10))
	resultado.set_stylebox("hover", "PopupMenu", _painel(Color("#285347"), Color(0, 0, 0, 0), 4))
	resultado.set_color("font_color", "PopupMenu", CREME)
	resultado.set_color("font_hover_color", "PopupMenu", CREME)
	return resultado
