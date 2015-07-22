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
	//vec4 velocity;
	vec4 gradient;
	//float density; // could be int
};

layout(std140, binding=0) buffer particle{
    Particle p[];
};

layout(std140, binding=1) buffer voxel{
    Voxel g_voxelGrid[];
};

layout(std140, binding=3) buffer velocity{
    vec4 g_velocityBuffer[];
};


layout(std140, binding = SIMULATION_DATA_BINDING ) uniform SimulationData { 
	float g_velocityDamping;
	int g_numIterations;
	float g_stiffness;
	float g_friction; 
	float g_repulsion;
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




void main(){
	
	uint localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand; 
	calculateIndices( localVertexIndex, localStrandIndex, globalStrandIndex,vertexIndexInStrand, g_numVerticesPerStrand,g_numStrandsPerThreadGroup );
	
	const vec4 oldPosition = sharedPos[localVertexIndex] =  p[gl_GlobalInvocationID.x].pos;
	const vec4 prevPosition =   p[gl_GlobalInvocationID.x].prevPos;
	const vec4 color = p[gl_GlobalInvocationID.x].color;
	const vec4 velocity =   p[gl_GlobalInvocationID.x].vel;

	sharedFixed[localVertexIndex] = p[gl_GlobalInvocationID.x].fix;

	vec4 force = g_gravityForce;
	
	memoryBarrierShared();



//	const int voxelIndex = voxelIndex( oldPosition ); 

	// const vec4 interpolatedVelocity = trilinearVelocityInterpolation( oldPosition ); 
	
	// //const vec4 gridVelocity = g_voxelGrid[ voxelIndex ].velocity; 
	// // friction 
	// velocity =  (1.0 - g_friction ) * velocity + g_friction * (interpolatedVelocity ); 

	// // repulsion
	// const vec4 gridGradient = trilinearGradientInterpolation(oldPosition) ;
	// //velocity = velocity + g_repulsion * vec4(gridGradient.xyz,0.0)/g_timeStep; // this one for normalize gradient 
	// velocity = velocity + g_repulsion * vec4(gridGradient.xyz,0.0) * g_timeStep; // this one for non normalize gradient

	simulationAlgorithm(localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand, oldPosition, prevPosition, velocity, color, force);
	
}


