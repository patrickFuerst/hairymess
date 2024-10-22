#version 440

#extension GL_NV_shader_atomic_float : enable

#pragma include "constants.h"
#pragma include "bufferDefinitions.h" // include all, glsl opts-out the ones we don't need
#pragma include "computeHelper.glsl"  // load after buffers are defined 


layout(local_size_x = LOCAL_GROUP_SIZE_X, local_size_y = 1, local_size_z = 1) in;




void trilinearInsertDensity( const vec4 position ,  const float value){

	// position in Voxelgrid space 
	vec3 delta; 
	vec3 cellIndex = mapPositionToGridIndex( position, delta); 

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

	atomicAdd(g_velocityBufferWrite[ index ].x ,  value.x); 
	atomicAdd(g_velocityBufferWrite[ index ].y ,  value.y); 
	atomicAdd(g_velocityBufferWrite[ index ].z ,  value.z); 

}

void trilinearInsertVelocity( const vec4 position ,  const vec4 velocity){

	// position in Voxelgrid space 
	vec3 delta; 
	vec3 cellIndex = mapPositionToGridIndex( position, delta); 

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

void insertVelocity( const vec4 position , const vec4 velocity){

	// position in Voxelgrid space 
	vec3 delta; 
	vec3 cellIndex = mapPositionToGridIndex( position, delta); 
	
	atomicAddVelocity( voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ,  velocity  ); 	
	
}

void insertDensity( const vec4 position ,  const float value){

	// position in Voxelgrid space 
	vec3 delta; 
	vec3 cellIndex = mapPositionToGridIndex( position, delta); 

	atomicAdd(g_densityBuffer[ voxelIndex(cellIndex.x, cellIndex.y, cellIndex.z ) ], value ) ; 
	
}

void main(){

	const vec4 position =  g_particles[gl_GlobalInvocationID.x].pos;
	const vec4 velocity =  ( g_particles[gl_GlobalInvocationID.x].pos - g_particles[gl_GlobalInvocationID.x].prevPos ) / g_timeStep;

	// TODO optimise both to one method
	trilinearInsertDensity( position - g_modelTranslation, 1.0 ); // for every particle adds a density of one
	trilinearInsertVelocity( position - g_modelTranslation, velocity);
//	insertDensity( position , 1.0 );
	//insertVelocity( position, velocity ); 

}


