#version 440

#pragma include "constants.h"
#pragma include "bufferDefinitions.h" // include all, glsl opts-out the ones we don't need
#pragma include "computeHelper.glsl"  // load after buffers are defined 


layout(local_size_x = LOCAL_GROUP_SIZE, local_size_y = LOCAL_GROUP_SIZE, local_size_z = LOCAL_GROUP_SIZE) in;

const float getDensityX( const uint x){
	const int voxelIndex = voxelIndex( x, gl_GlobalInvocationID.y, gl_GlobalInvocationID.z );
	return g_densityBuffer[voxelIndex];
}
const float getDensityY( const uint y){
	const int voxelIndex = voxelIndex( gl_GlobalInvocationID.x, y, gl_GlobalInvocationID.z );
	return g_densityBuffer[voxelIndex];
}
const float getDensityZ( const uint z){
	const int voxelIndex = voxelIndex( gl_GlobalInvocationID.x, gl_GlobalInvocationID.y, z );
	return g_densityBuffer[voxelIndex];
}

const vec3 calculateDensityGradient(){
	
	const uint x = gl_GlobalInvocationID.x;
	const uint y = gl_GlobalInvocationID.y;
	const uint z = gl_GlobalInvocationID.z;

	if (x < 1 || x >= g_gridSize - 1) return vec3(0);
	if (y < 1 || y >= g_gridSize - 1) return vec3(0); 
	if (z < 1 || z >= g_gridSize - 1) return vec3(0); 

	// Central Difference
	// use trilinearinterpolation for getDensity, could also be an approach
	const float x1 = getDensityX( x +1 );
	const float x2 = getDensityX( x -1 );

	const float y1 = getDensityY( y +1 );
	const float y2 = getDensityY( y -1 );
	
	const float z1 = getDensityZ( z +1 );
	const float z2 = getDensityZ( z -1 );

	const float xf = (x2-x1)/2.0;
	const float yf = (y2-y1)/2.0;
	const float zf = (z2-z1)/2.0;
	return vec3(xf,yf,zf );



}

void main(){
	
	
	const int voxelIndex = voxelIndex( gl_GlobalInvocationID.x, gl_GlobalInvocationID.y, gl_GlobalInvocationID.z );
	const float density = g_densityBuffer[voxelIndex];

	// normalize velocity 
	if( density > 0.0){
		//	g_velocityBufferNew[voxelIndex] = vec4(0,0,0,0); 
		g_velocityBufferWrite[voxelIndex].xyz /= density; 
	}

	// calculate gradient 
	const vec3 gradient  = calculateDensityGradient();
	
	#ifdef NORMALIZED_GRADIENT
		// if we use this, gradient acts more like a position offset and values for repulsion need to be very low 
		// better results with non-normalized gradient
		const float len = length(gradient); 
		if( len > 0.0)
			g_gradientBufferWrite[voxelIndex].xyz = normalize(gradient); // normalized gradient
		else
			g_gradientBufferWrite[voxelIndex] = vec4(0);
	#else
	
		g_gradientBufferWrite[voxelIndex].xyz = gradient; // not normalized gradient
	#endif
}


