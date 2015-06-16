#version 440 core

#define POSITION	0
#define COLOR		1
#define NORMAL		2
#define TEXCOORD    3

#define VELOCITY 4
#define GRADIENT 5
#define DENSITY 6 

#define SIMULATION_DATA_BINDING 0 
#define CONST_SIMULATION_DATA_BINDING 1
#define MODEL_DATA_BINDING 2
#define VOXEL_GRID_DATA_BINDING 3 
#define CONST_VOXEL_GRID_DATA_BINDING 4

precision highp float;
precision highp int;

layout(location = VELOCITY) in vec4 velocity;
layout(location = GRADIENT) in vec4 gradient ;
layout(location = DENSITY) in float density ;


uniform mat4 viewMatrix; // set from oF
uniform mat4 projectionMatrix;  // set from oF
uniform mat4 modelViewProjectionMatrix; // set from oF


layout( std140, binding = CONST_VOXEL_GRID_DATA_BINDING ) uniform ConstVoxelGridData{
	vec4 g_minBB;
	vec4 g_maxBB; 	
	int g_gridSize;

};

layout( std140, binding = MODEL_DATA_BINDING ) uniform ModelData{
	mat4 g_modelMatrix; 
	mat4 g_modelMatrixPrevInverted;
	vec4 g_modelTranslation; 

};



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

	// calculate voxel position from the verexID
	int voxelIndex_x = int(mod( gl_VertexID , g_gridSize)); 
	int voxelIndex_z = int( mod(floor(gl_VertexID /  (g_gridSize) ), g_gridSize) ) ;
	int voxelIndex_y = int(floor(gl_VertexID / (g_gridSize*g_gridSize))); 

	// position is calculated for the voxel center
	gl_Position.x = g_minBB.x + voxelIndex_x  *widthDelta  + widthDelta/2.0;
	gl_Position.y = g_minBB.y + voxelIndex_y  *heigthDelta + heigthDelta/2.0;
	gl_Position.z = g_minBB.z + voxelIndex_z  *depthDelta + depthDelta/2.0;

	gl_Position = modelViewProjectionMatrix * g_modelMatrix * vec4(gl_Position.xyz,1.0);
	
	// just look at voxels which are not empty
	// float alpha = density > 0.0 ? 1.0 : 0.0;
	// Out.color  = vec4(density,density,density,alpha);

	float alpha = length(gradient) > 0.0 ? 1.0 : 0.0; 
	Out.color = vec4(gradient.xyz, alpha);
}

