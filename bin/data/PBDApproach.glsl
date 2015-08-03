
//Position Based Dynamics Approach
layout(index= 2) subroutine(hairSimulationAlgorithm) void PBDApproach( const uint localStrandIndex,
	const uint localVertexIndex,
	const uint globalStrandIndex,
	const uint vertexIndexInStrand, 
	const vec4 position, 
	const vec4 prevPosition,
	const vec4 color,
	const vec4 force
	){

	const vec4 oldPosition = position;
	const float strandLength = sharedLength[localStrandIndex]; 

	vec4 velocity = vec4(0);

	if( !sharedFixed[localVertexIndex] ) {

		velocity = sharedPos[localVertexIndex] - prevPosition; 
		velocity /= g_timeStep; 
		
		velocity = calculateFrictionAndRepulsionVelocityCorrection( velocity, sharedPos[localVertexIndex] - g_modelTranslation);

		sharedPos[localVertexIndex]  = positionIntegration( sharedPos[localVertexIndex], velocity, force );

	}

	memoryBarrierShared();
	
	const uint index0 = localVertexIndex*2;
	const uint index1 = localVertexIndex*2+1;
	const uint index2 = localVertexIndex*2+2;

	float stiffness = 1.0 - pow( (1.0 - g_stiffness), 1.0/g_numIterations); // linear depended on the iterations now
	
	for(int i = 0 ; i < g_numIterations ; i++){
		
		// split the solving in non adjacent pairs of vertices 
		if( localVertexIndex <  floor(gl_WorkGroupSize.x/2) && (index0 % g_numVerticesPerStrand) < g_numVerticesPerStrand-1){
			applyLengthConstraint( sharedPos[index0], sharedFixed[index0], sharedPos[index1], sharedFixed[index1], strandLength/g_numVerticesPerStrand, stiffness);

		}
		memoryBarrierShared();
		if( localVertexIndex <  floor((gl_WorkGroupSize.x-1)/2) && (index1 % g_numVerticesPerStrand) < g_numVerticesPerStrand -1){
			applyLengthConstraint( sharedPos[index1], sharedFixed[index1], sharedPos[index2], sharedFixed[index2], strandLength/g_numVerticesPerStrand, stiffness);			
		}
		memoryBarrierShared();

	}

	barrier();
	checkCollision(prevPosition, sharedPos[localVertexIndex], velocity ); // somehow PBD doens't like collision detection before constraint , barrier thing ? 

	
	updateParticle(sharedPos[localVertexIndex], oldPosition, vec4(0), color );

}

