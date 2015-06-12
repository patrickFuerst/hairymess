#version 440 core

#define POSITION	0
#define COLOR		1
#define NORMAL		2
#define TEXCOORD    3

#define VELOCITY 4
#define GRADIENT 5
#define DENSITY 6 



precision highp float;
precision highp int;
//layout(std140, column_major) uniform;
//layout(std430, column_major) buffer; AMD bug

layout(location = VELOCITY) in vec4 velocity;
layout(location = GRADIENT) in vec4 gradient ;
layout(location = DENSITY) in float density ;

//layout(std140, column_major) uniform;
//layout(std430, column_major) buffer; AMD bug
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 g_modelMatrix;
uniform mat4 modelViewProjectionMatrix;

uniform vec3 g_minBB;
uniform vec3 g_maxBB; 	
uniform int g_gridSize; 
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

	float widthDelta  = (g_maxBB.x  - g_minBB.x) / g_gridSize; 
	float heigthDelta = (g_maxBB.y  - g_minBB.y) / g_gridSize;  
	float depthDelta = (g_maxBB.z  - g_minBB.z) / g_gridSize; 

	int voxelIndex_x = int(mod( gl_VertexID , g_gridSize)); 
	int voxelIndex_z = int( mod(floor(gl_VertexID /  (g_gridSize) ), g_gridSize) ) ;
	int voxelIndex_y = int(floor(gl_VertexID / (g_gridSize*g_gridSize))); 

	gl_Position.x = g_minBB.x + voxelIndex_x  *widthDelta  + widthDelta/2.0;
	gl_Position.y = g_minBB.y + voxelIndex_y  *heigthDelta + heigthDelta/2.0;
	gl_Position.z = g_minBB.z + voxelIndex_z  *depthDelta + depthDelta/2.0;
	//gl_Position = modelViewProjectionMatrix * position ;
	//gl_Position =  modelViewProjectionMatrix * position;
	gl_Position = modelViewProjectionMatrix * g_modelMatrix * vec4(gl_Position.xyz,1.0);
	float alpha = density > 0.0 ? 1.0 : 0.0;
	//Out.color  = vec4(vec3(density), alpha);
	Out.color  = vec4(gradient.xyz,alpha);
}

