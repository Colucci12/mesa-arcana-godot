// Sem registro na lâmpada da mesa, o material mantém sua aparência original.
uniform float luz_intensidade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 luz_cor : source_color = vec4(1.0, 0.95, 0.86, 1.0);
uniform vec2 luz_posicao = vec2(0.5, 0.47);
uniform vec2 luz_raio = vec2(0.65, 0.41);
uniform float luz_suavidade : hint_range(0.05, 1.0) = 0.4;
uniform float luz_brilho_foco : hint_range(0.5, 2.0) = 1.15;
uniform float luz_brilho_exterior : hint_range(0.0, 1.0) = 0.18;
uniform float luz_aquecimento : hint_range(0.0, 1.0) = 0.16;
uniform vec2 luz_assimetria = vec2(0.0);
uniform float luz_preservacao : hint_range(0.0, 1.0) = 0.0;

float calcular_foco_luz(vec2 posicao_tela, vec2 tamanho_pixel) {
	vec2 dimensoes_foco = vec2(1.0) / tamanho_pixel;
	vec2 proporcao_foco = dimensoes_foco / min(dimensoes_foco.x, dimensoes_foco.y);
	vec2 raios_seguros = max(luz_raio, vec2(0.001));
	vec2 coordenadas_foco = (posicao_tela - luz_posicao) * proporcao_foco / raios_seguros;
	// Curvatura ampla, sem ruído ou textura, para quebrar a simetria perfeita.
	vec2 deformacao_foco = clamp(luz_assimetria, vec2(-0.25), vec2(0.25));
	coordenadas_foco += deformacao_foco * coordenadas_foco.yx * coordenadas_foco.yx;
	float distancia_foco = length(coordenadas_foco);
	// A luz perde força desde o centro, evitando um interior de brilho uniforme.
	float atenuacao_foco = 1.0 / (1.0 + distancia_foco * distancia_foco);
	// A suavidade continua controlando o encontro do foco com a penumbra.
	float inicio_transicao = 1.0 - clamp(luz_suavidade, 0.05, 1.0);
	float borda_foco = 1.0 - smoothstep(inicio_transicao, 1.0, distancia_foco);
	return atenuacao_foco * borda_foco;
}

vec3 aplicar_iluminacao_ambiente(vec3 cor_original, vec2 posicao_tela, vec2 tamanho_pixel) {
	float alcance = calcular_foco_luz(posicao_tela, tamanho_pixel);
	// Brilhos interno e externo são independentes da temperatura da lâmpada.
	float brilho = mix(luz_brilho_exterior, luz_brilho_foco, alcance);
	vec3 temperatura = mix(vec3(1.0), luz_cor.rgb, luz_aquecimento * alcance);
	vec3 resultado_luz = cor_original * brilho * temperatura;
	// O ganho nos meios-tons diminui ao se aproximar do branco, sem levantar o preto.
	vec3 pigmento_luz = clamp(cor_original, vec3(0.0), vec3(1.0));
	vec3 resposta_papel = pigmento_luz * min(brilho, 1.0);
	resposta_papel += max(brilho - 1.0, 0.0) * pigmento_luz * (vec3(1.0) - pigmento_luz);
	float clareza_papel = dot(pigmento_luz, vec3(0.2126, 0.7152, 0.0722));
	float protecao_papel = 0.8 * smoothstep(0.65, 1.0, clareza_papel);
	vec3 temperatura_papel = mix(vec3(1.0), temperatura, 1.0 - protecao_papel);
	resultado_luz = mix(resultado_luz, resposta_papel * temperatura_papel, luz_preservacao);
	// Multiplicar preserva os pretos e o contraste; o alfa permanece inalterado.
	return mix(cor_original, resultado_luz, luz_intensidade);
}
