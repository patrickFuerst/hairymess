#version 440

#define LOCAL_GROUP_SIZE 8


#define SIMULATION_DATA_BINDING 0 
#define CONST_SIMULATION_DATA_BINDING 1
#define MODEL_DATA_BINDING 2
#define VOXEL_GRID_DATA_BINDING 3 
#define CONST_VOXEL_GRID_DATA_BINDING 4



layout(std140, binding=1) buffer gradient{
    vec4 g_gradientBuffer[];
};

layout(std140, binding=2) buffer gradient2{
    vec4 g_gradientBufferWrite[];
};
layout(std140, binding=3) buffer velocity{
    vec4 g_velocityBuffer[];
};

layout(std140, binding=4) buffer velocity2{
     vec4 g_velocityBufferWrite[];
 };


layout( std140, binding = CONST_VOXEL_GRID_DATA_BINDING ) uniform ConstVoxelGridData{
	vec4 g_minBB;
	vec4 g_maxBB; 	
	int g_gridSize;

};

layout(local_size_x = LOCAL_GROUP_SIZE, local_size_y = LOCAL_GROUP_SIZE, local_size_z = LOCAL_GROUP_SIZE) in;


uniform int g_filterPass; 

int  voxelIndex( const float x, const float y, const float z ) {

	return int(floor(x ) + floor(y ) * g_gridSize* g_gridSize  + floor(z ) *  g_gridSize);

}

int  voxelIndex( const int x, const int y, const int z ) {

	return x + y  * g_gridSize* g_gridSize  + z *  g_gridSize;

}


void lowPassFilterVelocity(){

	const int kernelSizeHalf = 1; 
	//const float[kernelSize] filterKernel = mat3(1) * 1.0/27.0;
	const float  factor = 1.0/27.0;;
	const uint x  = gl_GlobalInvocationID.x;
	const uint y  = gl_GlobalInvocationID.y;
	const uint z  = gl_GlobalInvocationID.z;

	if( x >= g_gridSize  || y >= g_gridSize  || z >= g_gridSize ){
		g_velocityBufferWrite[voxelIndex(x,y,z)] = g_velocityBuffer[voxelIndex(x,y,z)]; 

		return; 
	}
	
	if( x <= 0 || y  <= 0 || z <= 0){
		g_velocityBufferWrite[voxelIndex(x,y,z)] = g_velocityBuffer[voxelIndex(x,y,z)]; 
		return; 
	}

	vec4 value = vec4(0); 
	for( int i = -kernelSizeHalf; i <= kernelSizeHalf; i++){
		for( int j = -kernelSizeHalf; j <= kernelSizeHalf; j++){
			for( int k = -kernelSizeHalf; k <= kernelSizeHalf; k++){

				value += factor * g_velocityBuffer[voxelIndex(x+i,y+j,z+k)];
			}
		}
	}

	g_velocityBufferWrite[voxelIndex(x,y,z)] = value; 

}


void lowPassFilterGradient(){

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
	//lowPassFilterVelocity();
	lowPassFilterGradient();

	// const uint x  = gl_GlobalInvocationID.x;
	// const uint y  = gl_GlobalInvocationID.y;
	// const uint z  = gl_GlobalInvocationID.z;
	// g_velocityBufferWrite[voxelIndex(x,y,z)] = g_velocityBuffer[voxelIndex(x,y,z)]; 
	//g_gradientBufferWrite[voxelIndex(x,y,z)] = g_gradientBuffer[voxelIndex(x,y,z)]; 


}


