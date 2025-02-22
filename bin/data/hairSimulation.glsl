#version 440

#pragma include "constants.h"
#pragma include "bufferDefinitions.h" // include all, glsl opts-out the ones we don't need
#pragma include "computeHelper.glsl"  // load after buffers are defined 


shared vec4 sharedPos[LOCAL_GROUP_SIZE_X];
shared bool sharedFixed[LOCAL_GROUP_SIZE_X];
shared float sharedLength[LOCAL_GROUP_SIZE_X];

subroutine void hairSimulationAlgorithm( const uint localStrandIndex,
	const uint localVertexIndex,
	const uint globalStrandIndex,
	const uint vertexIndexInStrand, 
	const vec4 position, 
	const vec4 prevPosition,
	const vec4 color,
	const vec4 force
	);


subroutine uniform hairSimulationAlgorithm simulationAlgorithm; 


layout(local_size_x = LOCAL_GROUP_SIZE_X, local_size_y = 1, local_size_z = 1) in;


void updateParticle( const vec4 pos, const vec4 prevPos, const vec4 vel, const vec4 color  ){


	g_particles[gl_GlobalInvocationID.x].pos.xyz = pos.xyz;
	g_particles[gl_GlobalInvocationID.x].prevPos.xyz = prevPos.xyz;
	g_particles[gl_GlobalInvocationID.x].vel.xyz = vel.xyz;
	g_particles[gl_GlobalInvocationID.x].color = color;
}

vec4 getVelocity( const float x, const float y, const float z ){

	if (x < 0 || x >= g_gridSize) return vec4(0);
	if (y < 0 || y >= g_gridSize) return vec4(0); 
	if (z < 0 || z >= g_gridSize) return vec4(0); 
	
	const int index = voxelIndex(x, y, z );
	return g_velocityBuffer[ index ];
	
}

vec4 getGradient( const float x, const float y, const float z ){

	if (x < 0 || x >= g_gridSize) return vec4(0);
	if (y < 0 || y >= g_gridSize) return vec4(0); 
	if (z < 0 || z >= g_gridSize) return vec4(0); 
	
	const int index = voxelIndex(x, y, z );
	return g_gradientBuffer[ index ];
	
}

vec4 trilinearVelocityInterpolation( const vec4 position ){

	// position in Voxelgrid space 
	vec3 delta; 
	vec3 cellIndex = mapPositionToGridIndex( position, delta); 

	return getVelocity(cellIndex.x, cellIndex.y, cellIndex.z )  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z) +
	getVelocity(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z +
	getVelocity(cellIndex.x, cellIndex.y + 1 , cellIndex.z )  * (1.0 - delta.x) * delta.y * (1.0 - delta.z) +
	getVelocity(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) * (1.0 - delta.x) *  delta.y *  delta.z +
	getVelocity(cellIndex.x + 1, cellIndex.y, cellIndex.z ) * delta.x * (1.0 - delta.y ) * (1.0 - delta.z) + 
	getVelocity(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) * delta.x * (1.0 - delta.y ) * delta.z +
	getVelocity(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) * delta.x * delta.y * (1.0 - delta.z) +
	getVelocity(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) *  delta.x * delta.y * delta.z;

}

vec4 trilinearGradientInterpolation( const vec4 position ){

	// position in Voxelgrid space 
	vec3 delta; 
	vec3 cellIndex = mapPositionToGridIndex( position, delta); 

	return getGradient(cellIndex.x, cellIndex.y, cellIndex.z )  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z) +
	getGradient(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z +
	getGradient(cellIndex.x, cellIndex.y + 1 , cellIndex.z )  * (1.0 - delta.x) * delta.y * (1.0 - delta.z) +
	getGradient(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) * (1.0 - delta.x) *  delta.y *  delta.z +
	getGradient(cellIndex.x + 1, cellIndex.y, cellIndex.z ) * delta.x * (1.0 - delta.y ) * (1.0 - delta.z) + 
	getGradient(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) * delta.x * (1.0 - delta.y ) * delta.z +
	getGradient(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) * delta.x * delta.y * (1.0 - delta.z) +
	getGradient(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) *  delta.x * delta.y * delta.z;

}

