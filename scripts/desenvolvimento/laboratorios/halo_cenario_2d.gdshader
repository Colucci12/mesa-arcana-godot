shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 raios = vec2(60.0);
uniform vec4 cor : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float intensidade = 0.3;
varying vec2 ponto;

void vertex() {
	ponto = VERTEX / raios;
}

void fragment() {
	float distancia = length(ponto);
	float halo = exp(-4.5 * dot(ponto, ponto)) * (1.0 - smoothstep(0.65, 1.0, distancia));
	COLOR = vec4(cor.rgb, halo * intensidade);
}
