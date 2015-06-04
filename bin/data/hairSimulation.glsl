#version 440


#define LOCAL_GROUP_SIZE_X 64

struct Particle{
	vec4 pos;
	vec4 prevPos;
	vec4 vel;
	vec4 color;
	bool fix;
};

layout(std140, binding=0) buffer particle{
    Particle p[];
};


// model properties
uniform mat4 g_modelMatrix; // need this to transform the fixed vertices if model moves
uniform mat4 g_modelMatrixPrevInverted;
uniform vec3 g_gravityForce;

// strand properties
uniform float g_stiffness;
uniform float g_strandLength;

// simulation properties
uniform float g_velocityDamping; 
uniform int g_numIterations; 
uniform float g_timeStep;
uniform float g_ftlDamping;

// additional compute shader properties
uniform int g_numVerticesPerStrand;
uniform int g_numStrandsPerThreadGroup;


uniform bool g_useFTL; 

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
	const vec4 velocity =   p[gl_GlobalInvocationID.x].vel;
	const vec4 color = p[gl_GlobalInvocationID.x].color;

	sharedFixed[localVertexIndex] = p[gl_GlobalInvocationID.x].fix;

	vec4 force = vec4(g_gravityForce,0);

	simulationAlgorithm(localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand, oldPosition, prevPosition, velocity, color, force);
	
}


