
//Position Based Dynamics Approach
subroutine(hairSimulationAlgorithm) void PBDApproach( const uint localStrandIndex,
	const uint localVertexIndex,
	const uint globalStrandIndex,
	const uint vertexIndexInStrand, 
	const vec4 position, 
	const vec4 prevPosition,
	const vec4 velocity,
	const vec4 color,
	const vec4 force
	){


	const vec4 oldPosition = position; 
	//sharedPos[localVertexIndex]  = verletIntegration( sharedPos[localVertexIndex], prevPosition, force, sharedFixed[localVertexIndex]);
	sharedPos[localVertexIndex]  = positionIntegration( oldPosition , velocity, force, sharedFixed[localVertexIndex]);


	const uint index0 = localVertexIndex*2;
	const uint index1 = localVertexIndex*2+1;
	const uint index2 = localVertexIndex*2+2;


	memoryBarrierShared();
	barrier();

	
	float stiffness = 1.0 - pow( (1.0 - g_stiffness), 1.0/g_numIterations); // linear depended on the iterations now
	
	for(int i = 0 ; i < g_numIterations ; i++){
		
		// split the solving in non adjacent pairs of vertices 
		if( localVertexIndex <  floor(gl_WorkGroupSize.x/2) && (index0 % g_numVerticesPerStrand) < g_numVerticesPerStrand-1){
			applyLengthConstraint( sharedPos[index0], sharedFixed[index0], sharedPos[index1], sharedFixed[index1], g_strandLength/g_numVerticesPerStrand, stiffness);

		}
		memoryBarrierShared();
		if( localVertexIndex <  floor((gl_WorkGroupSize.x-1)/2) && (index1 % g_numVerticesPerStrand) < g_numVerticesPerStrand -1){
			applyLengthConstraint( sharedPos[index1], sharedFixed[index1], sharedPos[index2], sharedFixed[index2], g_strandLength/g_numVerticesPerStrand, stiffness);			
		}
		memoryBarrierShared();

	}

	vec4 newVelocity = vec4((sharedPos[localVertexIndex].xyz - oldPosition.xyz) / g_timeStep ,0.0); 
	newVelocity = calculateFrictionAndRepulsionVelocityCorrection( newVelocity, sharedPos[localVertexIndex] );
	
	updateParticle(sharedPos[localVertexIndex], oldPosition, newVelocity, color );

}

