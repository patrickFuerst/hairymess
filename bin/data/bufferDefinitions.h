
#pragma include "constants.h"

struct Particle{
	vec4 pos;
	vec4 prevPos;
	vec4 vel;
	vec4 color;
	bool fix;
};

struct StrandData{
	float strandLength; 
};
struct RootData{  // workaround because looks like NVIDIA bug not packing vec3 right with std430
	float x, y, z;
};

// constants defined in computehelper.h
layout(std430, binding = ROOT_DATA ) buffer rootParticle{
    RootData g_rootParticles[];
};


layout(std140, binding = PARTICLE_DATA ) buffer particle{
    Particle g_particles[];
};

layout(std140, binding = GRADIENT_READ_DATA ) buffer gradient{
    vec4 g_gradientBuffer[];
};

layout(std140, binding = GRADIENT_WRITE_DATA) buffer gradient2{
    vec4 g_gradientBufferWrite[];
};

layout(std140, binding = VELOCITY_READ_DATA) buffer velocity{
    vec4 g_velocityBuffer[];
};

layout(std140, binding = VELOCITY_WRITE_DATA ) buffer velocity2{
     vec4 g_velocityBufferWrite[];
 };

layout(std430, binding = DESNITY_DATA ) buffer density{ // need to use std430 here, because with std140 types of array get aligned to vec4 
    float g_densityBuffer[];
};

layout(std140, binding = STRAND_DATA ) buffer strandData{ 
    StrandData g_strandData[];
};

layout(std140, binding = SIMULATION_DATA_BINDING ) uniform SimulationData { 
	vec4 g_gravityForce;
	float g_velocityDamping;
	int g_numIterations;
	float g_stiffness;
	float g_friction; 
	float g_repulsion;
	float g_ftlDamping; 
	float g_timeStep; 

};

layout( std140, binding = CONST_SIMULATION_DATA_BINDING ) uniform ConstSimulationData{
	int g_numVerticesPerStrand; 
	int g_numStrandsPerThreadGroup;
	int g_numStrands; 
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
