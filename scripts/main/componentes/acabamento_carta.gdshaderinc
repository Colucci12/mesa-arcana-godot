// Acabamento da impressão; intensidades zeradas mantêm a arte original.
uniform float acabamento_claros : hint_range(0.0, 0.05) = 0.0;
uniform float acabamento_tinta : hint_range(0.0, 0.08) = 0.0;
uniform float acabamento_variacao_tinta : hint_range(0.0, 0.15) = 0.0;
uniform float acabamento_escala_variacao : hint_range(4.0, 48.0) = 18.0;

float hash_impressao(vec2 amostra_cobertura) {
	return fract(sin(dot(amostra_cobertura, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 pesos_cobertura(float fracao_peso) {
	float quadrado_peso = fracao_peso * fracao_peso;
	float cubo_peso = quadrado_peso * fracao_peso;
	float complemento_peso = 1.0 - fracao_peso;
	return vec4(
		complemento_peso * complemento_peso * complemento_peso,
		3.0 * cubo_peso - 6.0 * quadrado_peso + 4.0,
		-3.0 * cubo_peso + 3.0 * quadrado_peso + 3.0 * fracao_peso + 1.0,
		cubo_peso
	) / 6.0;
}

float ruido_cobertura(vec2 ponto_cobertura) {
	vec2 celula_cobertura = floor(ponto_cobertura);
	vec2 fracao_cobertura = fract(ponto_cobertura);
	vec4 pesos_horizontal = pesos_cobertura(fracao_cobertura.x);
	vec4 pesos_vertical = pesos_cobertura(fracao_cobertura.y);
	float cobertura_suave = 0.0;
	// B-spline: mistura 16 vizinhos, sem achatar a transição nas divisões da grade.
	for (int linha_cobertura = 0; linha_cobertura < 4; linha_cobertura++) {
		for (int coluna_cobertura = 0; coluna_cobertura < 4; coluna_cobertura++) {
			vec2 vizinho_cobertura = celula_cobertura + vec2(float(coluna_cobertura - 1), float(linha_cobertura - 1));
			float peso_cobertura = pesos_horizontal[coluna_cobertura] * pesos_vertical[linha_cobertura];
			cobertura_suave += hash_impressao(vizinho_cobertura) * peso_cobertura;
		}
	}
	return cobertura_suave;
}

vec3 aplicar_acabamento_carta(vec3 cor_impressa, vec2 uv_impressao, vec2 dimensoes_impressao) {
	// Grão preso aos pixels da arte, sem movimento ou alteração da silhueta.
	vec2 pixel_impressao = floor(uv_impressao * dimensoes_impressao);
	float amostra_impressao = hash_impressao(pixel_impressao);
	float grao_impressao = amostra_impressao * 2.0 - 1.0;
	float clareza_impressao = min(cor_impressa.r, min(cor_impressa.g, cor_impressa.b));
	float mascara_claros = smoothstep(0.75, 0.95, clareza_impressao);
	float variacao_impressao = mix(acabamento_tinta, acabamento_claros, mascara_claros);
	// A cobertura usa coordenadas contínuas para não formar degraus entre os pixels.
	// O grão continua pixelado, mas a transição entre regiões de tinta fica suave.
	vec2 posicao_cobertura = uv_impressao * dimensoes_impressao / max(acabamento_escala_variacao, 1.0) + vec2(11.0, 29.0);
	float cobertura_impressao = ruido_cobertura(posicao_cobertura) * 2.0 - 1.0;
	// A variação ampla fica na tinta, protegendo as áreas claras e os números brancos.
	float variacao_cobertura = acabamento_variacao_tinta * cobertura_impressao * (1.0 - mascara_claros);
	float brilho_impressao = 1.0 + variacao_impressao * grao_impressao + variacao_cobertura;
	return clamp(cor_impressa * brilho_impressao, vec3(0.0), vec3(1.0));
}
