shader_type canvas_item;

uniform float glitch_strength : hint_range(0.0, 1.0) = 0.0;
uniform float time_val : hint_range(0.0, 100.0) = 0.0;

float rand(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	
	if (glitch_strength > 0.01) {
		float block = floor(uv.y * 20.0);
		float t = floor(time_val * 15.0);
		float r = rand(block + t * 0.1);
		
		if (r > (1.0 - glitch_strength * 0.6)) {
			float shift = (rand(block + t) - 0.5) * glitch_strength * 0.08;
			uv.x += shift;
		}
		
		// RGB split
		float split = glitch_strength * 0.006;
		vec4 r_chan = texture(TEXTURE, uv + vec2(split, 0.0));
		vec4 g_chan = texture(TEXTURE, uv);
		vec4 b_chan = texture(TEXTURE, uv - vec2(split, 0.0));
		COLOR = vec4(r_chan.r, g_chan.g, b_chan.b, g_chan.a);
	} else {
		COLOR = texture(TEXTURE, uv);
	}
}
