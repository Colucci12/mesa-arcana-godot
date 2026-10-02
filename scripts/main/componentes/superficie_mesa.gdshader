shader_type canvas_item;
render_mode unshaded;

uniform vec2 tamanho_plano = vec2(1000.0, 700.0);
uniform vec2 origem_captura = vec2(0.0);
uniform vec2 tamanho_captura = vec2(1000.0, 700.0);
uniform bool arredondada = false;
uniform vec2 dimensoes_tampo = vec2(1000.0, 700.0);
uniform float largura_moldura : hint_range(0.0, 120.0) = 36.0;
uniform bool mostrar_grade = false;
uniform vec4 cor_superficie : source_color = vec4(0.055, 0.20, 0.14, 1.0);
uniform vec4 cor_moldura : source_color = vec4(0.19, 0.105, 0.065, 1.0);

void fragment() {
	vec2 ponto = origem_captura + UV * tamanho_captura;
	vec2 raios = dimensoes_tampo * 0.5;
	vec2 local = ponto - tamanho_plano * 0.5;
	vec2 interior = max(raios - largura_moldura, vec2(0.001));
	float distancia = arredondada ? length(local / raios) : max(abs(local.x) / raios.x, abs(local.y) / raios.y);
	float aa = max(fwidth(distancia), 0.0001);
	float cobertura = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, distancia);
	if (cobertura <= 0.0) { discard; }
	bool moldura = arredondada ? length(local / interior) >= 1.0 : any(greaterThan(abs(local), interior));
	vec4 cor = moldura ? cor_moldura : cor_superficie;
	if (mostrar_grade && !moldura) {
		// Quadrados de 100 unidades no plano original, projetados com o tampo.
		vec2 distancia = abs(mod(ponto + 50.0, 100.0) - 50.0);
		vec2 suavidade = max(fwidth(ponto), vec2(0.5));
		vec2 linhas = 1.0 - smoothstep(vec2(0.7), vec2(0.7) + suavidade, distancia);
		cor.rgb = mix(cor.rgb, vec3(0.60, 0.70, 0.61), max(linhas.x, linhas.y) * 0.45);
	}
	COLOR = vec4(cor.rgb, cor.a * cobertura);
}
