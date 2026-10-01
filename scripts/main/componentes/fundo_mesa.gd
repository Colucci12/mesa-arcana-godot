@tool
extends ColorRect

@export_group("Iluminação")
@export var cor_base: Color = Color("#0C382C"):
	set(valor):
		cor_base = valor
		_atualizar_material()

@export var cor_iluminada: Color = Color("#174A3A"):
	set(valor):
		cor_iluminada = valor
		_atualizar_material()

@export_range(0.0, 1.0, 0.01) var intensidade: float = 0.65:
	set(valor):
		intensidade = valor
		_atualizar_material()

@export_range(0.3, 2.0, 0.01) var extensao: float = 0.9:
	set(valor):
		extensao = valor
		_atualizar_material()

@export_group("Textura do feltro")
# Controle principal do grão e da variação do feltro; zero desliga a textura.
@export_range(0.0, 0.2, 0.005) var intensidade_textura: float = 0.0:
	set(valor):
		intensidade_textura = valor
		_atualizar_material()

# Valores maiores aumentam o tamanho dos detalhes, sem mudar sua intensidade.
@export_range(0.5, 4.0, 0.05) var escala_textura: float = 1.0:
	set(valor):
		escala_textura = valor
		_atualizar_material()

# Manchas amplas e muito discretas; zero mantém apenas o grão do feltro.
@export_range(0.0, 0.05, 0.001) var intensidade_manchas: float = 0.0:
	set(valor):
		intensidade_manchas = valor
		_atualizar_material()


func _ready() -> void:
	material = material.duplicate()
	resized.connect(_atualizar_material)
	_atualizar_material()


func _atualizar_material() -> void:
	if not is_inside_tree() or material == null:
		return
	var fundo_material := material as ShaderMaterial
	fundo_material.set_shader_parameter("cor_base", cor_base)
	fundo_material.set_shader_parameter("cor_iluminada", cor_iluminada)
	fundo_material.set_shader_parameter("intensidade", intensidade)
	fundo_material.set_shader_parameter("extensao", extensao)
	fundo_material.set_shader_parameter("dimensoes", size)
	fundo_material.set_shader_parameter("intensidade_textura", intensidade_textura)
	fundo_material.set_shader_parameter("escala_textura", escala_textura)
	fundo_material.set_shader_parameter("intensidade_manchas", intensidade_manchas)
