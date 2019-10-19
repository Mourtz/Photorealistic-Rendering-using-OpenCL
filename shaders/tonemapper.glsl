#version 150 core

out vec4 FragColor;

uniform sampler2D u_tex;
uniform vec2 u_resolution;

// linear white point
const float W = 1.2;
const float T2 = 7.5;

float filmic_reinhard_curve(float x) {
	float q = (T2 * T2 + 1.0) * x * x;
	return q / (q + x + T2 * T2);
}

vec3 filmic_reinhard(vec3 x) {
	float w = filmic_reinhard_curve(W);
	return vec3(
		filmic_reinhard_curve(x.r),
		filmic_reinhard_curve(x.g),
		filmic_reinhard_curve(x.b)) / w;
}

const int N = 8;
vec3 ca(sampler2D t, vec2 UV, vec4 sampl) {
	vec2 uv = 1.0 - 2.0 * UV;
	vec3 c = vec3(0);
	float rf = 1.0;
	float gf = 1.0;
	float bf = 1.0;
	float f = 1.0 / float(N);
	for (int i = 0; i < N; ++i) {
		c.r += f * texture(t, 0.5 - 0.5 * (uv * rf)).r;
		c.g += f * texture(t, 0.5 - 0.5 * (uv * gf)).g;
		c.b += f * texture(t, 0.5 - 0.5 * (uv * bf)).b;
		rf *= 0.9972;
		gf *= 0.998;
		bf /= 0.9988;
		c = clamp(c, 0.0, 1.0);
	}
	return c;
}

#define col tex.rgb

void main()
{
	const float brightness = 1.0;
	vec2 pp = gl_FragCoord.xy / u_resolution.xy;
	vec2 p = 1. - 2. * gl_FragCoord.xy / u_resolution.xy;

	vec3 color = texture(u_tex, pp).rgb;

	float vignette = 1.25 / (1.1 + 1.1 * dot(p, p));
	vignette *= vignette;
	vignette = mix(1.0, smoothstep(0.1, 1.1, vignette), 0.25);
	color = color * vignette;
	color = filmic_reinhard(brightness * color);

	color = smoothstep(-0.025, 1.0, color);

	color = pow(color, vec3(1.0 / 2.2));
	FragColor = vec4(color, 1.0);
}