vec4 calculateFrictionAndRepulsionVelocityCorrection( vec4 velocity, vec4 position){

	const vec4 interpolatedVelocity = trilinearVelocityInterpolation( position ); 
	
	// friction 
	velocity =  (1.0 - g_friction ) * velocity + g_friction * (interpolatedVelocity ); 

	// repulsion
	const vec4 gridGradient = trilinearGradientInterpolation(position) ;
	//velocity = velocity + g_repulsion * vec4(gridGradient.xyz,0.0)/g_timeStep; // this one for normalize gradient 
	velocity = velocity + g_repulsion * vec4(gridGradient.xyz,0.0) * g_timeStep; // this one for non normalize gradient
	return velocity; 

}


void checkCollision( const vec4 prevPos, inout vec4 pos, inout vec4 velocity ){


	float distanceRay = length(pos - prevPos);
	if( distanceRay < 1e-7 ) return; // solves some trouble

	vec4 sphere = vec4(0,0,0,4) + g_modelTranslation;
	vec3 collisionPoint, normal; 
	// if( calculateSphereCollision( prevPos, pos , sphere , collisionPoint, normal ) ){

	// 	// bounce particle on surface of sphere 

	// 	vec3 u = dot(velocity.xyz , normal ) * normal; 
	// 	vec3 w = velocity.xyz - u; 
	// 	velocity.xyz = w - u; 
	// 	pos.xyz = collisionPoint;
	// }

	vec3 planePosition = vec3(0,0,0);
	vec3 planeNormal = vec3(0,1,0);
	
	if( calculatePlaneCollision( prevPos, pos ,  planePosition, planeNormal, collisionPoint ) ){

		// bounce particle on surface of sphere 

		vec3 u = dot(velocity.xyz , planeNormal ) * planeNormal; 
		vec3 w = velocity.xyz - u; 
		velocity.xyz = w -  u; 
		pos.xyz = collisionPoint;
	}

}

 //simulation subroutines 
#pragma include "DFTLApproach.glsl" // load after helpers are defined
#pragma include "PBDApproach.glsl" // load after helpers are defined

void main(){
	
	uint localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand; 
	calculateIndices( localVertexIndex, localStrandIndex, globalStrandIndex,vertexIndexInStrand, g_numVerticesPerStrand,g_numStrandsPerThreadGroup );
	vec4 oldPosition, prevPosition,color ;

	if(vertexIndexInStrand > 0 ){
		  oldPosition = sharedPos[localVertexIndex] = g_particles[gl_GlobalInvocationID.x].pos;
		  prevPosition =   g_particles[gl_GlobalInvocationID.x].prevPos;
		  color = g_particles[gl_GlobalInvocationID.x].color;
		  sharedFixed[localVertexIndex] = g_particles[gl_GlobalInvocationID.x].fix;

	}else{
		 oldPosition = sharedPos[localVertexIndex] = g_modelMatrix * vec4(vec3(g_rootParticles[globalStrandIndex].x,g_rootParticles[globalStrandIndex].y,g_rootParticles[globalStrandIndex].z),1.0); // workaround because looks like NVIDIA bug not packing vec3 right with std430
		 prevPosition =  vec4(0);
		 color = vec4(1);
		 sharedFixed[localVertexIndex] = true;


	}
	sharedLength[localStrandIndex] = g_strandData[globalStrandIndex].strandLength; 

	vec4 force = g_gravityForce;
	
	memoryBarrierShared();


	simulationAlgorithm(localStrandIndex, localVertexIndex, globalStrandIndex, vertexIndexInStrand, oldPosition, prevPosition,  color, force);
	
}


