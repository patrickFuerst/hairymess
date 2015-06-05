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

layout(location = FRAG_COLOR, index = 0) out vec4 Color;

void main()
{
	Color = In.color;
}

