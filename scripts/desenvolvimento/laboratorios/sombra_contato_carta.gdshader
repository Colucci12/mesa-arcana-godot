shader_type canvas_item;
render_mode unshaded;

uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform vec4 regiao_textura;
uniform float intensidade = 0.0;
varying vec2 ponto_projetado;

void vertex() {
	ponto_projetado = VERTEX;
}

void fragment() {
	vec3 ponto = vec3(ponto_projetado, 1.0);
	float denominador = dot(inversa_z, ponto);
	if (abs(denominador) < 0.000001) { discard; }
	vec2 origem = vec2(dot(inversa_x, ponto), dot(inversa_y, ponto)) / denominador;
	if (any(lessThan(origem, vec2(0.0))) || any(greaterThan(origem, vec2(1.0)))) { discard; }
	float alpha = texture(TEXTURE, regiao_textura.xy + origem * regiao_textura.zw).a;
	COLOR = vec4(0.0, 0.0, 0.0, alpha * intensidade);
}
