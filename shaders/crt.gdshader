shader_type canvas_item;

uniform float scanline_intensity : hint_range(0.0, 0.5) = 0.08;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.2;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.02;
uniform float time_val : hint_range(0.0, 100.0) = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	
	// Scanlines
	float scanline = sin(uv.y * 600.0 + time_val * 2.0) * scanline_intensity;
	
	// Vignette
	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vignette = pow(vig_uv.x * vig_uv.y * 16.0, vignette_strength * 0.35);
	vignette = clamp(vignette, 0.0, 1.0);
	
	// Noise
	float noise = rand(uv + vec2(time_val * 0.1, 0.0)) * noise_intensity;
	
	COLOR = texture(TEXTURE, uv);
	COLOR.rgb -= scanline;
	COLOR.rgb *= vignette;
	COLOR.rgb += noise;
	COLOR.rgb = clamp(COLOR.rgb, 0.0, 1.0);
}
