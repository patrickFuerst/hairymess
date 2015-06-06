#version 440

#define LOCAL_GROUP_SIZE_X 64

struct Particle{
	vec4 pos;
	vec4 prevPos;
	vec4 vel;
	vec4 color;
	bool fix;
};

struct Voxel{
	vec4 velocity; 
	float density; 
};

layout(std140, binding=0) buffer particle{
    Particle p[];
};
layout(std140, binding=1) buffer voxel{
    Voxel voxelGrid[];
};


// additional compute shader properties
uniform int g_numVerticesPerStrand;
uniform int g_numStrandsPerThreadGroup;

uniform vec3 g_modelTranslation; 
uniform vec3 g_minBB;
uniform vec3 g_maxBB; 	
uniform int g_gridSize;

shared vec4 sharedPos[LOCAL_GROUP_SIZE_X];


layout(local_size_x = LOCAL_GROUP_SIZE_X, local_size_y = 1, local_size_z = 1) in;


void calculateIndices( inout uint localVertexIndex , inout uint localStrandIndex ,
					 inout uint globalStrandIndex , inout uint vertexIndexInStrand, const   uint numVerticesPerStrand, 
					const  uint numStrandsPerThreadGroup    ){



	localVertexIndex = gl_LocalInvocationID.x; 
	localStrandIndex = uint(floor(gl_LocalInvocationID.x /  numVerticesPerStrand));
	globalStrandIndex = gl_WorkGroupID.x * numStrandsPerThreadGroup + localStrandIndex;
	vertexIndexInStrand = gl_LocalInvocationID.x %  numVerticesPerStrand; 



}


int  calculateVoxelIndex( const vec4 position, const uint gridSize  ) {


	vec3 minBB =  g_minBB ;
	vec3 maxBB =  g_maxBB ;
	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation, 0.0) ) / vec4((g_maxBB - g_minBB),1) + 0.5;

	return int(floor(scaledPosition.x  * gridSize) + floor(scaledPosition.y * gridSize) * gridSize* gridSize  + floor(scaledPosition.z * gridSize) *  gridSize);

}

void main(){
	
	uint localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand; 
	calculateIndices( localVertexIndex, localStrandIndex, globalStrandIndex,vertexIndexInStrand, g_numVerticesPerStrand,g_numStrandsPerThreadGroup );
	
	const vec4 oldPosition =  p[gl_GlobalInvocationID.x].pos;
	const vec4 prevPosition =   p[gl_GlobalInvocationID.x].prevPos;
	const vec4 velocity =   p[gl_GlobalInvocationID.x].vel;
	const vec4 color = p[gl_GlobalInvocationID.x].color;

	const int voxelIndex = calculateVoxelIndex( oldPosition, g_gridSize );

	// calculate voxel grid index from position and fill density and velocity 
	
	//vec4 velocity = voxelGrid[gl_LocalInvocationIndex].velocity;
	//float density  = voxelGrid[gl_LocalInvocationIndex].density;
	voxelGrid[voxelIndex].velocity = vec4(1,0,0,1);
	voxelGrid[voxelIndex].density = 1.0;
}


