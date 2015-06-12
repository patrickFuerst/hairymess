#version 440

#define LOCAL_GROUP_SIZE 8


layout(std140, binding=0) buffer density{
    float g_densityBufferSource[];
};

layout(std140, binding=1) buffer density{
    float g_densityBufferDestination[];
};



uniform int g_gridSize;
uniform float g_timeStep;

layout(local_size_x = LOCAL_GROUP_SIZE, local_size_y = LOCAL_GROUP_SIZE, local_size_z = LOCAL_GROUP_SIZE) in;

int  voxelIndex( const float x, const float y, const float z ) {

	return int(floor(x ) + floor(y ) * g_gridSize* g_gridSize  + floor(z ) *  g_gridSize);

}

const float getDensityX( const uint x){
	
	if( x >= g_gridSize ) return 0;
	const int voxelIndex = voxelIndex( x, gl_GlobalInvocationID.y, gl_GlobalInvocationID.z );
	return g_densityBufferSource[voxelIndex];
}
const float getDensityY( const uint y){
	if( y >= g_gridSize ) return 0;
	const int voxelIndex = voxelIndex( gl_GlobalInvocationID.x, y, gl_GlobalInvocationID.z );
	return g_densityBufferSource[voxelIndex];
}
const float getDensityZ( const uint z){
	if( z >= g_gridSize ) return 0;
	const int voxelIndex = voxelIndex( gl_GlobalInvocationID.x, gl_GlobalInvocationID.y, z );
	return g_densityBufferSource[voxelIndex];
}


const vec3 diffuseJacobiBad(){
	
	const uint x = gl_GlobalInvocationID.x;
	const uint y = gl_GlobalInvocationID.y;
	const uint z = gl_GlobalInvocationID.z;

	const float density = g_densityBufferSource[voxelIndex];

	const alpha = 1.0/g_timeStep; 
	const beta = g_timeStep * 0.0001 * g_gridSize * g_gridSize; 
	const float x1 = getDensityX( x + 1 );
	const float x2 = getDensityX( x -1 );

	const float y1 = getDensityY( y +1 );
	const float y2 = getDensityY( y -1 );
	
	const float z1 = getDensityZ( z +1 );
	const float z2 = getDensityZ( z -1 );


	return density + (x1 + x2 + y1 + y2 + z1 + z2 - 4 * density) * beta; 

void main(){
	

	const int voxelIndex = voxelIndex( gl_GlobalInvocationID.x, gl_GlobalInvocationID.y, gl_GlobalInvocationID.z );

	g_densityBufferDestination[voxelIndex] = diffuseJacobiBad();




}


