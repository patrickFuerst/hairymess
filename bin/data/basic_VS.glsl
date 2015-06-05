#version 440 core

#define POSITION	0
#define COLOR		1
#define NORMAL		2
#define TEXCOORD    3

#define VELOCITY 4
#define DENSITY 5 


#define FRAG_COLOR	0


precision highp float;
precision highp int;
//layout(std140, column_major) uniform;
//layout(std430, column_major) buffer; AMD bug

layout(location = POSITION) in vec4 position;
layout(location = COLOR) in vec4 color;

//layout(std140, column_major) uniform;
//layout(std430, column_major) buffer; AMD bug

uniform mat4 modelViewProjectionMatrix;
uniform mat4 modelViewMatrix;
uniform vec4 globalColor; 
out block
{
	vec4 color;
} Out;

out gl_PerVertex
{
	vec4 gl_Position;
};

void main()
{	
	//gl_Position = modelViewProjectionMatrix * position ;
	gl_Position =  modelViewProjectionMatrix * position;
	Out.color  = color;
}

