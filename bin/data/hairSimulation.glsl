#version 440


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
	vec4 velocity;
	vec4 gradient;
	float density; // could be int
};

layout(std140, binding=0) buffer particle{
    Particle p[];
};

layout(std140, binding=1) buffer voxel{
    Voxel g_voxelGrid[];
};



layout(std140, binding = SIMULATION_DATA_BINDING ) uniform SimulationData { 
	float g_velocityDamping;
	int g_numIterations;
	float g_stiffness;
	float g_friction; 
	float g_ftlDamping; 
	float g_timeStep; 

};

layout( std140, binding = CONST_SIMULATION_DATA_BINDING ) uniform ConstSimulationData{
	vec4 g_gravityForce;
	int g_numVerticesPerStrand; 
	int g_numStrandsPerThreadGroup;
	float g_strandLength;	

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
shared bool sharedFixed[LOCAL_GROUP_SIZE_X];

subroutine void hairSimulationAlgorithm( const uint localStrandIndex,
	const uint localVertexIndex,
	const uint globalStrandIndex,
	const uint vertexIndexInStrand, 
	const vec4 position, 
	const vec4 prevPosition,
	const vec4 velocity,
	const vec4 color,
	const vec4 force
	);


subroutine uniform hairSimulationAlgorithm simulationAlgorithm; 


layout(local_size_x = LOCAL_GROUP_SIZE_X, local_size_y = 1, local_size_z = 1) in;


#pragma include "computeHelper.glsl"  // load after globals are defined 
 
 //simulation subroutines 
#pragma include "DFTLApproach.glsl" // load after helpers are defined
#pragma include "PBDApproach.glsl" // load after helpers are defined


int  voxelIndex( const float x, const float y, const float z ) {

	return int(floor(x ) + floor(y ) * g_gridSize* g_gridSize  + floor(z ) *  g_gridSize);

}

int  voxelIndex( const vec4 position ) {

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	return voxelIndex( scaledPosition.x, scaledPosition.y, scaledPosition.z);
}

vec4 getVelocity( const float x, const float y, const float z ){

	if (x < 0 || x >= g_gridSize) return vec4(0);
	if (y < 0 || y >= g_gridSize) return vec4(0); 
	if (z < 0 || z >= g_gridSize) return vec4(0); 
	
	const int index = voxelIndex(x, y, z );
	return g_voxelGrid[ index ].velocity;
	
}

vec4 trilinearVelocityInterpolation( const vec4 position ){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 
	vec3 delta = scaledPosition.xyz - cellIndex; 

	return getVelocity(cellIndex.x, cellIndex.y, cellIndex.z )  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z) +
	getVelocity(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z +
	getVelocity(cellIndex.x, cellIndex.y + 1 , cellIndex.z )  * (1.0 - delta.x) * delta.y * (1.0 - delta.z) +
	getVelocity(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) * (1.0 - delta.x) *  delta.y *  delta.z +
	getVelocity(cellIndex.x + 1, cellIndex.y, cellIndex.z ) * delta.x * (1.0 - delta.y ) * (1.0 - delta.z) + 
	getVelocity(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) * delta.x * (1.0 - delta.y ) * delta.z +
	getVelocity(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) * delta.x * delta.y * (1.0 - delta.z) +
	getVelocity(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) *  delta.x * delta.y * delta.z;


}



void main(){
	
	uint localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand; 
	calculateIndices( localVertexIndex, localStrandIndex, globalStrandIndex,vertexIndexInStrand, g_numVerticesPerStrand,g_numStrandsPerThreadGroup );
	
	const vec4 oldPosition = sharedPos[localVertexIndex] =  p[gl_GlobalInvocationID.x].pos;
	const vec4 prevPosition =   p[gl_GlobalInvocationID.x].prevPos;
	vec4 velocity =   p[gl_GlobalInvocationID.x].vel;
	const vec4 color = p[gl_GlobalInvocationID.x].color;

	sharedFixed[localVertexIndex] = p[gl_GlobalInvocationID.x].fix;

	vec4 force = g_gravityForce;
	const int voxelIndex = voxelIndex( oldPosition ); 

	const vec4 interpolatedVelocity = trilinearVelocityInterpolation( oldPosition ); 
	
	//const vec4 gridVelocity = g_voxelGrid[ voxelIndex ].velocity; 
	// friction 
	const float frictionCoeff = 0.2; 
	velocity =  (1.0 - g_friction ) * velocity + g_friction * (interpolatedVelocity ); 

	// repulsion
	//const vec4 gridGradient = g_voxelGrid[ voxelIndex ].gradient;
	//const float repulsionCoeff = 0.02;
	//velocity = velocity + repulsionCoeff * vec4(gridGradient.xyz,0.0)/g_timeStep;

	simulationAlgorithm(localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand, oldPosition, prevPosition, velocity, color, force);
	
}


