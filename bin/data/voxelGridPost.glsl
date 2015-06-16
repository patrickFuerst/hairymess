#version 440

#define LOCAL_GROUP_SIZE 8


#define SIMULATION_DATA_BINDING 0 
#define CONST_SIMULATION_DATA_BINDING 1
#define MODEL_DATA_BINDING 2
#define VOXEL_GRID_DATA_BINDING 3 
#define CONST_VOXEL_GRID_DATA_BINDING 4


struct Voxel{
	vec4 velocity; 
	vec4 gradient; 
	float density; // could be int
};


layout(std140, binding=1) buffer voxel{
    Voxel g_voxelGrid[];
};


layout( std140, binding = CONST_VOXEL_GRID_DATA_BINDING ) uniform ConstVoxelGridData{
	vec4 g_minBB;
	vec4 g_maxBB; 	
	int g_gridSize;

};

layout(local_size_x = LOCAL_GROUP_SIZE, local_size_y = LOCAL_GROUP_SIZE, local_size_z = LOCAL_GROUP_SIZE) in;

int  voxelIndex( const float x, const float y, const float z ) {

	return int(floor(x ) + floor(y ) * g_gridSize* g_gridSize  + floor(z ) *  g_gridSize);

}

const float getDensityX( const uint x){
	const int voxelIndex = voxelIndex( x, gl_GlobalInvocationID.y, gl_GlobalInvocationID.z );
	return g_voxelGrid[voxelIndex].density;
}
const float getDensityY( const uint y){
	const int voxelIndex = voxelIndex( gl_GlobalInvocationID.x, y, gl_GlobalInvocationID.z );
	return g_voxelGrid[voxelIndex].density;
}
const float getDensityZ( const uint z){
	const int voxelIndex = voxelIndex( gl_GlobalInvocationID.x, gl_GlobalInvocationID.y, z );
	return g_voxelGrid[voxelIndex].density;
}


const vec3 centralDifference(){
	
	const uint x = gl_GlobalInvocationID.x;
	const uint y = gl_GlobalInvocationID.y;
	const uint z = gl_GlobalInvocationID.z;

	if (x < 1 || x >= g_gridSize - 1) return vec3(0);
	if (y < 1 || y >= g_gridSize - 1) return vec3(0); 
	if (z < 1 || z >= g_gridSize - 1) return vec3(0); 

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
	const float density = g_voxelGrid[voxelIndex].density;

	// normalize velocity 
	if( density > 0.0)
		g_voxelGrid[voxelIndex].velocity /= density; 

	// calculate gradient 
	const vec3 gradient  = centralDifference();
	const float len = length(gradient); 

	if( len > 0.0)
		g_voxelGrid[voxelIndex].gradient.xyz = normalize(gradient); // normalized gradient
	else
	g_voxelGrid[voxelIndex].gradient = vec4(0);
}


