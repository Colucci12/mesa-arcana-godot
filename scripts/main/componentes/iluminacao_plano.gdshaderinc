// Desligada por padrão: apenas o laboratório registra seus materiais.
uniform bool iluminacao_ativa = false;
uniform bool iluminacao_cartas = false;
uniform vec3 iluminacao_inversa_x;
uniform vec3 iluminacao_inversa_y;
uniform vec3 iluminacao_inversa_z;
uniform vec2 iluminacao_centro = vec2(0.5, 0.5);
uniform float iluminacao_ambiente = 0.60;
uniform float iluminacao_minimo_cartas : hint_range(0.0, 1.0) = 0.72;
uniform float iluminacao_intensidade = 0.55;
uniform float iluminacao_abrangencia = 1.0;
uniform float iluminacao_temperatura = 0.15;

vec3 iluminar_plano(vec3 original, vec2 posicao_canvas) {
	if (!iluminacao_ativa) { return original; }
	vec3 ponto = vec3(posicao_canvas, 1.0);
	float denominador = dot(iluminacao_inversa_z, ponto);
	float foco = 0.0;
	if (denominador > 0.00001) {
		vec2 mesa = vec2(dot(iluminacao_inversa_x, ponto), dot(iluminacao_inversa_y, ponto)) / denominador;
		vec2 distancia = (mesa - iluminacao_centro) / (vec2(0.70, 0.90) * iluminacao_abrangencia);
		foco = exp(-2.0 * dot(distancia, distancia));
	}
	float brilho = iluminacao_ambiente + iluminacao_intensidade * foco;
	vec3 temperatura = mix(vec3(1.0), vec3(1.0, 0.90, 0.74), iluminacao_temperatura * foco);
	if (iluminacao_cartas) {
		// Preservar leitura, papel e pretos também durante as transferências.
		brilho = max(brilho, iluminacao_minimo_cartas);
		vec3 pigmento = clamp(original, vec3(0.0), vec3(1.0));
		vec3 papel = pigmento * min(brilho, 1.0);
		papel += max(brilho - 1.0, 0.0) * pigmento * (vec3(1.0) - pigmento);
		float clareza = dot(pigmento, vec3(0.2126, 0.7152, 0.0722));
		temperatura = mix(temperatura, vec3(1.0), 0.8 * smoothstep(0.65, 1.0, clareza));
		return papel * temperatura;
	}
	return original * brilho * temperatura;
}
