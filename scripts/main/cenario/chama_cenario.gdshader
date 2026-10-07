shader_type canvas_item;
render_mode unshaded;

uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform vec4 quadros[8];
uniform vec2 bases[8];
uniform vec2 tamanho_quadro = vec2(240.0, 400.0);
uniform bool animada = true;
uniform bool suave = true;
uniform float velocidade = 8.0;
uniform float fase = 0.0;
uniform float quadro = 1.0;
uniform float brilho = 1.0;
varying vec2 ponto_local;

void vertex() {
	ponto_local = VERTEX;
}

vec4 amostrar_chama(sampler2D folha, vec2 tamanho_pixel, int indice, vec2 uv) {
	vec4 area = quadros[indice];
	vec2 pixel = bases[indice] + (uv - vec2(0.5, 1.0)) * tamanho_quadro;
	if (any(lessThan(pixel, vec2(0.0))) || any(greaterThanEqual(pixel, area.zw))) {
		return vec4(0.0);
	}
	vec4 cor = texture(folha, (area.xy + pixel) * tamanho_pixel);
	return vec4(cor.rgb * cor.a, cor.a);
}

void fragment() {
	vec3 p = vec3(ponto_local, 1.0);
	vec2 uv = vec2(dot(inversa_x, p), dot(inversa_y, p)) / dot(inversa_z, p);
	float tempo = animada ? mod(TIME * velocidade + fase * 0.08, 8.0) : clamp(quadro - 1.0, 0.0, 7.0);
	int atual = int(floor(tempo));
	vec4 cor = amostrar_chama(TEXTURE, TEXTURE_PIXEL_SIZE, atual, uv);
	if (animada && suave) {
		vec4 proxima = amostrar_chama(TEXTURE, TEXTURE_PIXEL_SIZE, (atual + 1) % 8, uv);
		// Misturar cores premultiplicadas evita franjas escuras na transparência.
		cor = mix(cor, proxima, smoothstep(0.0, 1.0, fract(tempo)));
	}
	COLOR = vec4(cor.a > 0.00001 ? cor.rgb / cor.a * brilho : vec3(0.0), cor.a);
}
