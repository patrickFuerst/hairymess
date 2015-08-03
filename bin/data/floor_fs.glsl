#version 440 core

#define POSITION	0
#define COLOR		1
#define NORMAL		2
#define TEXCOORD    3
#define FRAG_COLOR	0

precision highp float;
precision highp int;
//layout(std140, column_major) uniform;
//layout(std430, column_major) buffer; AMD bug

in block
{
	vec4 color;
} In;


uniform vec4 overrideColor; 
uniform float windowHeight; 

layout(location = FRAG_COLOR, index = 0) out vec4 Color;


void main()
{

	float y = gl_FragCoord.y; 
	// fade out color 
	float delta = (y) /(windowHeight - (windowHeight/2.0) );
	float alpha =  0.01 + pow(delta,4);
	Color = overrideColor * In.color;
	Color.a = clamp(alpha,0,1);
	float p = 1.0/2.2;
	Color.rgb =  pow(Color.rgb, vec3(p)); 
}

