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
	float density; // could be int
};

layout(std140, binding=0) buffer particle{
    Particle g_particles[];
};
layout(std140, binding=1) buffer voxel{
    Voxel g_voxelGrid[];
};


// additional compute shader properties
//uniform int g_numVerticesPerStrand;
//uniform int g_numStrandsPerThreadGroup;

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


int  voxelIndex( const float x, const float y, const float z ) {

	return int(floor(x ) + floor(y ) * g_gridSize* g_gridSize  + floor(z ) *  g_gridSize);

}

int  voxelIndex( const vec4 position ) {

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation, 0.0) ) / vec4((g_maxBB - g_minBB),1) + 0.5;
	scaledPosition *= g_gridSize; 
	return voxelIndex( scaledPosition.x, scaledPosition.y, scaledPosition.z);
}



void trilinearInsertDensity( const vec4 position ,  const float value){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation, 0.0) ) / vec4((g_maxBB - g_minBB),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 

	// make this atomic
	g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].density +=  value  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z); 
	g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ].density +=  value  * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z; 
	g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ].density +=  value  * (1.0 - delta.x) * delta.y * (1.0 - delta.z); 
	g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ].density +=  value  * (1.0 - delta.x) *  delta.y *  delta.z; 
	g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ].density +=  value  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z); 
	g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ].density +=  value  * delta.x * (1.0 - delta.y ) * delta.z; 
	g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ].density +=  value  * delta.x * delta.y * (1.0 - delta.z); 
	g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ].density +=  value  *  delta.x * delta.y * delta.z; 


}

void trilinearInsertVelocity( const vec4 position ,  const vec4 velocity){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation, 0.0) ) / vec4((g_maxBB - g_minBB),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 

	// make this atomic
	g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].velocity +=  velocity  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z); 
	g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ].velocity +=  velocity  * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z; 
	g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ].velocity +=  velocity  * (1.0 - delta.x) * delta.y * (1.0 - delta.z); 
	g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ].velocity +=  velocity  * (1.0 - delta.x) *  delta.y *  delta.z; 
	g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ].velocity +=  velocity  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z); 
	g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ].velocity +=  velocity  * delta.x * (1.0 - delta.y ) * delta.z; 
	g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ].velocity +=  velocity  * delta.x * delta.y * (1.0 - delta.z); 
	g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ].velocity +=  velocity  *  delta.x * delta.y * delta.z; 


}


void main(){
	
	//uint localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand; 
	//calculateIndices( localVertexIndex, localStrandIndex, globalStrandIndex,vertexIndexInStrand, g_numVerticesPerStrand,g_numStrandsPerThreadGroup );
	
	const vec4 position =  g_particles[gl_GlobalInvocationID.x].pos;
	const vec4 velocity =  g_particles[gl_GlobalInvocationID.x].vel;

	// const int voxelIndex = voxelIndex( position );
	// g_voxelGrid[voxelIndex].density = 0.5;

	// TODO optimise both to one method
	trilinearInsertDensity( position, 1.0 ); 
	trilinearInsertVelocity( position , velocity);
}


