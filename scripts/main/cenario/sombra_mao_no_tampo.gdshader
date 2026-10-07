shader_type canvas_item;
render_mode unshaded;

uniform vec3 inversa_x;
uniform vec3 inversa_y;
uniform vec3 inversa_z;
uniform vec3 mesa_x;
uniform vec3 mesa_y;
uniform vec3 mesa_z;
uniform vec4 regiao_textura;
uniform vec3 altura_plano;
uniform vec2 tamanho_captura;
uniform vec2 margem_feltro;
uniform bool mesa_arredondada = false;
uniform vec2 raios_feltro = vec2(0.5);
uniform float intensidade = 0.30;
uniform float suavidade = 2.0;
uniform float suavidade_por_altura = 0.035;
uniform bool fonte_localizada = true;
uniform float altura_fonte = 700.0;
varying vec2 ponto_projetado;

void vertex() {
	ponto_projetado = VERTEX;
}

float silhueta(sampler2D atlas, vec2 uv) {
	// Cada amostra fica dentro da célula: não captura cartas das outras mãos.
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	vec2 pixel = regiao_textura.zw / tamanho_captura * 0.5;
	vec2 coordenada = clamp(regiao_textura.xy + uv * regiao_textura.zw,
		regiao_textura.xy + pixel, regiao_textura.xy + regiao_textura.zw - pixel);
	return texture(atlas, coordenada).a;
}

void fragment() {
	vec3 ponto = vec3(ponto_projetado, 1.0);
	float denominador = dot(inversa_z, ponto);
	float denominador_mesa = dot(mesa_z, ponto);
	if (abs(denominador) < 0.000001 || abs(denominador_mesa) < 0.000001) {
		discard;
	}
	vec2 uv = vec2(dot(inversa_x, ponto), dot(inversa_y, ponto)) / denominador;
	vec2 feltro = vec2(dot(mesa_x, ponto), dot(mesa_y, ponto)) / denominador_mesa;
	vec2 local_feltro = (feltro - vec2(0.5)) / max(raios_feltro, vec2(0.00001));
	float distancia_feltro = mesa_arredondada ? length(local_feltro) : max(abs(local_feltro.x), abs(local_feltro.y));
	if (any(lessThanEqual(raios_feltro, vec2(0.0))) || distancia_feltro >= 1.0) {
		discard;
	}
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		discard;
	}
	float altura_real = dot(altura_plano, vec3(uv, 1.0));
	// A fonte deve estar acima do ponto para que seu raio alcance o tampo.
	if (fonte_localizada && altura_real >= altura_fonte - 0.5) {
		discard;
	}
	float altura = max(altura_real, 0.0);
	vec2 passo = vec2(min(suavidade + altura * suavidade_por_altura, 20.0)) / tamanho_captura;
	float alpha = silhueta(TEXTURE, uv) * 0.20;
	alpha += silhueta(TEXTURE, uv + passo * vec2(1.0, 0.0)) * 0.10;
	alpha += silhueta(TEXTURE, uv + passo * vec2(-1.0, 0.0)) * 0.10;
	alpha += silhueta(TEXTURE, uv + passo * vec2(0.0, 1.0)) * 0.10;
	alpha += silhueta(TEXTURE, uv + passo * vec2(0.0, -1.0)) * 0.10;
	alpha += silhueta(TEXTURE, uv + passo * vec2(0.707, 0.707)) * 0.10;
	alpha += silhueta(TEXTURE, uv + passo * vec2(-0.707, 0.707)) * 0.10;
	alpha += silhueta(TEXTURE, uv + passo * vec2(0.707, -0.707)) * 0.10;
	alpha += silhueta(TEXTURE, uv + passo * vec2(-0.707, -0.707)) * 0.10;
	// Perto do apoio a sombra fica mais firme; elevada, mais suave e discreta.
	float cobertura_feltro = 1.0 - smoothstep(1.0 - max(fwidth(distancia_feltro), 0.0001), 1.0, distancia_feltro);
	COLOR = vec4(0.015, 0.020, 0.018, alpha * intensidade * cobertura_feltro / (1.0 + altura * 0.002));
}
