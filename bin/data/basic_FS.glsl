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

layout(location = FRAG_COLOR, index = 0) out vec4 Color;


void main()
{
	Color = overrideColor * In.color;
	float p = 1.0/2.2;
	Color.rgb =  pow(Color.rgb, vec3(p));  
}

