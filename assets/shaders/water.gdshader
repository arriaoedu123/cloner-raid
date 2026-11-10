shader_type canvas_item;
// Água em pixel art: fundo azul (b) com ondinhas de 5 px (B) e, às vezes, um brilho (c).
// As ondinhas ficam presas em posições do MUNDO (passam por você ao voar) e piscam em
// degraus de tempo, sem transição suave, para combinar com a pixel art.

uniform vec4 water_color : source_color = vec4(0.122, 0.435, 0.710, 1.0);   // b #1F6FB5
uniform vec4 ripple_color : source_color = vec4(0.247, 0.663, 0.961, 1.0);  // B #3FA9F5
uniform vec4 sparkle_color : source_color = vec4(0.741, 0.902, 1.0, 1.0);   // c #BDE6FF
uniform vec2 cell_size = vec2(24.0, 12.0);  // uma ondinha possível por célula
uniform float density = 0.3;                // fração de células com ondinha visível
uniform float blink_speed = 1.5;            // trocas por segundo

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(world_pos);
	vec2 cell = floor(p / cell_size);
	vec2 local = p - cell * cell_size;

	// cada célula liga e desliga num ritmo próprio
	float phase = floor(TIME * blink_speed + hash(cell) * 8.0);
	bool visible = hash(cell + vec2(phase, 0.0)) < density;

	// posição da ondinha dentro da célula, e um "balanço" de 1 px a cada troca
	float lx = floor(hash(cell + 1.7) * (cell_size.x - 7.0));
	float ly = floor(hash(cell + 4.3) * (cell_size.y - 1.0));
	float sway = mod(phase, 2.0);
	bool on_line = local.y == ly && local.x >= lx + sway && local.x < lx + sway + 5.0;

	COLOR = water_color;
	if (visible && on_line) {
		COLOR = ripple_color;
		if (local.x == lx + sway + 1.0 && hash(cell + vec2(phase, 9.0)) > 0.75) {
			COLOR = sparkle_color;
		}
	}
}
