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
	float mass;
	bool fix;
};

struct Voxel{
	vec4 velocity; 
	vec4 gradient; 
	float density; // could be int
};

layout(std140, binding=0) buffer particle{
    Particle g_particles[];
};
volatile layout(std140, binding=1) buffer voxel{
    Voxel g_voxelGrid[];
};

// layout(std140, binding=2) buffer density{
//     float g_densityBuffer[];
// };


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



void trilinearInsertDensity( const vec4 position ,  const float value){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz ),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 

	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].density ,  value  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z)); 
	if(cellIndex.z + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ].density ,  value  * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
	if(cellIndex.y + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ].density ,  value  * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
	if(cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize )  atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ].density ,  value  * (1.0 - delta.x) *  delta.y *  delta.z); 
	if(cellIndex.x + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ].density ,  value  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
	if(cellIndex.x + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ].density ,  value  * delta.x * (1.0 - delta.y ) * delta.z); 
	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ].density ,  value  * delta.x * delta.y * (1.0 - delta.z)); 
	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ].density ,  value  *  delta.x * delta.y * delta.z); 


}

// void trilinearInsertDensity2( const vec4 position ,  const float value){

// 	// position in Voxelgrid space 
// 	vec4 scaledPosition = (position - vec4( g_modelTranslation, 0.0) ) / vec4((g_maxBB - g_minBB),1) + 0.5;
// 	scaledPosition *= g_gridSize; 
// 	vec3 cellIndex = floor( scaledPosition.xyz  ); 

// 	vec3 delta = scaledPosition.xyz - cellIndex; 

// 	atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ] ,  value  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z)); 
// 	if(cellIndex.z + 1 < g_gridSize) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ] ,  value  * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
// 	if(cellIndex.y + 1 < g_gridSize) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ] ,  value  * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
// 	if(cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize )  atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ] ,  value  * (1.0 - delta.x) *  delta.y *  delta.z); 
// 	if(cellIndex.x + 1 < g_gridSize) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ] ,  value  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ] ,  value  * delta.x * (1.0 - delta.y ) * delta.z); 
// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize ) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ] ,  value  * delta.x * delta.y * (1.0 - delta.z)); 
// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ] ,  value  *  delta.x * delta.y * delta.z); 


// }

void trilinearInsertVelocity( const vec4 position ,  const vec4 velocity){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 
	// #pragma unroll
	// for(uint i = 0; i < 3; i++ ){
	// 	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].velocity[i] ,  velocity[i]  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z)); 
	// 	if(cellIndex.z + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ].velocity[i] ,  velocity[i] * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
	// 	if(cellIndex.y + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ].velocity[i] ,  velocity[i] * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
	// 	if(cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ].velocity[i] ,  velocity[i]  * (1.0 - delta.x) *  delta.y *  delta.z); 
	// 	if(cellIndex.x + 1 < g_gridSize) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ].velocity[i] ,  velocity[i]  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
	// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ].velocity[i] ,  velocity[i]  * delta.x * (1.0 - delta.y ) * delta.z); 
	// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize ) atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ].velocity[i] ,  velocity[i]  * delta.x * delta.y * (1.0 - delta.z)); 
	// 	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize )atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ].velocity[i] ,  velocity[i]  *  delta.x * delta.y * delta.z); 
	// }

	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].velocity.x ,  velocity.x  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z)); 
	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].velocity.y ,  velocity.y  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z)); 
	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].velocity.z ,  velocity.z  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z)); 
	
	if(cellIndex.z + 1 < g_gridSize){

		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ].velocity.x ,  velocity.y * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ].velocity.y ,  velocity.y * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) ].velocity.z ,  velocity.z * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z); 
	}


	if(cellIndex.y + 1 < g_gridSize){
	 	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ].velocity.x ,  velocity.x * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
	 	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ].velocity.y ,  velocity.y * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
	 	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1 , cellIndex.z ) ].velocity.z ,  velocity.z * (1.0 - delta.x) * delta.y * (1.0 - delta.z)); 
	}


	if(cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ){
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ].velocity.x ,  velocity.x  * (1.0 - delta.x) *  delta.y *  delta.z); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ].velocity.y ,  velocity.y  * (1.0 - delta.x) *  delta.y *  delta.z); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) ].velocity.z ,  velocity.z  * (1.0 - delta.x) *  delta.y *  delta.z); 
	}
	
	if(cellIndex.x + 1 < g_gridSize){
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ].velocity.x ,  velocity.x  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ].velocity.y ,  velocity.y  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z ) ].velocity.z ,  velocity.z  * delta.x * (1.0 - delta.y ) * (1.0 - delta.z)); 
	}
	
	if(cellIndex.x + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ){
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ].velocity.x ,  velocity.x  * delta.x * (1.0 - delta.y ) * delta.z); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ].velocity.y ,  velocity.y  * delta.x * (1.0 - delta.y ) * delta.z); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) ].velocity.z ,  velocity.z  * delta.x * (1.0 - delta.y ) * delta.z); 
	}
	
	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize ){
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ].velocity.x ,  velocity.x  * delta.x * delta.y * (1.0 - delta.z)); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ].velocity.y ,  velocity.y  * delta.x * delta.y * (1.0 - delta.z)); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) ].velocity.z ,  velocity.z  * delta.x * delta.y * (1.0 - delta.z)); 
	}
	if(cellIndex.x + 1 < g_gridSize && cellIndex.y + 1 < g_gridSize && cellIndex.z + 1 < g_gridSize ){
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ].velocity.x ,  velocity.x  *  delta.x * delta.y * delta.z); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ].velocity.y ,  velocity.y  *  delta.x * delta.y * delta.z); 
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) ].velocity.z ,  velocity.z  *  delta.x * delta.y * delta.z); 
	}

}

void insertVelocity( const vec4 position ,  const vec4 velocity){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 
	for(uint i = 0; i < 3; i++ ){
		atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].velocity[i] ,  velocity[i]  ); 	
	}
}

void insertDensity( const vec4 position ,   const float value){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 

	vec3 delta = scaledPosition.xyz - cellIndex; 

	atomicAdd(g_voxelGrid[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ].density, value ) ; 
	
}

void main(){
	

	const vec4 position =  g_particles[gl_GlobalInvocationID.x].pos;
	const vec4 velocity =  g_particles[gl_GlobalInvocationID.x].vel;
	const float mass =  g_particles[gl_GlobalInvocationID.x].mass;

	// const int voxelIndex = voxelIndex( position );
	// g_voxelGrid[voxelIndex].density = 0.5;

	// TODO optimise both to one method
	trilinearInsertDensity( position, mass ); 
	
	//trilinearInsertDensity2( position, 1.0 ); 
	trilinearInsertVelocity( position , velocity * mass);
//	insertDensity( position , 1.0 );
//	insertVelocity( position, velocity ); 

}


