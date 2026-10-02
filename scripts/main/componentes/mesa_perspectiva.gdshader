shader_type canvas_item;
render_mode unshaded;

uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform vec2 origem_retangulo;
uniform vec2 tamanho_plano = vec2(1000.0, 700.0);
uniform vec2 origem_captura = vec2(0.0);
uniform vec2 tamanho_captura = vec2(1000.0, 700.0);
varying vec2 ponto_projetado;

void vertex() {
	ponto_projetado = VERTEX + origem_retangulo;
}

void fragment() {
	vec3 ponto = vec3(ponto_projetado, 1.0);
	float denominador = dot(inversa_z, ponto);
	if (denominador <= 0.000001) { discard; }
	vec2 mundo = vec2(dot(inversa_x, ponto), dot(inversa_y, ponto)) / denominador * tamanho_plano;
	vec2 origem = (mundo - origem_captura) / tamanho_captura;
	if (any(lessThan(origem, vec2(0.0))) || any(greaterThan(origem, vec2(1.0)))) {
		discard;
	}
	COLOR = texture(TEXTURE, origem);
}
