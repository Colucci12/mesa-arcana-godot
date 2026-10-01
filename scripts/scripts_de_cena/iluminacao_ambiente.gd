@tool
extends Node
class_name IluminacaoAmbiente

signal parametros_alterados

@export_group("Foco da lâmpada")
# Controle principal: zero desliga o efeito em todas as superfícies registradas.
@export_range(0.0, 1.0, 0.01) var intensidade: float = 1.0:
	set(valor):
		intensidade = valor
		_atualizar_materiais()

@export var cor: Color = Color(1.0, 0.95, 0.86):
	set(valor):
		cor = valor
		_atualizar_materiais()

# Coordenadas relativas à tela: (0.5, 0.5) é o centro.
@export var posicao: Vector2 = Vector2(0.5, 0.47):
	set(valor):
		posicao = valor
		_atualizar_materiais()

# Raios horizontal e vertical em proporção ao menor lado da tela.
# Valores iguais formam um círculo; aumentar X alarga o oval.
@export var raio: Vector2 = Vector2(0.65, 0.41):
	set(valor):
		raio = valor
		_atualizar_materiais()

@export_range(0.05, 1.0, 0.01) var suavidade: float = 0.4:
	set(valor):
		suavidade = valor
		_atualizar_materiais()

# Deformação discreta e estática do oval; (0, 0) restaura o foco simétrico.
@export var assimetria: Vector2 = Vector2(0.07, -0.04):
	set(valor):
		assimetria = valor
		_atualizar_materiais()

@export_group("Brilho e temperatura")
# Intensidade dentro do foco: 1 mantém o brilho original dos objetos.
@export_range(0.5, 2.0, 0.01) var brilho_foco: float = 1.15:
	set(valor):
		brilho_foco = valor
		_atualizar_materiais()

# Brilho fora do oval: diminuir este valor aprofunda a escuridão do ambiente.
@export_range(0.0, 1.0, 0.01) var brilho_exterior: float = 0.18:
	set(valor):
		brilho_exterior = valor
		_atualizar_materiais()

# Mantém apenas uma leitura mínima das cartas na penumbra, sem iluminar as mãos.
@export_range(0.0, 1.0, 0.01) var brilho_minimo_cartas: float = 0.32:
	set(valor):
		brilho_minimo_cartas = valor
		_atualizar_materiais()

# A cor quente atua somente na área atingida pela lâmpada.
@export_range(0.0, 1.0, 0.01) var aquecimento: float = 0.16:
	set(valor):
		aquecimento = valor
		_atualizar_materiais()

# Reduz o estouro dos brancos e a coloração do papel, mantendo a tinta escura.
@export_range(0.0, 1.0, 0.01) var preservacao_cartas: float = 0.8:
	set(valor):
		preservacao_cartas = valor
		_atualizar_materiais()

@export_group("Sombras das cartas")
# Quanto mais longe do centro da lâmpada, maior o deslocamento da sombra.
@export_range(0.0, 40.0, 0.5) var comprimento_sombra: float = 18.0:
	set(valor):
		comprimento_sombra = valor
		_atualizar_materiais()

@export_group("Superfícies")
@export var superficies_mesa: Array[NodePath] = []
@export var objetos_mesa: Array[NodePath] = []

var _materiais: Array[Dictionary] = []


func _ready() -> void:
	_registrar_superficies(superficies_mesa, false)
	_registrar_superficies(objetos_mesa, true)


func aplicar_em(material_superficie: ShaderMaterial, objeto: bool = false) -> void:
	if material_superficie == null:
		return
	for indice in range(_materiais.size() - 1, -1, -1):
		var registro := _materiais[indice]
		var material_existente := registro["material"].get_ref() as ShaderMaterial
		if material_existente == null:
			_materiais.remove_at(indice)
			continue
		if material_existente == material_superficie:
			registro["objeto"] = objeto
			_configurar_material(material_superficie, objeto)
			return
	# Referências fracas permitem liberar as cartas retiradas da mesa normalmente.
	_materiais.append({"material": weakref(material_superficie), "objeto": objeto})
	_configurar_material(material_superficie, objeto)


func _registrar_superficies(caminhos: Array[NodePath], objeto: bool) -> void:
	for caminho in caminhos:
		var superficie := get_node_or_null(caminho) as CanvasItem
		if superficie:
			aplicar_em(superficie.material as ShaderMaterial, objeto)


func deslocamento_sombra_na_tela(centro_carta: Vector2, dimensoes_tela: Vector2) -> Vector2:
	var menor_lado := maxf(minf(dimensoes_tela.x, dimensoes_tela.y), 1.0)
	var distancia_lampada := (centro_carta - posicao * dimensoes_tela) / menor_lado
	return distancia_lampada * comprimento_sombra


func _atualizar_materiais() -> void:
	for indice in range(_materiais.size() - 1, -1, -1):
		var registro := _materiais[indice]
		var material_superficie := registro["material"].get_ref() as ShaderMaterial
		if material_superficie == null:
			_materiais.remove_at(indice)
			continue
		_configurar_material(material_superficie, registro["objeto"])
	parametros_alterados.emit()


func _configurar_material(material_superficie: ShaderMaterial, objeto: bool) -> void:
	material_superficie.set_shader_parameter("luz_intensidade", intensidade)
	material_superficie.set_shader_parameter("luz_cor", cor)
	material_superficie.set_shader_parameter("luz_posicao", posicao)
	material_superficie.set_shader_parameter("luz_raio", raio)
	material_superficie.set_shader_parameter("luz_suavidade", suavidade)
	material_superficie.set_shader_parameter("luz_assimetria", assimetria)
	material_superficie.set_shader_parameter("luz_brilho_foco", brilho_foco)
	var exterior := maxf(brilho_exterior, brilho_minimo_cartas) if objeto else brilho_exterior
	material_superficie.set_shader_parameter("luz_brilho_exterior", exterior)
	material_superficie.set_shader_parameter("luz_aquecimento", aquecimento)
	material_superficie.set_shader_parameter("luz_preservacao", preservacao_cartas if objeto else 0.0)
