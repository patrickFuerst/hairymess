#version 440


#define LOCAL_GROUP_SIZE_X 64

struct Particle{
	vec4 pos;
	vec4 prevPos;
	vec4 vel;
	vec4 color;
	bool fix;
};


struct Voxel{
	vec4 velocity; 
	float density; // could be int
};

layout(std140, binding=0) buffer particle{
    Particle p[];
};

layout(std140, binding=1) buffer voxel{
    Voxel g_voxelGrid[];
};


// model properties
uniform mat4 g_modelMatrix; // need this to transform the fixed vertices if model moves
uniform mat4 g_modelMatrixPrevInverted;
uniform vec3 g_gravityForce;

// strand properties
uniform float g_stiffness;
uniform float g_strandLength;
uniform float g_friction; 

// simulation properties
uniform float g_velocityDamping; 
uniform int g_numIterations; 
uniform float g_timeStep;
uniform float g_ftlDamping;

// additional compute shader properties
uniform int g_numVerticesPerStrand;
uniform int g_numStrandsPerThreadGroup;

// voxel grid properties
uniform vec3 g_minBB;
uniform vec3 g_maxBB; 	
uniform int g_gridSize;
uniform vec3 g_modelTranslation; 


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


int  voxelIndex( const float x, const float y, const float z ) {

	return int(floor(x ) + floor(y ) * g_gridSize* g_gridSize  + floor(z ) *  g_gridSize);

}

int  voxelIndex( const vec4 position ) {

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation, 0.0) ) / vec4((g_maxBB - g_minBB),1) + 0.5;
	scaledPosition *= g_gridSize; 
	return voxelIndex( scaledPosition.x, scaledPosition.y, scaledPosition.z);
}

vec4 getNormalizedVelocity( const float x, const float y, const float z ){

		const int index = voxelIndex(x, y, z );
		const float gridDensity = g_voxelGrid[ index ].density;
		
		if(gridDensity > 0.0 ){
				return g_voxelGrid[ index ].velocity / gridDensity;
		}
		else{
				return vec4(0);
		}
}

vec4 trilinearVelocityInterpolation( const vec4 position ){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation, 0.0) ) / vec4((g_maxBB - g_minBB),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 
	vec3 delta = scaledPosition.xyz - cellIndex; 

	return getNormalizedVelocity(cellIndex.x, cellIndex.y, cellIndex.z )  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z) +
	getNormalizedVelocity(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z +
	getNormalizedVelocity(cellIndex.x, cellIndex.y + 1 , cellIndex.z )  * (1.0 - delta.x) * delta.y * (1.0 - delta.z) +
	getNormalizedVelocity(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) * (1.0 - delta.x) *  delta.y *  delta.z +
	getNormalizedVelocity(cellIndex.x + 1, cellIndex.y, cellIndex.z ) * delta.x * (1.0 - delta.y ) * (1.0 - delta.z) + 
	getNormalizedVelocity(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) * delta.x * (1.0 - delta.y ) * delta.z +
	getNormalizedVelocity(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) * delta.x * delta.y * (1.0 - delta.z) +
	getNormalizedVelocity(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) *  delta.x * delta.y * delta.z;


}



void main(){
	
	uint localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand; 
	calculateIndices( localVertexIndex, localStrandIndex, globalStrandIndex,vertexIndexInStrand, g_numVerticesPerStrand,g_numStrandsPerThreadGroup );
	
	const vec4 oldPosition = sharedPos[localVertexIndex] =  p[gl_GlobalInvocationID.x].pos;
	const vec4 prevPosition =   p[gl_GlobalInvocationID.x].prevPos;
	vec4 velocity =   p[gl_GlobalInvocationID.x].vel;
	const vec4 color = p[gl_GlobalInvocationID.x].color;

	sharedFixed[localVertexIndex] = p[gl_GlobalInvocationID.x].fix;

	vec4 force = vec4(g_gravityForce,0);

	// const int voxelIndex = voxelIndex( oldPosition ); 
	// const vec4 gridVelocity = g_voxelGrid[voxelIndex].velocity;
	// const float gridDensity = g_voxelGrid[voxelIndex].density; 

	// friction 
	// const float frictionCoeff = 0.2; 
	// if( gridDensity > 0.0 )
	// 		velocity =  (1.0 - g_friction ) * velocity + g_friction * (gridVelocity/gridDensity ); 

	const vec4 gridVelocity = trilinearVelocityInterpolation( oldPosition ); 
	// friction 
	const float frictionCoeff = 0.2; 
	velocity =  (1.0 - g_friction ) * velocity + g_friction * (gridVelocity ); 

	simulationAlgorithm(localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand, oldPosition, prevPosition, velocity, color, force);
	
}


