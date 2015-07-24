#version 440


#pragma include "constants.h"
#pragma include "bufferDefinitions.h" // include all, glsl opts-out the ones we don't need
#pragma include "computeHelper.glsl"  // load after buffers are defined 


layout(local_size_x = LOCAL_GROUP_SIZE, local_size_y = LOCAL_GROUP_SIZE, local_size_z = LOCAL_GROUP_SIZE) in;

uniform int g_filterPass; 


void lowPassFilter(){

	const int kernelSize = 3;
	const int kernelSizeHalf = int(floor(kernelSize/2.0));
	//const float[kernelSize] filterKernel = {0.0508822, 0.211839,  0.474559, 0.211839,0.0508822 };
	const float kernel = 1.0/kernelSize;
	const float[kernelSize] filterKernel = {kernel, kernel, kernel};
	const uint x  = gl_GlobalInvocationID.x;
	const uint y  = gl_GlobalInvocationID.y;
	const uint z  = gl_GlobalInvocationID.z;

	vec4 gradientValue = vec4(0); 
	vec4 velocityValue = vec4(0); 
	uint index = 0;
	if(  g_filterPass == 0){
		for( int i = 0; i < kernelSize; i++){
			index = x - kernelSizeHalf + i;
			if(index < 0 || index >= g_gridSize ) index = x; 
			gradientValue +=  filterKernel[i] * g_gradientBuffer[voxelIndex(index ,y,z)];
			velocityValue +=  filterKernel[i] * g_velocityBuffer[voxelIndex(index ,y,z)];
		}
	}else if( g_filterPass == 1){
		for( int i = 0; i < kernelSize; i++){
			index = y - kernelSizeHalf + i;
			if(index < 0 || index >= g_gridSize ) index = y; 
			gradientValue +=  filterKernel[i] * g_gradientBuffer[voxelIndex(x,index,z)];
			velocityValue +=  filterKernel[i] * g_velocityBuffer[voxelIndex(x,index,z)];
		}
	}else if( g_filterPass == 2){
		for( int i = 0; i < kernelSize; i++){
			index = z - kernelSizeHalf + i;
			if(index < 0 || index >= g_gridSize ) index = z; 
			gradientValue +=  filterKernel[i] * g_gradientBuffer[voxelIndex(x,y,index)];
			velocityValue +=  filterKernel[i] * g_velocityBuffer[voxelIndex(x,y,index)];
		}
	}

	g_gradientBufferWrite[voxelIndex(x,y,z)] = gradientValue; 
	g_velocityBufferWrite[voxelIndex(x,y,z)] = velocityValue; 

}

void main(){
	
	
	// filter velocity 
	lowPassFilter();

	// const uint x  = gl_GlobalInvocationID.x;
	// const uint y  = gl_GlobalInvocationID.y;
	// const uint z  = gl_GlobalInvocationID.z;
	// g_velocityBufferWrite[voxelIndex(x,y,z)] = g_velocityBuffer[voxelIndex(x,y,z)]; 
	//g_gradientBufferWrite[voxelIndex(x,y,z)] = g_gradientBuffer[voxelIndex(x,y,z)]; 


}


