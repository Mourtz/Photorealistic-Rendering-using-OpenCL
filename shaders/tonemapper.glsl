#version 150 core

out vec4 FragColor;

uniform sampler2D u_tex;
uniform vec2 u_resolution;

#define FILMIC

vec3 filmicToneMapping(vec3 color){
	color = max(vec3(0.), color - vec3(0.004));
	color = (color * (6.2 * color + .5)) / (color * (6.2 * color + 1.7) + 0.06);
	return color;
}

void main()
{
	vec3 col = texture(u_tex, gl_FragCoord.xy / u_resolution).rgb;

#ifndef FILMIC

	// gamma correction
	const vec3 gamma = vec3(1. / 2.2);
	// image exposure
	const float exposure = 0.5;

#if 0
	// exposure tone mapping
	col = vec3(1.0) - exp(-col * exposure);
#else
	// reinhard tone mapping
	col = col / (col + 1.0);
#endif
	// gamma correction
	col = pow(col, gamma);

#else
	col = filmicToneMapping(col);
#endif

	FragColor = vec4(col, 1.0);
}