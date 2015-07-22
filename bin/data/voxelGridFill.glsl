#version 440

#extension GL_NV_shader_atomic_float : enable

#define LOCAL_GROUP_SIZE_X 64


#define SIMULATION_DATA_BINDING 0 
#define CONST_SIMULATION_DATA_BINDING 1
#define MODEL_DATA_BINDING 2
#define VOXEL_GRID_DATA_BINDING 3 
#define CONST_VOXEL_GRID_DATA_BINDING 4


struct Particle{
	vec4 pos;
	vec4 prevPos;
	vec4 vel;
	vec4 color;
	bool fix;
};

struct Voxel{
	//vec4 velocity; 
	vec4 gradient; 
	//float density; // could be int
};

layout(std140, binding=0) buffer particle{
    Particle g_particles[];
};

volatile layout(std430, binding=2) buffer density{  // need to use std430 here, because with std140 types of array get aligned to vec4 
    float g_densityBuffer[];
};
volatile layout(std140, binding=3) buffer velocity{
    vec4 g_velocityBuffer[];
};


layout( std140, binding = MODEL_DATA_BINDING ) uniform ModelData{
	mat4 g_modelMatrix; 
	mat4 g_modelMatrixPrevInverted;
	vec4 g_modelTranslation; 

};

layout( std140, binding = CONST_VOXEL_GRID_DATA_BINDING ) uniform ConstVoxelGridData{
	vec4 g_minBB;
	vec4 g_maxBB; 	
	int g_gridSize;

};
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
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	return voxelIndex( scaledPosition.x, scaledPosition.y, scaledPosition.z);
}



// void trilinearInsertDensity( const vec4 position ,  const float value){

// 	// position in Voxelgrid space 
// 	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz ),1) + 0.5;
// 	scaledPosition *= g_gridSize; 
// 	vec3 cellIndex = floor( scaledPosition.xyz  ); 

// 	vec3 delta = scaledPosition.xyz - cellIndex; 

// 	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].density ,  value  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z)); 
// 	if(cellIndex.z + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ].density ,  value  * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
// 	if(cellIndex.y + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ].density ,  value  * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
// 	if(cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize )  atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ].density ,  value  * (1.0 - delta.x) *  delta.y *  delta.z); 
// 	if(cellIndex.x + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ].density ,  value  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ].density ,  value  * delta.x * (1.0 - delta.y ) * delta.z); 
// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ].density ,  value  * delta.x * delta.y * (1.0 - delta.z)); 
// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ].density ,  value  *  delta.x * delta.y * delta.z); 


// }

void trilinearInsertDensity2( const vec4 position ,  const float value){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 

	atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ] ,  value  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z)); 
	if(cellIndex.z + 1 < g_gridSize) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ] ,  value  * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
	if(cellIndex.y + 1 < g_gridSize) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ] ,  value  * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
	if(cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize )  atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ] ,  value  * (1.0 - delta.x) *  delta.y *  delta.z); 
	if(cellIndex.x + 1 < g_gridSize) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ] ,  value  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
	if(cellIndex.x + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ] ,  value  * delta.x * (1.0 - delta.y ) * delta.z); 
	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize ) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ] ,  value  * delta.x * delta.y * (1.0 - delta.z)); 
	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ] ,  value  *  delta.x * delta.y * delta.z); 


}

void atomicAddVelocity( const uint index, const vec4 value ){

	atomicAdd(g_velocityBuffer[ index ].x ,  value.x); 
	atomicAdd(g_velocityBuffer[ index ].y ,  value.y); 
	atomicAdd(g_velocityBuffer[ index ].z ,  value.z); 

}

void trilinearInsertVelocity( const vec4 position ,  const vec4 velocity){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 

	atomicAddVelocity( voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ,  velocity * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z) ); 
	
	if(cellIndex.z + 1 < g_gridSize){

		atomicAddVelocity(  voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ,  velocity * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
	}

	if(cellIndex.y + 1 < g_gridSize){
	 	atomicAddVelocity(  voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ,  velocity * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
	}

	if(cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ){
		atomicAddVelocity(  voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 )  ,  velocity  * (1.0 - delta.x) *  delta.y *  delta.z); 
	}
	
	if(cellIndex.x + 1 < g_gridSize){
		atomicAddVelocity(  voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ,  velocity  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
	}
	
	if(cellIndex.x + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ){
		atomicAddVelocity(  voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  )  ,  velocity  * delta.x * (1.0 - delta.y ) * delta.z); 
	}
	
	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize ){
		atomicAddVelocity(  voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z )  ,  velocity  * delta.x * delta.y * (1.0 - delta.z) ); 
	}
	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ){
		atomicAddVelocity(  voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ,  velocity *  delta.x * delta.y * delta.z); 
	}

}

void insertVelocity( const vec4 position ,  const vec4 velocity){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 
	atomicAddVelocity( voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ,  velocity  ); 	
	
}

void insertDensity( const vec4 position ,   const float value){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 

	atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ], value ) ; 
	
}

void main(){
	

	const vec4 position =  g_particles[gl_GlobalInvocationID.x].pos;
	const vec4 velocity =  g_particles[gl_GlobalInvocationID.x].vel;

	// TODO optimise both to one method
	trilinearInsertDensity2( position, 1.0 ); // for every particle adds a density of one
	trilinearInsertVelocity( position , velocity);
//	insertDensity( position , 1.0 );
//	insertVelocity( position, velocity ); 

}


